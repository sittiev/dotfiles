//! Catálogo de ações (mesmo cardápio do `tofi-menu.sh`) + submenus.
//!
//! Rótulos seguem o UX-WRITING do rice (pt-BR, sentence case, " · estado",
//! " >" para submenu). Ações executam os scripts existentes (única fonte
//! da lógica de aplicação), usando os hooks não-interativos `TOFI_*`.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::state::{Kind, States, Value};

// ---------------------------------------------------------------------------
// Paths do rice (sobrescrevíveis por env para testes/CI)
// ---------------------------------------------------------------------------

#[derive(Clone, Debug)]
pub struct Paths {
    pub scripts: PathBuf,
    pub schemes_json: PathBuf,
    pub presets: PathBuf,
    pub tofi_themes: PathBuf,
}

impl Paths {
    pub fn load() -> Self {
        let home = PathBuf::from(std::env::var("HOME").unwrap_or_default());
        let config = home.join(".config");
        let env_path = |k: &str, d: PathBuf| std::env::var_os(k).map(PathBuf::from).unwrap_or(d);
        Paths {
            scripts: env_path("MENU_SCRIPTS", config.join("sway/scripts")),
            schemes_json: env_path("MENU_SCHEMES", config.join("sway/schemes/gogh-themes-min.json")),
            presets: env_path("MENU_PRESETS", config.join("fastfetch/presets")),
            tofi_themes: env_path("MENU_TOFI_THEMES", config.join("tofi/themes")),
        }
    }
}

// ---------------------------------------------------------------------------
// Views (abas)
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum View {
    All,
    Apps,
    Net,
    Look,
    Win,
    Sys,
}

pub const VIEWS: [(&str, View); 6] = [
    ("Todas", View::All),
    ("Aplicativos", View::Apps),
    ("Conectividade", View::Net),
    ("Aparência", View::Look),
    ("Janelas", View::Win),
    ("Sistema", View::Sys),
];

const V_APPS: u8 = 1 << 0;
const V_NET: u8 = 1 << 1;
const V_LOOK: u8 = 1 << 2;
const V_WIN: u8 = 1 << 3;
const V_SYS: u8 = 1 << 4;
const V_ABS: u8 = V_APPS | V_NET | V_LOOK | V_WIN | V_SYS;

