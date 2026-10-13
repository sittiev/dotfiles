//! Estados do sistema exibidos no menu, com cache TTL.
//!
//! Overhead mínimo: pgrep/makoctl são subprocessos (~5-15 ms); com TTL
//! por chave eles rodam só quando o rótulo é renderizado e a janela venceu
//! (2 s; bateria 5 s; hora 10 s; data 60 s). `invalidate` pós-ação força
//! releitura. Caminhos sobreescrevíveis por env (testes, CI): XDG_CACHE_HOME,
//! XDG_RUNTIME_DIR, MENU_BATTERY_DIR.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Kind {
    Autotiling,
    Dnd,
    Game,
    Night,
    Bar,
    ClockFull,
    Mode,
    Scheme,
    Fastfetch,
    TofiLayout,
    UiFont,
    UiSize,
    TermFont,
    MonoFont,
    Icons,
    PapirusVariant,
    PapirusFolders,
    Fm,
    LockTimeout,
    Battery,
    Time,
    Date,
}

#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Value {
    Str(String),
    Flag(bool),
}

impl Value {
    pub fn flag(&self) -> bool {
        matches!(self, Value::Flag(true))
    }
    pub fn str(&self) -> Option<&str> {
        match self {
            Value::Str(s) => Some(s),
            Value::Flag(_) => None,
        }
    }
}

impl Default for Value {
    fn default() -> Self {
        Value::Str(String::new())
    }
}

pub struct States {
    cache: PathBuf,
    runtime: PathBuf,
    battery_dir: Option<PathBuf>,
    vals: HashMap<Kind, Value>,
    next: HashMap<Kind, Instant>,
}

fn ttl(k: Kind) -> Duration {
    match k {
        Kind::Time => Duration::from_secs(10),
        Kind::Date => Duration::from_secs(60),
        Kind::Battery => Duration::from_secs(5),
        _ => Duration::from_secs(2),
    }
}

fn pgrep_on(name: &str) -> bool {
    Command::new("pgrep")
        .arg("-x")
        .arg(name)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn mako_dnd_on() -> bool {
    Command::new("makoctl")
        .arg("mode")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("do-not-disturb"))
        .unwrap_or(false)
}

fn read_trim_file(p: &Path) -> Option<String> {
    std::fs::read_to_string(p)
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn file_exists(p: &Path) -> bool {
    p.is_file()
}

fn battery_capacity(dir: &Path) -> String {
    let Ok(rd) = std::fs::read_dir(dir) else {
        return "—".to_string();
    };
    let mut caps = Vec::new();
    for e in rd.flatten() {
        let name = e.file_name();
        let name = name.to_string_lossy();
        if !name.starts_with("BAT") || !e.path().is_dir() {
            continue;
        }
        if let Some(v) = read_trim_file(&e.path().join("capacity")) {
            caps.push(v);
        }
    }
    caps.first().cloned().unwrap_or_else(|| "—".to_string())
}

fn read(kind: Kind, cache: &Path, runtime: &Path, battery: Option<&Path>) -> Value {
    match kind {
        Kind::Autotiling => Value::Flag(pgrep_on("autotiling-rs")),
        Kind::Dnd => Value::Flag(mako_dnd_on()),
        Kind::Game => Value::Flag(file_exists(&cache.join("sway-game-mode/active"))),
        Kind::Night => Value::Flag(pgrep_on("wlsunset")),
        Kind::Bar => Value::Flag(pgrep_on("yambar")),
        Kind::ClockFull => Value::Flag(file_exists(&runtime.join("yambar-clock-full"))),
        Kind::Mode => file_val(cache, "theme-mode"),
        Kind::Scheme => file_val(cache, "theme-scheme"),
        Kind::Fastfetch => file_val(cache, "fastfetch-style"),
        Kind::TofiLayout => file_val(cache, "tofi-layout"),
        Kind::UiFont => file_val(cache, "ui-font"),
        Kind::UiSize => file_val(cache, "ui-font-size"),
        Kind::TermFont => file_val(cache, "term-font"),
        Kind::MonoFont => file_val(cache, "mono-font"),
        Kind::Icons => file_val(cache, "icon-theme"),
        Kind::PapirusVariant => file_val(cache, "icon-theme-papirus-variant"),
        Kind::PapirusFolders => file_val(cache, "icon-theme-papirus-folders"),
        Kind::Fm => file_val(cache, "file-manager"),
        Kind::LockTimeout => file_val(cache, "lock-timeout"),
        Kind::Battery => {
            let d = battery.unwrap_or(Path::new("/sys/class/power_supply"));
            Value::Str(battery_capacity(d))
        }
        Kind::Time => Value::Str(
            Command::new("date")
                .args(["+%H:%M"])
                .output()
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or_default(),
        ),
        Kind::Date => Value::Str(
            Command::new("date")
                .args(["+%A, %d de %B de %Y"])
                .output()
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or_default(),
        ),
    }
}

fn file_val(cache: &Path, name: &str) -> Value {
    match read_trim_file(&cache.join(name)) {
        Some(v) => Value::Str(v),
        None => Value::Str(String::new()),
    }
}

impl States {
    pub fn new() -> Self {
        let cache = std::env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".cache"));
        let runtime = std::env::var_os("XDG_RUNTIME_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from("/run/user").join(std::env::var("USER").unwrap_or_default())
            });
        let battery_dir = std::env::var_os("MENU_BATTERY_DIR").map(PathBuf::from);
        States {
            cache,
            runtime,
            battery_dir,
            vals: HashMap::new(),
            next: HashMap::new(),
        }
    }

    pub fn cache(&self) -> &Path {
        &self.cache
    }

    /// Valor atual, lendo do sistema se a janela TTL venceu.
    pub fn get(&mut self, k: Kind) -> Value {
        let due = self.next.get(&k).map(|i| Instant::now() >= *i).unwrap_or(true);
        if due {
            let v = read(k, &self.cache, &self.runtime, self.battery_dir.as_deref());
            self.vals.insert(k, v.clone());
            self.next.insert(k, Instant::now() + ttl(k));
            v
        } else {
            self.vals.get(&k).cloned().unwrap_or_default()
        }
    }

    /// Releitura imediata de todas as chaves (pós-ação; o script terminou).
    pub fn invalidate_all(&mut self) {
        self.next.clear();
    }

    /// Próxima expiração entre todas as chaves já lidas; `None` = nada pendente.
    pub fn next_due(&self) -> Option<Instant> {
        self.next.values().copied().min()
    }
}

