//! Render do TUI: header com abas, busca, lista com highlight de match,
//! painel direito com a paleta viva (canto) e footer de atalhos.
//!
//! Regra de cor (consistência com o rice): o texto herda o tema do
//! terminal (foot já traz as cores do pywal corretas) — nunca impõe cor
//! absoluta em texto, senão um colors.sh defasado do terminal deixa o
//! menu ilegível. A paleta absoluta vale só nos swatches do painel.

use ratatui::layout::{Alignment, Constraint, Direction, Layout, Position, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph};
use ratatui::Frame;

use crate::actions::VIEWS;
use crate::app::{App, Row};
use crate::fuzzy;
use crate::palette::{hex_str, Palette};

const SIDE_W: u16 = 26;

/// Estilos derivados da paleta viva; `None` = herda o terminal.
pub struct St {
    acc: Option<Color>,
    muted: Option<Color>,
}

fn rgb(c: (u8, u8, u8)) -> Color {
    Color::Rgb(c.0, c.1, c.2)
}

fn styles(p: &Palette) -> St {
    St {
        acc: p.colors[4].map(rgb),
        muted: p.colors[8].map(rgb),
    }
}

/// Estilo do item selecionado: inversão nativa do terminal (sempre legível).
const fn sel_style() -> Style {
    Style::new().add_modifier(Modifier::REVERSED)
}

pub fn draw(f: &mut Frame, app: &mut App) {
    let st = styles(&app.palette);
    let [cols, footer] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(0), Constraint::Length(1)])
        .areas(f.area());
    let side_w = if cols.width >= SIDE_W * 2 { SIDE_W } else { 0 };
    let [main, side] = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Min(0), Constraint::Length(side_w)])
        .areas(cols);
    let [hdr, tabs, search, list] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Min(0),
        ])
        .areas(main);

    draw_header(f, app, hdr, &st);
    draw_tabs(f, app, tabs, &st);
    draw_search(f, app, search, &st);
    draw_list(f, app, list, &st);
    if side_w > 0 {
        draw_palette(f, app, side, &st);
    }
    draw_footer(f, app, footer, &st);
}

fn muted_span(st: &St, text: &str) -> Span<'static> {
    Span::styled(
        text.to_string(),
        Style::default().add_modifier(Modifier::DIM).fg(st.muted.unwrap_or(Color::Reset)),
    )
}

fn draw_header(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let mut spans = vec![Span::styled(
        "Ajustes".to_string(),
        Style::default().add_modifier(Modifier::BOLD),
    )];
    if let Some(title) = app.sub_title() {
        spans.push(muted_span(st, " › "));
        spans.push(Span::styled(title.to_string(), Style::default().add_modifier(Modifier::BOLD)));
    }
    let [left, right] = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Min(0), Constraint::Length(8)])
        .areas(area);
    f.render_widget(Paragraph::new(Line::from(spans)), left);
    f.render_widget(
        Paragraph::new(Line::from(muted_span(st, &format!("{} itens", app.rows.len()))))
            .alignment(Alignment::Right),
        right,
    );
}

fn draw_tabs(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let mut spans: Vec<Span> = Vec::with_capacity(VIEWS.len() * 2);
    for (i, (name, _)) in VIEWS.iter().enumerate() {
        if i > 0 {
            spans.push(Span::raw(" "));
        }
        let active = i == app.view && app.stack.is_empty();
        let mut style = Style::default();
        if active {
            style = style.add_modifier(Modifier::BOLD);
            if let Some(acc) = st.acc {
                style = style.fg(acc);
            }
        } else {
            style = style.add_modifier(Modifier::DIM);
            if let Some(m) = st.muted {
                style = style.fg(m);
            }
        }
        spans.push(Span::styled(*name, style));
    }
    f.render_widget(Paragraph::new(Line::from(spans)), area);
}

fn draw_search(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let cursor_x = area.x + 8 + app.query.chars().count() as u16;
    let mut line = vec![muted_span(st, "Buscar: ")];
    if app.query.is_empty() {
        line.push(muted_span(st, "(digite para filtrar)"));
    } else {
        line.push(Span::raw(app.query.clone()));
    }
    f.render_widget(Paragraph::new(Line::from(line)), area);
    f.set_cursor_position(Position::new(cursor_x.min(area.right().saturating_sub(1)), area.y));
}

fn draw_list(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let n = app.rows.len();
    if n == 0 {
        f.render_widget(
            Paragraph::new(Line::from(muted_span(st, "Nada encontrado"))),
            area,
        );
        return;
    }
    let h = area.height as usize;
    let top = if n <= h { 0 } else { app.sel.saturating_sub(h / 2).min(n - h) };
    for i in 0..h {
        let gi = top + i;
        let Some(row) = app.rows.get(gi) else { break };
        let selected = gi == app.sel;
        let line = row_line(app, row, selected, st);
        let style = if selected { sel_style() } else { Style::default() };
        let y = area.y + i as u16;
        f.render_widget(Paragraph::new(line).style(style), Rect::new(area.x, y, area.width, 1));
    }
}