// ---------------------------------------------------------------------------
// Ações
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Sub {
    Fm,
    Schemes,
    Fastfetch,
    Tofi,
    Uifont,
    Uisize,
    Termfont,
    Monofont,
    Icons,
    Papirus,
    Folders,
    Temp,
    Monitors,
    Power,
    Lock,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Run {
    /// Comando do PATH; fecha o menu (app externo).
    Open { cmd: &'static [&'static str] },
    /// Primeiro candidato existente no PATH; senão notify (Rede/Bluetooth).
    OpenBest {
        cand: &'static [&'static str],
        title: &'static str,
        body: &'static str,
    },
    /// Script do rice; keep = menu permanece aberto (toggle/estado novo).
    Script {
        script: &'static str,
        args: &'static [&'static str],
        keep: bool,
    },
    /// Script com escolha via hook não-interativo `TOFI_*`.
    Pick {
        script: &'static str,
        env: &'static str,
        keep: bool,
    },
    ToggleAutotiling,
    ToggleDnd,
    Notify { title: &'static str, body: Option<Kind> },
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Root {
    pub label: &'static str,
    pub state: Option<Kind>,
    pub sub: Option<Sub>,
    pub run: Option<Run>,
    pub views: u8,
}

const ROOTS: &[Root] = &[
    // --- Aplicativos -----------------------------------------------------
    Root { label: "Terminal", state: None, sub: None, run: Some(Run::Open { cmd: &["foot"] }), views: V_ABS },
    Root { label: "Arquivos", state: Some(Kind::Fm), sub: None, run: Some(Run::Script { script: "file-manager.sh", args: &["open"], keep: false }), views: V_ABS },
    Root { label: "Gerenciador padrão", state: Some(Kind::Fm), sub: Some(Sub::Fm), run: None, views: V_ABS },
    Root { label: "Navegador", state: None, sub: None, run: Some(Run::Open { cmd: &["librewolf"] }), views: V_ABS },
    // --- Conectividade ----------------------------------------------------
    Root { label: "Rede", state: None, sub: None, run: Some(Run::OpenBest { cand: &["iwgtk"], title: "Rede indisponível", body: "Para configurar, instale iwgtk: paru -S iwgtk." }), views: V_NET },
    Root { label: "Bluetooth", state: None, sub: None, run: Some(Run::OpenBest { cand: &["overskride"], title: "Bluetooth indisponível", body: "Para configurar, instale overskride: paru -S overskride." }), views: V_NET },
    // --- Aparência ---------------------------------------------------------
    Root { label: "Modo claro", state: None, sub: None, run: Some(Run::Script { script: "theme-toggle.sh", args: &["light"], keep: false }), views: V_LOOK },
    Root { label: "Modo escuro", state: None, sub: None, run: Some(Run::Script { script: "theme-toggle.sh", args: &["dark"], keep: false }), views: V_LOOK },
    Root { label: "Esquemas de cores", state: Some(Kind::Scheme), sub: Some(Sub::Schemes), run: None, views: V_LOOK },
    Root { label: "Estilo do fastfetch", state: Some(Kind::Fastfetch), sub: Some(Sub::Fastfetch), run: None, views: V_LOOK },
    Root { label: "Tema do Tofi", state: Some(Kind::TofiLayout), sub: Some(Sub::Tofi), run: None, views: V_LOOK },
    Root { label: "Fonte", state: Some(Kind::UiFont), sub: Some(Sub::Uifont), run: None, views: V_LOOK },
    Root { label: "Tamanho da fonte", state: Some(Kind::UiSize), sub: Some(Sub::Uisize), run: None, views: V_LOOK },
    Root { label: "Fonte do terminal", state: Some(Kind::TermFont), sub: Some(Sub::Termfont), run: None, views: V_LOOK },
    Root { label: "Fonte mono", state: Some(Kind::MonoFont), sub: Some(Sub::Monofont), run: None, views: V_LOOK },
    Root { label: "Ícones", state: Some(Kind::Icons), sub: Some(Sub::Icons), run: None, views: V_LOOK },
    Root { label: "Papel de parede", state: None, sub: None, run: Some(Run::Script { script: "wallpaper.sh", args: &[], keep: false }), views: V_LOOK },
    Root { label: "Luz noturna", state: Some(Kind::Night), sub: None, run: Some(Run::Script { script: "nightlight.sh", args: &[], keep: true }), views: V_LOOK },
    Root { label: "Temperatura da luz", state: None, sub: Some(Sub::Temp), run: None, views: V_LOOK },
    Root { label: "Barra inferior", state: Some(Kind::Bar), sub: None, run: Some(Run::Script { script: "yambar-toggle.sh", args: &[], keep: true }), views: V_LOOK },
    Root { label: "Relógio da barra", state: Some(Kind::ClockFull), sub: None, run: Some(Run::Script { script: "yambar-clock-toggle.sh", args: &[], keep: true }), views: V_LOOK },
    // --- Janelas ------------------------------------------------------------
    Root { label: "Divisão automática", state: Some(Kind::Autotiling), sub: None, run: Some(Run::ToggleAutotiling), views: V_WIN },
    Root { label: "Avisos", state: Some(Kind::Dnd), sub: None, run: Some(Run::ToggleDnd), views: V_WIN },
    Root { label: "Modo jogo", state: Some(Kind::Game), sub: None, run: Some(Run::Script { script: "game-mode.sh", args: &["toggle"], keep: true }), views: V_WIN },
    // --- Sistema -------------------------------------------------------------
    Root { label: "Área de transferência", state: None, sub: None, run: Some(Run::Script { script: "clipboard.sh", args: &[], keep: false }), views: V_SYS },
    Root { label: "Emoji", state: None, sub: None, run: Some(Run::Script { script: "emoji.sh", args: &[], keep: false }), views: V_SYS },
    Root { label: "Monitores", state: None, sub: Some(Sub::Monitors), run: None, views: V_SYS },
    Root { label: "Energia", state: None, sub: Some(Sub::Power), run: None, views: V_SYS },
    Root { label: "Bloqueio automático", state: Some(Kind::LockTimeout), sub: Some(Sub::Lock), run: None, views: V_SYS },
    Root { label: "Bateria", state: Some(Kind::Battery), sub: None, run: Some(Run::Notify { title: "Bateria", body: Some(Kind::Battery) }), views: V_SYS },
    Root { label: "Hora", state: Some(Kind::Time), sub: None, run: Some(Run::Notify { title: "Hora", body: Some(Kind::Time) }), views: V_SYS },
    Root { label: "Data", state: None, sub: None, run: Some(Run::Notify { title: "Data", body: Some(Kind::Date) }), views: V_SYS },
    Root { label: "Bloquear tela", state: None, sub: None, run: Some(Run::Script { script: "dewlock.sh", args: &[], keep: false }), views: V_SYS },
];

/// Raízes visíveis numa aba (All = todas).
pub fn roots_for(view: View) -> impl Iterator<Item = &'static Root> {
    ROOTS.iter().filter(move |r| view == View::All || r.views & view_mask(view) != 0)
}

