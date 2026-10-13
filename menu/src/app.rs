//! Estado da UI: abas, filtro, pilha de submenus, seleção e ativação.

use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::actions::{self, Paths, Run, Sub, SubDef, View, VIEWS};
use crate::exec::{self, Outcome};
use crate::fuzzy::{self, Folded};
use crate::palette::{Palette, SchemeInfo};
use crate::state::States;

pub enum Ctl {
    Continue,
    Quit,
}

pub struct Row {
    pub label: String,
    pub run: Option<Run>,
    pub sub: Option<Sub>,
    pub active: bool,
    pub is_back: bool,
}

pub struct App {
    pub paths: Paths,
    pub states: States,
    pub palette: Palette,
    pub scheme: SchemeInfo,
    pub view: usize,
    pub query: String,
    pub folded: Folded,
    pub stack: Vec<Sub>,
    pub rows: Vec<Row>,
    pub sel: usize,
    pub msg: Option<String>,
    pub dirty: bool,
    /// Última ação executada (label, "exit"|"stay"|"erro") — log MENU_SEQ.
    pub last_action: Option<(String, &'static str)>,
}

impl App {
    pub fn new() -> Self {
        let paths = Paths::load();
        let states = States::new();
        let palette = Palette::load(states.cache());
        let scheme = SchemeInfo::load(states.cache());
        let mut app = App {
            paths,
            states,
            palette,
            scheme,
            view: 0,
            query: String::new(),
            folded: fuzzy::fold_chars(""),
            stack: Vec::new(),
            rows: Vec::new(),
            sel: 0,
            msg: None,
            dirty: true,
            last_action: None,
        };
        app.refresh_rows();
        app
    }

    pub fn view_name(&self) -> View {
        VIEWS[self.view].1
    }

    /// Título do submenu no topo da pilha (None = vista principal).
    pub fn sub_title(&self) -> Option<&'static str> {
        self.stack.last().map(|s| actions::sub_def(*s).title)
    }

    /// Reconstrói a lista atual (abas/query/submenu) com os rótulos novos.
    pub fn refresh_rows(&mut self) {
        self.folded = fuzzy::fold_chars(&self.query);
        let mut rows: Vec<Row> = if let Some(sub) = self.stack.last().copied() {
            let def: &SubDef = actions::sub_def(sub);
            (def.loader)(&mut self.states, &self.paths)
                .into_iter()
                .map(|e| {
                    let mut label = e.label;
                    let is_back = label == "< Voltar";
                    if e.sub.is_some() && !is_back {
                        label.push_str(" >");
                    } else if e.active && !is_back {
                        label.push_str(" · Ativo");
                    }
                    Row { label, run: e.run, sub: e.sub, active: e.active, is_back }
                })
                .collect()
        } else {
            actions::roots_for(self.view_name())
                .map(|r| {
                    let mut label = r.label.to_string();
                    if let Some(k) = r.state {
                        label.push_str(" · ");
                        label.push_str(&actions::state_label(&mut self.states, &self.paths, k));
                    }
                    if r.sub.is_some() {
                        label.push_str(" >");
                    }
                    Row { label, run: r.run, sub: r.sub, active: false, is_back: false }
                })
                .collect()
        };

        let q = &self.folded.base;
        if !q.is_empty() {
            let mut scored: Vec<(i32, Row)> = rows
                .into_iter()
                .filter_map(|r| {
                    let t = fuzzy::fold_chars(&r.label);
                    fuzzy::score(q, &t.base).map(|s| (s, r))
                })
                .collect();
            scored.sort_by_key(|(s, _)| std::cmp::Reverse(*s));
            rows = scored.into_iter().map(|(_, r)| r).collect();
        }
        self.rows = rows;
        self.sel = self.sel.min(self.rows.len().saturating_sub(1));
        self.dirty = true;
    }

    fn back(&mut self) {
        self.stack.pop();
        self.query.clear();
        self.sel = 0;
        self.refresh_rows();
    }

    fn activate(&mut self) -> Ctl {
        let Some(row) = self.rows.get(self.sel) else {
            return Ctl::Continue;
        };
        if row.is_back {
            self.back();
            return Ctl::Continue;
        }
        if let Some(sub) = row.sub {
            self.stack.push(sub);
            self.query.clear();
            self.sel = 0;
            self.refresh_rows();
            return Ctl::Continue;
        }
        let Some(run) = row.run else {
            return Ctl::Continue;
        };
        let mut ex = exec::Exec { paths: &self.paths, states: &mut self.states };
        match ex.run(&run, &row.label) {
            Ok(Outcome::Exit) => {
                self.last_action = Some((row.label.clone(), "exit"));
                Ctl::Quit
            }
            Ok(Outcome::Stay) => {
                self.last_action = Some((row.label.clone(), "stay"));
                self.query.clear();
                self.refresh_rows();
                Ctl::Continue
            }
            Err(e) => {
                self.last_action = Some((row.label.clone(), "erro"));
                self.msg = Some(e);
                self.refresh_rows();
                Ctl::Continue
            }
        }
    }

