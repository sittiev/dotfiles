# Rice dotfiles

Canonical dotfiles for this CachyOS/Sway desktop.

## Scope

- Sway 1.12 on Wayland
- Foot 1.28
- Tofi launcher
- Yambar bar
- Pywal/WAL theme pipeline
- Swaybg + Waypaper wallpaper selection and dynamic palette refresh
- Mako notifications
- GTK 3/4 settings

The repository was initialized from the live configuration on 2026-09-23.
The original files in `~/.config` were not deleted.

## Layout

```text
sway/       Sway config and scripts
foot/       Foot configuration
yambar/     Yambar configuration
tofi/       Tofi config and themes
mako/       Mako configuration
gtk/        GTK settings used by the theme pipeline
shell/      Bash startup files
systemd/    User-service files and notes
.opencode/  Project-local OpenCode skills
docs/       Environment notes
scripts/    Validation helpers
```

## Source/generated files

Edit the source files, not generated output:

- `sway/scripts/colorlib.sh`
- `sway/scripts/theme-mode.sh`
- `sway/scripts/render.sh`
- `sway/scripts/theme.sh`
- `sway/scripts/wallpaper.sh`
- `tofi/themes/*/config`

The following are generated snapshots and are marked in their headers:

- `foot/foot.ini` color section and `initial-color-theme`
- `yambar/config.yml`
- `tofi/config` color block
- `mako/config`
- `sway/scripts/swaynag-exit.sh`

## Validate

```sh
./scripts/validate.sh
```

Or run the checks directly:

```sh
sway --validate -c sway/config
foot --check-config -c foot/foot.ini
dash -n sway/scripts/*.sh
checkbashisms sway/scripts/*.sh
```

The scripts target `dash` (`extra/dash`); `validate.sh` enforces `dash -n` and
`checkbashisms` on every script under `sway/scripts/` and `scripts/`.

## Wallpaper

Install `swaybg` from the official repositories and `waypaper` from the AUR:

```sh
sudo pacman -S swaybg
yay -S waypaper
```

Open **Mod+Shift+x → Papel de parede**. Waypaper uses `swaybg`; its
`post_command` runs `theme.sh`, so selecting an image also updates the
Pywal palette and the rendered light/dark theme. Sway restores the last
image with `waypaper --restore` at startup; no additional wallpaper
shortcut is created.

Two guards make that link reliable:

- `wallpaper.sh` never passes `--backend` to waypaper (the backend stays
  in `waypaper/config.ini`). Waypaper picks the previous `swaybg` with
  `pgrep -f swaybg`, and a command line containing `swaybg` matched
  waypaper itself: it could kill its own process before `post_command`,
  so the wallpaper changed but the theme did not (the "press twice"
  bug) and orphaned `swaybg` processes piled up.
- `theme.sh` takes a `flock` on `$XDG_RUNTIME_DIR/waltheme.lock` and runs
  its body in a subshell with the lock fd closed, so concurrent runs
  serialize instead of racing, while long-lived children (`yambar`,
  `mako`) cannot keep the lock forever.

The startup restore uses `--no-post-command`: `sway/config` already runs
`theme.sh` once, so the palette is generated a single time per session.

### Ícones

`theme-mode.sh` chama `sway/scripts/icon-recolor.sh`, que gera
`~/.local/share/icons/yamis-wal`: uma cópia do YAMIS
(yet-another-monochrome-icon-set) com as cores `.ColorScheme-Text`,
`.ColorScheme-Highlight` e o tom secundário trocados pelos tokens da
paleta (FG / ACCENT / MUTED). O SVG usa `fill:currentColor` dentro do
bloco `<style>`, então os ícones acompanham o wallpaper e o modo
light/dark junto com o texto. O tema base nunca é alterado: a cópia é
feita com hardlinks e a reescrita usa tmp+rename (o inode original fica
intocado); a ativação acontece no gsettings, `settings.ini`, `.gtkrc-2.0`
e `kdeglobals`. Custo por troca de wallpaper: ~0,7 s.

### GTK backgrounds

`theme-mode.sh apply` also writes the user stylesheets
`~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css` (marker
`wal-gtk`, regenerated on every run), plus `colors.css` and
`~/.gtkrc-2.0`. Qogir hardcodes hex values and ignores its own
`@define-color`, so the file carries explicit `.background`, `headerbar`,
`entry`, `.view`, `button`, menu and selection rules that re-tint the
theme with the palette. GTK reads CSS only at startup: restart an open
GTK application to see a new wallpaper's colors.

## Activation

The selected live paths are linked to this repository by
`scripts/install-links.sh`. The first activation backed up the originals to:

```text
~/.local/state/dotfiles-backup/20260923-215929-346623
```

The Sway backup directory remains outside this repository. Re-run the installer
only after reviewing its dry-run output.

## OpenCode integration

The global OpenCode configuration restricts the filesystem MCP to this
repository (`/home/rafael/dotfiles`). Actions are allowed by default; only a
direct `git push` asks for explicit approval. Keep API keys in environment
variables, not in this repository.

## OpenCode skill

`wl` is a project-local skill sourced from `~/Downloads/SKILL.md` and exposed
globally through a symlink at `~/.config/opencode/skills/wl`.

It documents `ov eval wl` automation for containerized/selkies environments.
The local host does not currently provide `ov`, `wlrctl`, or `wlr-randr`; use
native Sway tools for local desktop actions.