fn view_mask(v: View) -> u8 {
    match v {
        View::All => V_ABS,
        View::Apps => V_APPS,
        View::Net => V_NET,
        View::Look => V_LOOK,
        View::Win => V_WIN,
        View::Sys => V_SYS,
    }
}

// ---------------------------------------------------------------------------
// Submenus
// ---------------------------------------------------------------------------

pub struct SubEntry {
    pub label: String,
    pub active: bool,
    pub run: Option<Run>,
    pub sub: Option<Sub>,
}

pub struct SubDef {
    pub title: &'static str,
    pub loader: fn(&mut States, &Paths) -> Vec<SubEntry>,
}

fn back() -> SubEntry {
    SubEntry { label: "< Voltar".to_string(), active: false, run: None, sub: None }
}

static SUB_FM: SubDef = SubDef { title: "Gerenciador padrão", loader: sub_fm };
static SUB_SCHEMES: SubDef = SubDef { title: "Esquema", loader: sub_schemes };
static SUB_FASTFETCH: SubDef = SubDef { title: "Estilo do fastfetch", loader: sub_fastfetch };
static SUB_TOFI: SubDef = SubDef { title: "Tema", loader: sub_tofi };
static SUB_UIFONT: SubDef = SubDef { title: "Fonte", loader: sub_uifont };
static SUB_UISIZE: SubDef = SubDef { title: "Tamanho da fonte", loader: sub_uisize };
static SUB_TERMFONT: SubDef = SubDef { title: "Fonte do terminal", loader: sub_termfont };
static SUB_MONOFONT: SubDef = SubDef { title: "Fonte mono", loader: sub_monofont };
static SUB_ICONS: SubDef = SubDef { title: "Ícones", loader: sub_icons };
static SUB_PAPIRUS: SubDef = SubDef { title: "Variante do Papirus", loader: sub_papirus };
static SUB_FOLDERS: SubDef = SubDef { title: "Cor das pastas", loader: sub_folders };
static SUB_TEMP: SubDef = SubDef { title: "Luz noturna", loader: sub_temp };
static SUB_MONITORS: SubDef = SubDef { title: "Monitores", loader: sub_monitors };
static SUB_POWER: SubDef = SubDef { title: "Energia", loader: sub_power };
static SUB_LOCK: SubDef = SubDef { title: "Bloqueio automático", loader: sub_lock };