fn row_line(app: &App, row: &Row, selected: bool, st: &St) -> Line<'static> {
    let mut spans: Vec<Span> = vec![Span::raw(if selected { "> " } else { "  " })];
    let (orig, marks) = fold_label(app, &row.label);
    // match: accent da paleta quando existir; peso (bold) sempre.
    let hi = Style::default().add_modifier(Modifier::BOLD);
    let hi = match (selected, st.acc) {
        (false, Some(acc)) => hi.fg(acc),
        _ => hi,
    };
    let mut run: Vec<char> = Vec::new();
    let mut run_hi = false;
    for (i, &c) in orig.iter().enumerate() {
        let m = marks[i];
        if run.is_empty() || run_hi == m {
            run.push(c);
            run_hi = m;
        } else {
            spans.push(if run_hi {
                Span::styled(run.iter().collect::<String>(), hi)
            } else {
                Span::raw(run.iter().collect::<String>())
            });
            run.clear();
            run.push(c);
            run_hi = m;
        }
    }
    if !run.is_empty() {
        spans.push(if run_hi {
            Span::styled(run.iter().collect::<String>(), hi)
        } else {
            Span::raw(run.iter().collect::<String>())
        });
    }
    if row.active && !selected {
        let mut s = Style::default().add_modifier(Modifier::BOLD);
        if let Some(acc) = st.acc {
            s = s.fg(acc);
        }
        spans.push(Span::styled(" · Ativo", s));
    }
    Line::from(spans)
}

fn fold_label(app: &App, label: &str) -> (Vec<char>, Vec<bool>) {
    let f = fuzzy::fold_chars(label);
    let marks = fuzzy::matched_positions(&app.folded.base, &f)
        .unwrap_or_else(|| vec![false; f.orig.len()]);
    (f.orig, marks)
}

fn draw_palette(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(Line::from(Span::styled(
            " Paleta atual ",
            Style::default().add_modifier(Modifier::BOLD),
        )));
    f.render_widget(block, area);
    let inner = Rect::new(
        area.x + 1,
        area.y + 1,
        area.width.saturating_sub(2),
        area.height.saturating_sub(2),
    );

    let p = &app.palette;
    let mut lines: Vec<Line> = Vec::new();
    if !p.has_wall() {
        lines.push(Line::from(muted_span(st, "Sem paleta (pywal ausente)")));
    } else {
        lines.push(Line::from(muted_span(st, &format!("{} · {}", app.scheme.name, app.scheme.mode))));
        if let Some(bg) = p.background {
            let spans: Vec<Span> = vec![
                Span::styled("██", Style::default().fg(rgb(bg))),
                Span::raw(" "),
                muted_span(st, &hex_str(bg)),
            ];
            lines.push(Line::from(spans));
        }
        // grade 8x2 das 16 cores (cores absolutas — é o conteúdo do painel)
        for row in 0..2 {
            let mut spans: Vec<Span> = Vec::with_capacity(23);
            for col in 0..8 {
                if col > 0 {
                    spans.push(Span::raw(" "));
                }
                let c = p.colors[row * 8 + col];
                spans.push(Span::styled(
                    "██",
                    Style::default().fg(c.map(rgb).unwrap_or(Color::Reset)),
                ));
            }
            lines.push(Line::from(spans));
        }
        if let Some(fgc) = p.foreground {
            let spans: Vec<Span> = vec![
                Span::styled("██", Style::default().fg(rgb(fgc))),
                Span::raw(" "),
                muted_span(st, &hex_str(fgc)),
            ];
            lines.push(Line::from(spans));
        }
    }
    f.render_widget(Paragraph::new(ratatui::text::Text::from(lines)), inner);
}

fn draw_footer(f: &mut Frame, app: &App, area: Rect, st: &St) {
    let hints = if let Some(msg) = &app.msg {
        format!("! {msg}")
    } else if app.stack.is_empty() {
        "↑↓ mover · Tab abas · Digitar filtrar · ↵ abrir · Esc/Q sair · R recarregar".to_string()
    } else {
        "↑↓ mover · ↵ escolher · Esc voltar".to_string()
    };
    f.render_widget(Paragraph::new(Line::from(muted_span(st, &hints))), area);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::App;
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    fn render(app: &mut App, w: u16, h: u16) -> Vec<String> {
        let mut t = Terminal::new(TestBackend::new(w, h)).unwrap();
        t.draw(|f| draw(f, app)).unwrap();
        t.backend()
            .buffer()
            .content()
            .chunks(w as usize)
            .map(|row| row.iter().map(|c| c.symbol().chars().next().unwrap_or(' ')).collect())
            .collect()
    }

    #[test]
    fn desenha_titulo_lista_e_paleta() {
        let mut a = App::new();
        a.palette = Palette::default();
        let buf = render(&mut a, 110, 34);
        let all: String = buf.iter().flat_map(|l| l.chars()).collect();
        assert!(all.contains('A') && all.contains("Terminal"), "faltou 'Terminal': {buf:?}");
        assert!(buf[0].contains("Ajustes"));
        assert!(buf.iter().any(|l| l.contains("Paleta")), "painel da paleta ausente");
        assert!(buf.last().unwrap().contains("Esc/Q"), "footer ausente");
    }

    #[test]
    fn paleta_com_cores_desenha_swatches() {
        let mut a = App::new();
        a.palette = Palette {
            background: Some((0x2a, 0x2a, 0x2a)),
            foreground: Some((0xc9, 0xc9, 0xc9)),
            colors: [Some((1, 2, 3)); 16],
        };
        let buf = render(&mut a, 110, 34);
        assert!(buf.iter().any(|l| l.contains("#2a2a2a")), "hex do BG ausente");
        assert!(buf.iter().any(|l| l.contains('#')), "hex das cores ausente");
    }
}