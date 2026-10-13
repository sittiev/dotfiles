//! Execução de ações: spawn detached (grupo próprio, sem SIGHUP do foot),
//! hooks `TOFI_*` para os pickers do rice, toggles equivalentes ao tofi-menu.
//!
//! Blast radius: o menu nunca escreve estado além do que os scripts já
//! escrevem — toggles de divisão/avisos replicam exatamente o comportamento
//! do `tofi-menu.sh` (flag `autotiling-off`, `makoctl mode`).

use std::os::unix::process::CommandExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

use crate::actions::{Paths, Run};
use crate::state::{Kind, States};

pub enum Outcome {
    /// Menu permanece aberto (estado atualizado em seguida).
    Stay,
    /// Ação executada e o menu deve sair (app/picker externo).
    Exit,
}

pub struct Exec<'a> {
    pub paths: &'a Paths,
    pub states: &'a mut States,
}

/// Spawn detached (grupo de processo próprio); não espera.
fn spawn_detached(cmd: &mut Command) -> std::io::Result<()> {
    cmd.stdout(Stdio::null())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
}

/// Constrói um `Command` para script do rice (resolvido em `scripts/`).
fn script_cmd(paths: &Paths, name: &str) -> Command {
    let path: PathBuf = paths.scripts.join(name);
    let mut c = Command::new(&path);
    // Aponta `$script_dir` para o mesmo lugar (scripts usam `$(dirname $0)`
    // derivado do próprio caminho — nada a injetar; PATH herda o do app).
    c.arg0(&path); // argv[0] = caminho absoluto (shebang funciona igual)
    c
}

fn notify(title: &str, body: &str) {
    let mut c = Command::new("notify-send");
    c.arg(title).arg(body);
    let _ = spawn_detached(&mut c);
}

fn find_in_path(cand: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        let p = dir.join(cand);
        if p.is_file() {
            use std::os::unix::fs::PermissionsExt;
            if p.metadata().is_ok_and(|m| m.permissions().mode() & 0o111 != 0) {
                return Some(p);
            }
        }
    }
    None
}

impl Exec<'_> {
    pub fn run(&mut self, run: &Run, entry_label: &str) -> Result<Outcome, String> {
        match run {
            Run::Open { cmd } => {
                let mut c = Command::new(cmd[0]);
                c.args(&cmd[1..]);
                spawn_detached(&mut c).map_err(|_| format!("Falha ao abrir {}", cmd[0]))?;
                Ok(Outcome::Exit)
            }
            Run::OpenBest { cand, title, body } => {
                for c in *cand {
                    if let Some(p) = find_in_path(c) {
                        let mut cmd = Command::new(p);
                        if spawn_detached(&mut cmd).is_ok() {
                            return Ok(Outcome::Exit);
                        }
                    }
                }
                notify(title, body);
                Ok(Outcome::Stay)
            }
            Run::Script { script, args, keep } => {
                let mut c = script_cmd(self.paths, script);
                c.args(*args);
                self.spawn_script(c, script, *keep)
            }
            Run::Pick { script, env, keep } => {
                let mut c = script_cmd(self.paths, script);
                c.env(env, entry_label);
                self.spawn_script(c, script, *keep)
            }
            Run::ToggleAutotiling => {
                let cache = self.states.cache();
                let flag = cache.join("autotiling-off");
                if self.states.get(Kind::Autotiling).flag() {
                    let _ = Command::new("pkill").arg("-x").arg("autotiling-rs")
                        .stdout(Stdio::null()).stderr(Stdio::null()).status();
                    let _ = std::fs::write(&flag, "");
                    notify("Divisão automática desligada", "Para monocle, use mod+w (abas) ou mod+s (pilha).");
                } else {
                    let _ = std::fs::remove_file(&flag);
                    let _ = Command::new("pkill").arg("-x").arg("autotiling-rs")
                        .stdout(Stdio::null()).stderr(Stdio::null()).status();
                    std::thread::sleep(std::time::Duration::from_millis(200));
                    let mut c = Command::new("autotiling-rs");
                    if spawn_detached(&mut c).is_err() {
                        // autotiling ausente: só o flag foi limpo; avisa.
                        notify("Divisão automática indisponível", "Para ativar, instale autotiling-rs: paru -S autotiling-rs.");
                    } else {
                        notify("Divisão automática ativada", "Novas janelas alternam direção sozinhas.");
                    }
                }
                self.states.invalidate_all();
                Ok(Outcome::Stay)
            }
            Run::ToggleDnd => {
                let on = self.states.get(Kind::Dnd).flag();
                let mut c = Command::new("makoctl");
                c.arg("mode");
                if on {
                    c.args(["-r", "do-not-disturb"]);
                    notify("Avisos ativados", "");
                } else {
                    notify("Avisos silenciados", "");
                    c.args(["-a", "do-not-disturb"]);
                }
                let _ = c.stdout(Stdio::null()).stderr(Stdio::null()).status();
                self.states.invalidate_all();
                Ok(Outcome::Stay)
            }
            Run::Notify { title, body } => {
                let text = body
                    .map(|k| crate::actions::state_label(self.states, self.paths, k))
                    .unwrap_or_default();
                notify(title, &text);
                Ok(Outcome::Stay)
            }
        }
    }

    /// Spawn do script do rice; keep = espera terminar e invalida estados.
    fn spawn_script(&mut self, mut c: Command, script: &str, keep: bool) -> Result<Outcome, String> {
        let mut child = c
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .stdin(Stdio::null())
            .process_group(0)
            .spawn()
            .map_err(|_| format!("Falha ao executar {script}"))?;
        if keep {
            let _ = child.wait();
            self.states.invalidate_all();
            Ok(Outcome::Stay)
        } else {
            Ok(Outcome::Exit)
        }
    }
}