pub fn sub_def(s: Sub) -> &'static SubDef {
    match s {
        Sub::Fm => &SUB_FM,
        Sub::Schemes => &SUB_SCHEMES,
        Sub::Fastfetch => &SUB_FASTFETCH,
        Sub::Tofi => &SUB_TOFI,
        Sub::Uifont => &SUB_UIFONT,
        Sub::Uisize => &SUB_UISIZE,
        Sub::Termfont => &SUB_TERMFONT,
        Sub::Monofont => &SUB_MONOFONT,
        Sub::Icons => &SUB_ICONS,
        Sub::Papirus => &SUB_PAPIRUS,
        Sub::Folders => &SUB_FOLDERS,
        Sub::Temp => &SUB_TEMP,
        Sub::Monitors => &SUB_MONITORS,
        Sub::Power => &SUB_POWER,
        Sub::Lock => &SUB_LOCK,
    }
}

fn pick_options(options: &'static [&'static str], script: &'static str, keep: bool) -> Vec<SubEntry> {
    let mut v = vec![back()];
    for label in options {
        v.push(SubEntry {
            label: (*label).to_string(),
            active: false,
            run: Some(Run::Pick { script, env: "TOFI_PICK", keep }),
            sub: None,
        });
    }
    v
}

fn sub_fm(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    let cur = s.get(Kind::Fm).str().unwrap_or("").to_string();
    vec![
        back(),
        SubEntry { label: "PCManFM".into(), active: cur.is_empty() || cur == "pcmanfm", run: Some(Run::Script { script: "file-manager.sh", args: &["pcmanfm"], keep: true }), sub: None },
        SubEntry { label: "Dolphin".into(), active: cur == "dolphin", run: Some(Run::Script { script: "file-manager.sh", args: &["dolphin"], keep: true }), sub: None },
    ]
}

fn sub_schemes(s: &mut States, p: &Paths) -> Vec<SubEntry> {
    let mut v = vec![back()];
    let cur = s.get(Kind::Scheme).str().unwrap_or("").to_string();
    let Ok(src) = fs::read_to_string(&p.schemes_json) else {
        v.push(SubEntry { label: "Biblioteca de esquemas ausente".into(), active: false, run: None, sub: None });
        return v;
    };
    let Ok(list) = serde_json::from_str::<Vec<serde_json::Value>>(&src) else {
        v.push(SubEntry { label: "Biblioteca de esquemas inválida".into(), active: false, run: None, sub: None });
        return v;
    };
    let mut names: Vec<String> = list
        .iter()
        .filter_map(|o| {
            let name = o.get("name")?.as_str()?;
            let variant = o.get("variant").and_then(|x| x.as_str()).unwrap_or("");
            Some(format!("{name} ({variant})"))
        })
        .collect();
    names.sort(); // byte sort, igual ao `sort` do scheme-menu.sh
    if let Some(i) = names.iter().position(|n| n == "Apprentice (dark)") {
        let app = names.remove(i);
        names.insert(0, app);
    }
    for n in names {
        let active = n
            .strip_suffix(" (dark)")
            .or_else(|| n.strip_suffix(" (light)"))
            .is_some_and(|name| name == cur);
        v.push(SubEntry {
            label: n,
            active,
            run: Some(Run::Pick { script: "scheme-menu.sh", env: "TOFI_SCHEME", keep: false }),
            sub: None,
        });
    }
    v
}

fn preset_title(p: &Path) -> String {
    let Ok(src) = fs::read_to_string(p) else {
        return String::new();
    };
    let first = src.lines().next().unwrap_or("");
    let title = first.strip_prefix("// ").unwrap_or(first);
    title.split(" — ").next().unwrap_or(title).trim().to_string()
}