pub fn all_kinds() -> impl Iterator<Item = Kind> {
    [
        Kind::Autotiling,
        Kind::Dnd,
        Kind::Game,
        Kind::Night,
        Kind::Bar,
        Kind::ClockFull,
        Kind::Mode,
        Kind::Scheme,
        Kind::Fastfetch,
        Kind::TofiLayout,
        Kind::UiFont,
        Kind::UiSize,
        Kind::TermFont,
        Kind::MonoFont,
        Kind::Icons,
        Kind::PapirusVariant,
        Kind::PapirusFolders,
        Kind::Fm,
        Kind::LockTimeout,
        Kind::Battery,
        Kind::Time,
        Kind::Date,
    ]
    .into_iter()
}

impl Default for States {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn tmp_home() -> PathBuf {
        let dir = std::env::temp_dir().join(format!("menu-state-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn le_arquivos_de_cache() {
        let dir = tmp_home();
        std::fs::write(dir.join("theme-mode"), "light\n").unwrap();
        std::fs::write(dir.join("theme-scheme"), "1984\n").unwrap();
        std::fs::write(dir.join("ui-font"), "sf\n").unwrap();
        std::fs::create_dir_all(dir.join("sway-game-mode")).unwrap();
        std::fs::write(dir.join("sway-game-mode/active"), "").unwrap();

        let mut s = States::new();
        s.cache = dir.clone();
        s.runtime = dir.join("run");
        assert_eq!(s.get(Kind::Mode).str(), Some("light"));
        assert_eq!(s.get(Kind::Scheme).str(), Some("1984"));
        assert_eq!(s.get(Kind::UiFont).str(), Some("sf"));
        assert!(s.get(Kind::Game).flag());
        // ausente → string vazia (label mostra default)
        assert_eq!(s.get(Kind::Fm).str(), Some(""));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn invalidacao_forca_releitura() {
        let dir = tmp_home();
        std::fs::write(dir.join("theme-mode"), "dark\n").unwrap();
        let mut s = States::new();
        s.cache = dir.clone();
        s.runtime = dir.join("run");
        assert_eq!(s.get(Kind::Mode).str(), Some("dark"));
        std::fs::write(dir.join("theme-mode"), "light\n").unwrap();
        // sem invalidar, TTL segura o valor antigo
        assert_eq!(s.get(Kind::Mode).str(), Some("dark"));
        s.invalidate_all();
        assert_eq!(s.get(Kind::Mode).str(), Some("light"));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn bateria_por_override() {
        let dir = tmp_home();
        std::fs::create_dir_all(dir.join("BAT0")).unwrap();
        let mut f = std::fs::File::create(dir.join("BAT0/capacity")).unwrap();
        f.write_all(b"73\n").unwrap();
        let mut s = States::new();
        s.battery_dir = Some(dir.clone());
        assert_eq!(s.get(Kind::Battery).str(), Some("73"));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn bateria_sem_dir_devia_tracinho() {
        let mut s = States::new();
        s.battery_dir = Some(PathBuf::from("/tmp/menu-sem-bat-xyz"));
        assert_eq!(s.get(Kind::Battery).str(), Some("—"));
    }
}