//! menu — hub de utilidades do rice (Mod+Shift+x). TUI ratatui puro.
//!
//! Sem async, sem camadas: crossterm + ratatui direto. Estados com TTL
//! (state.rs), ações nos scripts do rice via hooks `TOFI_*` (exec.rs).
//! `MENU_SEQ` injeta teclas (CI/E2E sem display; imprime RUN/STATE/SEQ_END).

mod actions;
mod app;
mod exec;
mod fuzzy;
mod palette;
mod state;
mod ui;

use std::io;
use std::time::{Duration, Instant};

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use crossterm::execute;
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use app::{App, Ctl};

fn print_help() {
    println!(
        "menu {} — hub de utilidades do rice (substitui o Mod+Shift+x).

Uso: menu [--hub|--global]

  Sem args abre o menu interativo (foot flutuante, app_id \"menu\").
  --hub / --global  aceitos por compatibilidade com o tofi-menu.sh.

Variáveis de ambiente (testes/CI):
  MENU_SEQ      teclas injetadas, uma por linha (char:x, key:enter, wait:ms,
                state, quit); imprime RUN/STATE/SEQ_END e sai.
  XDG_CACHE_HOME/XDG_RUNTIME_DIR   origem dos estados (padrão do rice);
  MENU_SCRIPTS/MENU_SCHEMES/MENU_PRESETS/MENU_TOFI_THEMES  redirecionam os
  caminhos do rice (testes).",
        env!("CARGO_PKG_VERSION")
    );
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let arg = std::env::args().nth(1);
    match arg.as_deref() {
        Some("--version") => {
            println!("menu {}", env!("CARGO_PKG_VERSION"));
            return Ok(());
        }
        Some("--help" | "-h") => {
            print_help();
            return Ok(());
        }
        _ => {}
    }
    if let Ok(seq) = std::env::var("MENU_SEQ") {
        return run_seq(&seq);
    }
    run_tui()
}

fn run_tui() -> Result<(), Box<dyn std::error::Error>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, crossterm::cursor::Hide)?;
    let mut term = Terminal::new(CrosstermBackend::new(stdout))?;
    let mut app = App::new();

    let res: Result<(), Box<dyn std::error::Error>> = loop {
        if app.dirty {
            term.draw(|f| ui::draw(f, &mut app))?;
            app.dirty = false;
        }
        if event::poll(Duration::from_millis(100))? {
            match event::read()? {
                Event::Key(k) => {
                    if matches!(app.handle_key(k), Ctl::Quit) {
                        break Ok(());
                    }
                }
                Event::Resize(..) => app.dirty = true,
                _ => {}
            }
        } else if app.states.next_due().is_some_and(|d| d <= Instant::now()) {
            // estados expiraram: o próximo draw relê os rótulos
            app.dirty = true;
        }
    };

    disable_raw_mode()?;
    execute!(term.backend_mut(), LeaveAlternateScreen, crossterm::cursor::Show)?;
    res
}

// ---------------------------------------------------------------------------
// MENU_SEQ (CI/E2E sem display): teclas injetadas + observação de estados
// ---------------------------------------------------------------------------

fn run_seq(seq: &str) -> Result<(), Box<dyn std::error::Error>> {
    let mut app = App::new();
    for raw in seq.lines() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        match line {
            "quit" => break,
            "state" => {
                for k in state::all_kinds() {
                    let l = actions::state_label(&mut app.states, &app.paths, k);
                    println!("STATE {k:?} = {l}");
                }
            }
            s if s.starts_with("wait:") => {
                std::thread::sleep(Duration::from_millis(s[5..].parse()?));
            }
            s if s.starts_with("char:") => {
                if let Some(c) = s[5..].chars().next() {
                    app.handle_key(KeyEvent::new(KeyCode::Char(c), KeyModifiers::NONE));
                }
            }
            s if s.starts_with("key:") => {
                let ctl = app.handle_key(seq_key(&s[4..]));
                if let Some((label, kind)) = app.last_action.take() {
                    println!("RUN {label} [{kind}]");
                }
                if matches!(ctl, Ctl::Quit) {
                    break;
                }
            }
            other => eprintln!("MENU_SEQ: linha ignorada: {other}"),
        }
    }
    println!("SEQ_END");
    Ok(())
}

fn seq_key(name: &str) -> KeyEvent {
    let none = KeyModifiers::NONE;
    match name {
        "enter" => KeyEvent::new(KeyCode::Enter, none),
        "esc" => KeyEvent::new(KeyCode::Esc, none),
        "up" => KeyEvent::new(KeyCode::Up, none),
        "down" => KeyEvent::new(KeyCode::Down, none),
        "left" => KeyEvent::new(KeyCode::Left, none),
        "right" => KeyEvent::new(KeyCode::Right, none),
        "tab" => KeyEvent::new(KeyCode::Tab, none),
        "backtab" | "shift-tab" => KeyEvent::new(KeyCode::BackTab, none),
        "backspace" => KeyEvent::new(KeyCode::Backspace, none),
        "home" => KeyEvent::new(KeyCode::Home, none),
        "end" => KeyEvent::new(KeyCode::End, none),
        "pgup" => KeyEvent::new(KeyCode::PageUp, none),
        "pgdn" => KeyEvent::new(KeyCode::PageDown, none),
        "r" => KeyEvent::new(KeyCode::Char('r'), none),
        "q" => KeyEvent::new(KeyCode::Char('q'), none),
        "ctrl-c" => KeyEvent::new(KeyCode::Char('c'), KeyModifiers::CONTROL),
        "ctrl-u" => KeyEvent::new(KeyCode::Char('u'), KeyModifiers::CONTROL),
        "ctrl-w" => KeyEvent::new(KeyCode::Char('w'), KeyModifiers::CONTROL),
        "enter-in-sub" => KeyEvent::new(KeyCode::Enter, none),
        _ => KeyEvent::new(KeyCode::Null, none),
    }
}