fn sub_fastfetch(s: &mut States, p: &Paths) -> Vec<SubEntry> {
    let mut v = vec![back()];
    let cur = s.get(Kind::Fastfetch).str().unwrap_or("").to_string();
    let Ok(rd) = fs::read_dir(&p.presets) else {
        v.push(SubEntry { label: "Presets ausentes".into(), active: false, run: None, sub: None });
        return v;
    };
    let mut slugs: Vec<(String, String)> = rd
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|x| x == "jsonc"))
        .filter_map(|p| {
            let slug = p.file_stem()?.to_string_lossy().to_string();
            Some((slug, preset_title(&p)))
        })
        .collect();
    slugs.sort_by(|a, b| a.0.cmp(&b.0));
    for (slug, title) in slugs {
        v.push(SubEntry {
            label: if title.is_empty() { slug.clone() } else { title },
            active: cur.is_empty() && slug == "padrao" || cur == slug,
            run: Some(Run::Pick { script: "fastfetch-menu.sh", env: "TOFI_FASTFETCH", keep: true }),
            sub: None,
        });
    }
    v
}

fn sub_tofi(s: &mut States, p: &Paths) -> Vec<SubEntry> {
    let mut v = vec![back()];
    let cur = s.get(Kind::TofiLayout).str().unwrap_or("").to_string();
    let Ok(rd) = fs::read_dir(&p.tofi_themes) else {
        v.push(SubEntry { label: "Temas do Tofi indisponíveis".into(), active: false, run: None, sub: None });
        return v;
    };
    let mut names: Vec<String> = rd
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.join("config").is_file())
        .filter_map(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
        .filter(|n| n != "clipboard" && n != "emoji")
        .collect();
    names.sort();
    for n in names {
        v.push(SubEntry {
            label: n.clone(),
            active: cur == n,
            run: Some(Run::Pick { script: "tofi-themes.sh", env: "TOFI_PICK", keep: true }),
            sub: None,
        });
    }
    v
}

// ---------------------------------------------------------------------------
// Fontes do sistema (fc-list) para os seletores de fonte
// ---------------------------------------------------------------------------

/// Todas as famílias instaladas; fc-list junta estilos com vírgula e ':'
/// quebra a spec de fonte dos apps, então ambos saem da lista (mesmo filtro
/// de ui-font.sh/term-font.sh/mono-font.sh).
fn font_families() -> Vec<String> {
    let Ok(out) = Command::new("fc-list").arg(":").arg("family").output() else {
        return Vec::new();
    };
    let mut fams: Vec<String> = String::from_utf8_lossy(&out.stdout)
        .lines()
        .flat_map(|l| l.split(','))
        .map(str::trim)
        .filter(|f| !f.is_empty() && !f.contains(':'))
        .map(str::to_string)
        .collect();
    fams.sort();
    fams.dedup();
    fams
}

/// Rótulo ativo: chave antiga vira família; valor novo já é a família.
fn legacy_family(legacy: &[(&str, &str)], raw: &str) -> String {
    legacy
        .iter()
        .find(|(k, _)| *k == raw)
        .map(|(_, f)| (*f).to_string())
        .unwrap_or_else(|| raw.to_string())
}

/// Lista dinâmica de fontes; a escolha vai ao script via hook `TOFI_*`
/// (Run::Pick injeta o rótulo no env — mesmo caminho dos pickers do rice).
fn sub_fonts(
    s: &mut States,
    kind: Kind,
    script: &'static str,
    env: &'static str,
    auto: bool,
    legacy: &[(&str, &str)],
) -> Vec<SubEntry> {
    let raw = s.get(kind).str().unwrap_or("").to_string();
    let cur = legacy_family(legacy, &raw);
    let mut v = vec![back()];
    if auto {
        v.push(SubEntry {
            label: "Automática".into(),
            active: raw.is_empty() || raw == "auto",
            run: Some(Run::Pick { script, env, keep: true }),
            sub: None,
        });
    }
    for fam in font_families() {
        v.push(SubEntry {
            label: fam.clone(),
            active: fam == cur,
            run: Some(Run::Pick { script, env, keep: true }),
            sub: None,
        });
    }
    v
}