    /// Trata uma tecla. `run_label` é preenchido quando uma ação executou
    /// (modo MENU_SEQ: o caller registra para o teste).
    pub fn handle_key(&mut self, k: KeyEvent) -> Ctl {
        self.msg = None;
        let nil = self.rows.len().saturating_sub(1);
        let ctl = match k.code {
            KeyCode::Esc => {
                if self.stack.is_empty() {
                    Ctl::Quit
                } else {
                    self.back();
                    Ctl::Continue
                }
            }
            KeyCode::Char('c') if k.modifiers.contains(KeyModifiers::CONTROL) => Ctl::Quit,
            KeyCode::Char('r') if !k.modifiers.contains(KeyModifiers::CONTROL) => {
                self.states.invalidate_all();
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::Char('q') if !k.modifiers.contains(KeyModifiers::CONTROL) => Ctl::Quit,
            KeyCode::Char('u') if k.modifiers.contains(KeyModifiers::CONTROL) => {
                self.query.clear();
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::Char('w') if k.modifiers.contains(KeyModifiers::CONTROL) => {
                while let Some(c) = self.query.pop() {
                    if c == ' ' {
                        break;
                    }
                }
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::Char(c) => {
                self.query.push(c);
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::Backspace => {
                self.query.pop();
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::Enter => return self.activate(),
            KeyCode::Up => {
                self.sel = if self.sel == 0 { nil } else { self.sel - 1 };
                Ctl::Continue
            }
            KeyCode::Down => {
                self.sel = if self.sel >= nil { 0 } else { self.sel + 1 };
                Ctl::Continue
            }
            KeyCode::Home => {
                self.sel = 0;
                Ctl::Continue
            }
            KeyCode::End => {
                self.sel = nil;
                Ctl::Continue
            }
            KeyCode::PageUp => {
                self.sel = self.sel.saturating_sub(10);
                Ctl::Continue
            }
            KeyCode::PageDown => {
                self.sel = (self.sel + 10).min(nil);
                Ctl::Continue
            }
            KeyCode::Tab | KeyCode::Right if self.stack.is_empty() => {
                self.view = (self.view + 1) % VIEWS.len();
                self.refresh_rows();
                Ctl::Continue
            }
            KeyCode::BackTab | KeyCode::Left if self.stack.is_empty() => {
                self.view = (self.view + VIEWS.len() - 1) % VIEWS.len();
                self.refresh_rows();
                Ctl::Continue
            }
            _ => Ctl::Continue,
        };
        self.dirty = true;
        ctl
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossterm::event::KeyModifiers as M;

    fn key(code: KeyCode, mods: M) -> KeyEvent {
        KeyEvent::new(code, mods)
    }
    fn ch(c: char) -> KeyEvent {
        key(KeyCode::Char(c), M::NONE)
    }

    fn app_teste() -> App {
        let mut a = App::new();
        a.paths.scripts = "/tmp/menu-teste-scripts".into();
        a.paths.presets = "/tmp/menu-teste-presets".into();
        a.states.invalidate_all();
        a
    }

    #[test]
    fn filtro_acha_e_ordena() {
        let mut a = app_teste();
        a.handle_key(ch('t'));
        a.handle_key(ch('e'));
        a.handle_key(ch('l'));
        a.handle_key(ch('a'));
        assert!(!a.rows.is_empty());
        assert_eq!(a.rows[0].label, "Bloquear tela");
    }

    #[test]
    fn filtro_com_acento_na_query() {
        let mut a = app_teste();
        for c in ['e', 's', 'q'] {
            a.handle_key(ch(c));
        }
        assert!(a.rows.iter().any(|r| r.label.starts_with("Esquemas de cores")));
    }

    #[test]
    fn backspace_e_ctrl_u() {
        let mut a = app_teste();
        a.handle_key(ch('x'));
        a.handle_key(ch('y'));
        assert_eq!(a.query, "xy");
        a.handle_key(key(KeyCode::Backspace, M::NONE));
        assert_eq!(a.query, "x");
        a.handle_key(key(KeyCode::Char('u'), M::CONTROL));
        assert_eq!(a.query, "");
        assert_eq!(a.rows.len(), actions::roots_for(a.view_name()).count());
    }

    #[test]
    fn submenu_entra_e_volta() {
        let mut a = app_teste();
        // filtra até "Gerenciador padrão" e entra no submenu
        a.handle_key(ch('g'));
        a.handle_key(ch('e'));
        let idx = a.rows.iter().position(|r| r.label.starts_with("Gerenciador")).unwrap();
        a.sel = idx;
        a.handle_key(key(KeyCode::Enter, M::NONE));
        assert!(a.stack.len() == 1);
        assert!(a.rows[0].is_back);
        assert!(a.rows.iter().any(|r| r.label.starts_with("PCManFM")));
        a.handle_key(key(KeyCode::Esc, M::NONE));
        assert!(a.stack.is_empty());
    }

    #[test]
    fn esc_sai_na_raiz() {
        let mut a = app_teste();
        assert!(matches!(a.handle_key(key(KeyCode::Esc, M::NONE)), Ctl::Quit));
    }

    #[test]
    fn tab_troca_aba() {
        let mut a = app_teste();
        let v0 = a.view;
        a.handle_key(key(KeyCode::Tab, M::NONE));
        assert_eq!((v0 + 1) % VIEWS.len(), a.view);
        // em submenu Tab não troca
        a.stack.push(Sub::Fm);
        let v1 = a.view;
        a.handle_key(key(KeyCode::Tab, M::NONE));
        assert_eq!(v1, a.view);
    }

    #[test]
    fn selecao_wrapa() {
        let mut a = app_teste();
        a.sel = 0;
        a.handle_key(key(KeyCode::Up, M::NONE));
        assert_eq!(a.sel, a.rows.len() - 1);
        a.handle_key(key(KeyCode::Down, M::NONE));
        assert_eq!(a.sel, 0);
    }
}