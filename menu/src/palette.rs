//! Paleta viva do pywal (`~/.cache/wal/colors.sh`) + estilo do TUI.
//!
//! O rice herda as cores do wallpaper (README: "A wallpaper gives the
//! palette"); o menu mostra a paleta no canto e usa as mesmas cores no
//! próprio desenho. Ausência do arquivo (sem pywal) degrada para os
//! estilos default do terminal — menu continua 100% funcional.

use std::fs;
use std::path::{Path, PathBuf};

/// Cores da paleta (hex em `Option`; `None` = terminal decide).
#[derive(Default, Clone)]
pub struct Palette {
    pub background: Option<(u8, u8, u8)>,
    pub foreground: Option<(u8, u8, u8)>,
    pub colors: [Option<(u8, u8, u8)>; 16],
}

impl Palette {
    /// Lê `~/.cache/wal/colors.sh` (formato pywal16: `colorN='#rrggbb'`).
    pub fn load(cache: &Path) -> Self {
        let mut p = Palette::default();
        let Ok(src) = fs::read_to_string(cache.join("wal").join("colors.sh")) else {
            return p;
        };
        for line in src.lines() {
            let Some(eq) = line.find('=') else { continue };
            let key = line[..eq].trim();
            let val = line[eq + 1..].trim();
            let val = val.strip_prefix('\'').and_then(|v| v.strip_suffix('\''));
            let Some(hex) = val.and_then(parse_hex) else { continue };
            match key {
                "background" => p.background = Some(hex),
                "foreground" => p.foreground = Some(hex),
                k if k.starts_with("color") => {
                    let Some(n) = k["color".len()..].parse::<usize>().ok().filter(|&n| n < 16) else {
                        continue;
                    };
                    p.colors[n] = Some(hex);
                }
                _ => {}
            }
        }
        p
    }

    /// Tem paleta de wallpaper (senão, estilos default).
    pub fn has_wall(&self) -> bool {
        self.background.is_some() && self.foreground.is_some()
    }
}

fn parse_hex(s: &str) -> Option<(u8, u8, u8)> {
    let s = s.trim_start_matches('#');
    if s.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&s[0..2], 16).ok()?;
    let g = u8::from_str_radix(&s[2..4], 16).ok()?;
    let b = u8::from_str_radix(&s[4..6], 16).ok()?;
    Some((r, g, b))
}

/// Nome do scheme Gogh ativo + modo (defaults do rice: Apprentice / dark).
pub struct SchemeInfo {
    pub name: String,
    pub mode: String,
}

impl SchemeInfo {
    pub fn load(cache: &Path) -> Self {
        let name = read_trim(cache.join("theme-scheme"))
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "Apprentice".to_string());
        let mode = match read_trim(cache.join("theme-mode")).as_deref() {
            Some("light") => "claro".to_string(),
            _ => "escuro".to_string(),
        };
        SchemeInfo { name, mode }
    }
}

fn read_trim(p: PathBuf) -> Option<String> {
    fs::read_to_string(p).ok().map(|s| s.trim().to_string())
}

/// Formata `#rrggbb` para exibição no painel da paleta.
pub fn hex_str(c: (u8, u8, u8)) -> String {
    format!("#{:02x}{:02x}{:02x}", c.0, c.1, c.2)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn tmp_cache(src: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("menu-palette-test-{}", std::process::id()));
        let wal = dir.join("wal");
        fs::create_dir_all(&wal).unwrap();
        let mut f = fs::File::create(wal.join("colors.sh")).unwrap();
        f.write_all(src.as_bytes()).unwrap();
        dir
    }

    #[test]
    fn parse_pywal_colors() {
        let dir = tmp_cache(
            "wallpaper=\"/x.jpg\"\nbackground='#2a2a2a'\nforeground='#c9c9c9'\n\
             color0='#000000'\ncolor4='#00aaFF'\ncolor15='#ffffff'\n",
        );
        let p = Palette::load(&dir);
        assert_eq!(p.background, Some((0x2a, 0x2a, 0x2a)));
        assert_eq!(p.foreground, Some((0xc9, 0xc9, 0xc9)));
        assert_eq!(p.colors[0], Some((0, 0, 0)));
        // maiúsculas no hex valem
        assert_eq!(p.colors[4], Some((0x00, 0xaa, 0xff)));
        assert_eq!(p.colors[15], Some((0xff, 0xff, 0xff)));
        // demais cores ausentes
        assert_eq!(p.colors[1], None);
        assert!(p.has_wall());
        fs::remove_dir_all(dir.parent().unwrap()).ok();
    }

    #[test]
    fn sem_arquivo_degrada() {
        let p = Palette::load(Path::new("/tmp/nao-existe-menu"));
        assert!(!p.has_wall());
        assert_eq!(p.colors[0], None);
    }

    #[test]
    fn scheme_info_defaults() {
        let dir = tmp_cache("background='#000000'\n");
        let s = SchemeInfo::load(&dir);
        assert_eq!(s.name, "Apprentice");
        assert_eq!(s.mode, "escuro");
        fs::create_dir_all(dir.join("theme-mode")).ok();
        fs::remove_dir_all(dir.parent().unwrap()).ok();
    }

    #[test]
    fn hex_format() {
        assert_eq!(hex_str((0x2a, 0x2a, 0x2a)), "#2a2a2a");
    }
}