fn sub_uifont(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    sub_fonts(
        s,
        Kind::UiFont,
        "ui-font.sh",
        "TOFI_UIFONT",
        false,
        &[("noto", "Noto Sans"), ("sf", "SF Pro Display"), ("segoe", "Segoe UI")],
    )
}
fn sub_uisize(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_radio(s, Kind::UiSize, "ui-font-size.sh", "14", &[("12", &["12"]), ("14", &["14"]), ("18", &["18"])])
}
fn sub_termfont(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    sub_fonts(
        s,
        Kind::TermFont,
        "term-font.sh",
        "TOFI_TERMFONT",
        false,
        &[
            ("jetbrains", "JetBrainsMono Nerd Font"),
            ("lexend", "Lexend"),
            ("atkinson", "Atkinson Hyperlegible Mono"),
        ],
    )
}
fn sub_monofont(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    sub_fonts(
        s,
        Kind::MonoFont,
        "mono-font.sh",
        "TOFI_MONOFONT",
        true,
        &[
            ("noto", "Noto Sans Mono"),
            ("jetbrains", "JetBrainsMono Nerd Font"),
            ("atkinson", "Atkinson Hyperlegible Mono"),
        ],
    )
}

fn pick_radio(
    s: &mut States,
    k: Kind,
    script: &'static str,
    def: &'static str,
    options: &'static [(&'static str, &'static [&'static str])],
) -> Vec<SubEntry> {
    let cur = s.get(k).str().unwrap_or("").to_string();
    let mut v = vec![back()];
    for (label, args) in options {
        let key = args.last().copied().unwrap_or("");
        let active = if cur.is_empty() { key == def } else { cur == key };
        v.push(SubEntry {
            label: (*label).to_string(),
            active,
            run: Some(Run::Script { script, args, keep: true }),
            sub: None,
        });
    }
    v
}

fn sub_icons(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    let cur = s.get(Kind::Icons).str().unwrap_or("").to_string();
    let is_papirus = cur == "papirus";
    let mut v = vec![
        back(),
        SubEntry { label: "YAMIS-wal".into(), active: cur.is_empty() || cur == "yamis", run: Some(Run::Script { script: "icon-theme.sh", args: &["yamis"], keep: true }), sub: None },
        SubEntry { label: "Papirus".into(), active: is_papirus, run: Some(Run::Script { script: "icon-theme.sh", args: &["papirus"], keep: true }), sub: None },
    ];
    if is_papirus {
        let variant = papirus_variant_label(&s.get(Kind::PapirusVariant));
        let folders = papirus_folder_label(&s.get(Kind::PapirusFolders));
        v.push(SubEntry { label: format!("Variante do Papirus · {variant} >"), active: false, run: None, sub: Some(Sub::Papirus) });
        v.push(SubEntry { label: format!("Cor das pastas · {folders} >"), active: false, run: None, sub: Some(Sub::Folders) });
        v.push(SubEntry { label: "Corrigir ícones fixos".into(), active: false, run: Some(Run::Script { script: "icon-theme.sh", args: &["hardcode"], keep: true }), sub: None });
    }
    v
}

fn sub_papirus(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_radio(
        s,
        Kind::PapirusVariant,
        "icon-theme.sh",
        "auto",
        &[
            ("Automática", &["variant", "auto"]),
            ("Base", &["variant", "Papirus"]),
            ("Escura", &["variant", "Papirus-Dark"]),
            ("Clara", &["variant", "Papirus-Light"]),
        ],
    )
}

macro_rules! folder_args {
    ($color:literal) => {
        &["folders", $color]
    };
}

fn sub_folders(s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    let cur = s.get(Kind::PapirusFolders).str().unwrap_or("").to_string();
    let mut v = vec![
        back(),
        SubEntry { label: "Automática".into(), active: cur.is_empty() || cur == "auto", run: Some(Run::Script { script: "icon-theme.sh", args: folder_args!("auto"), keep: true }), sub: None },
        SubEntry { label: "Padrão".into(), active: cur == "default", run: Some(Run::Script { script: "icon-theme.sh", args: folder_args!("default"), keep: true }), sub: None },
    ];
    for c in PAPIRUS_FOLDER_COLORS {
        let label = c.to_string();
        let args: &'static [&'static str] = match *c {
            "adwaita" => folder_args!("adwaita"),
            "black" => folder_args!("black"),
            "blue" => folder_args!("blue"),
            "bluegrey" => folder_args!("bluegrey"),
            "breeze" => folder_args!("breeze"),
            "brown" => folder_args!("brown"),
            "carmine" => folder_args!("carmine"),
            "cyan" => folder_args!("cyan"),
            "darkcyan" => folder_args!("darkcyan"),
            "deeporange" => folder_args!("deeporange"),
            "green" => folder_args!("green"),
            "grey" => folder_args!("grey"),
            "indigo" => folder_args!("indigo"),
            "magenta" => folder_args!("magenta"),
            "nordic" => folder_args!("nordic"),
            "orange" => folder_args!("orange"),
            "palebrown" => folder_args!("palebrown"),
            "paleorange" => folder_args!("paleorange"),
            "pink" => folder_args!("pink"),
            "teal" => folder_args!("teal"),
            "white" => folder_args!("white"),
            "yellow" => folder_args!("yellow"),
            _ => unreachable!("cor fora da lista"),
        };
        v.push(SubEntry {
            label,
            active: cur == *c,
            run: Some(Run::Script { script: "icon-theme.sh", args, keep: true }),
            sub: None,
        });
    }
    v
}

const PAPIRUS_FOLDER_COLORS: &[&str] = &[
    "adwaita", "black", "blue", "bluegrey", "breeze", "brown", "carmine", "cyan", "darkcyan",
    "deeporange", "green", "grey", "indigo", "magenta", "nordic", "orange", "palebrown",
    "paleorange", "pink", "teal", "white", "yellow",
];

fn sub_temp(_s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_options(&["1000 K — noite", "2000 K", "3000 K", "4500 K", "6500 K — dia", "Escurecer (gamma 0.8)", "Normal (gamma 1.0)", "Desligar"], "nightmenu.sh", true)
}
fn sub_monitors(_s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_options(&["Auto (HDMI)", "Apenas HDMI", "Apenas notebook", "Estender", "Espelhar"], "monitormenu.sh", true)
}
fn sub_power(_s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_options(&["Suspender em 5 min", "Suspender em 10 min", "Suspender em 15 min", "Suspender em 30 min", "Nunca suspender", "Tampa fechada: suspender", "Tampa fechada: apenas desligar a tela"], "powermenu.sh", true)
}
fn sub_lock(_s: &mut States, _p: &Paths) -> Vec<SubEntry> {
    pick_options(&["Bloquear em 1 min", "Bloquear em 2 min", "Bloquear em 5 min", "Bloquear em 10 min", "Bloquear em 15 min", "Bloquear em 30 min", "Bloquear em 1 hora", "Nunca bloquear"], "lockmenu.sh", true)
}

// ---------------------------------------------------------------------------
// Rótulos de estado (" · X" ao lado do item)
// ---------------------------------------------------------------------------

pub fn state_label(s: &mut States, p: &Paths, k: Kind) -> String {
    match k {
        Kind::Autotiling => flag_label(s.get(k), "Ativada", "Desativada"),
        Kind::Dnd => flag_label(s.get(k), "silenciados", "ativados"),
        Kind::Game => flag_label(s.get(k), "Ativado", "Desligado"),
        Kind::Night => flag_label(s.get(k), "Ligada", "Desligada"),
        Kind::Bar => flag_label(s.get(k), "Visível", "Oculta"),
        Kind::ClockFull => flag_label(s.get(k), "Data e hora", "Hora"),
        Kind::Mode => match s.get(k).str() {
            Some("light") => "Claro".into(),
            _ => "Escuro".into(),
        },
        Kind::Scheme => str_label(s, k, "Apprentice"),
        Kind::Fastfetch => {
            let slug = s.get(k).str().unwrap_or("").to_string();
            if slug.is_empty() {
                "padrão".into()
            } else {
                preset_title(&p.presets.join(format!("{slug}.jsonc")))
            }
        }
        Kind::TofiLayout => str_label(s, k, "padrao"),
        Kind::UiFont => match s.get(k).str() {
            Some("sf") => "SF Pro".into(),
            Some("segoe") => "Segoe UI".into(),
            _ => "Noto Sans".into(),
        },
        Kind::UiSize => str_label(s, k, "14"),
        Kind::TermFont => match s.get(k).str() {
            Some("lexend") => "Lexend".into(),
            Some("atkinson") => "Atkinson Hyperlegible Mono".into(),
            _ => "JetBrains Mono".into(),
        },
        Kind::MonoFont => match s.get(k).str() {
            Some("noto") => "Noto Sans Mono".into(),
            Some("jetbrains") => "JetBrains Mono".into(),
            Some("atkinson") => "Atkinson Hyperlegible Mono".into(),
            _ => "Automática".into(),
        },
        Kind::Icons => match s.get(k).str() {
            Some("papirus") => "Papirus".into(),
            _ => "YAMIS".into(),
        },
        Kind::PapirusVariant => papirus_variant_label(&s.get(k)),
        Kind::PapirusFolders => papirus_folder_label(&s.get(k)),
        Kind::Fm => match s.get(k).str() {
            Some("dolphin") => "Dolphin".into(),
            _ => "PCManFM".into(),
        },
        Kind::LockTimeout => lock_label(&s.get(k)),
        Kind::Battery => {
            let v = s.get(k).str().unwrap_or("").to_string();
            if v.is_empty() || v == "—" {
                "—".into()
            } else {
                format!("{v}%")
            }
        }
        Kind::Time => s.get(k).str().unwrap_or("").to_string(),
        Kind::Date => s.get(k).str().unwrap_or("").to_string(),
    }
}

fn flag_label(v: Value, on: &str, off: &str) -> String {
    if v.flag() { on.into() } else { off.into() }
}

fn str_label(s: &mut States, k: Kind, def: &str) -> String {
    let v = s.get(k).str().unwrap_or("").to_string();
    if v.is_empty() { def.to_string() } else { v }
}

fn lock_label(v: &Value) -> String {
    let raw = v.str().unwrap_or("");
    let secs: u64 = raw.parse().unwrap_or(300);
    match secs {
        0 => "Nunca".into(),
        _ if secs >= 3600 => format!("{} h", secs / 3600),
        _ => format!("{} min", secs / 60),
    }
}

fn papirus_variant_label(v: &Value) -> String {
    match v.str() {
        Some("Papirus") => "Base".into(),
        Some("Papirus-Dark") => "Escura".into(),
        Some("Papirus-Light") => "Clara".into(),
        _ => "Automática".into(),
    }
}

fn papirus_folder_label(v: &Value) -> String {
    match v.str() {
        Some("") | Some("auto") => "Automática".into(),
        Some("default") => "Padrão".into(),
        Some(x) => x.to_string(),
        None => "Automática".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn states() -> States {
        States::new()
    }

    #[test]
    fn todas_as_abas_tem_acoes() {
        for (_, v) in VIEWS {
            let n = roots_for(v).count();
            assert!(n > 0, "view sem ações: {v:?}");
        }
        assert!(roots_for(View::All).count() >= roots_for(View::Sys).count());
    }

    #[test]
    fn root_rotulos_sem_duplicata() {
        let mut seen = std::collections::HashSet::new();
        for r in ROOTS {
            assert!(seen.insert(r.label), "rótulo duplicado: {}", r.label);
        }
    }

    #[test]
    fn sub_titulos_e_voltar() {
        for sub in [Sub::Fm, Sub::Schemes, Sub::Temp, Sub::Power, Sub::Lock, Sub::Monitors] {
            let sdef = sub_def(sub);
            let entries = (sdef.loader)(&mut states(), &Paths::load());
            assert!(entries[0].label == "< Voltar");
            assert!(!sdef.title.is_empty());
        }
    }

    #[test]
    fn pickers_tem_scripts() {
        let sdef = sub_def(Sub::Temp);
        let entries = (sdef.loader)(&mut states(), &Paths::load());
        assert!(entries[1].run.is_some());
    }
}