# Rice dotfiles

Sway desktop for CachyOS. A wallpaper gives the palette (Pywal), the
wallpaper's luminance picks light or dark, and an optional Gogh scheme
(1247 vendored) clamps everything into its envelopes. Initialized from the
live config on 2026-09-23; nothing under `~/.config` was deleted.

## Requirements

Official repos:

```sh
sudo pacman -S sway foot mako kanshi swaybg waypaper grim slurp wl-clipboard wtype \
    cliphist lxqt-policykit jq dash python glib2 \
    ttf-jetbrains-mono-nerd noto-fonts ttf-atkinson-hyperlegible
```

AUR, via `paru`:

```sh
paru -S tofi yambar python-pywal16 qogir-gtk-theme swaylock-effects-git lexend-fonts-git
```

Validation tools and optional theme consumers (all official; the writers
skip them when absent, see `docs/PENDING.md`):

```sh
sudo pacman -S checkbashisms qt6ct qt5ct ly
```

YAMIS, the icon set, is not packaged: put it at
`~/.local/share/icons/yet-another-monochrome-icon-set`. Without it the
theme still works; only the recolored `yamis-wal` copy is skipped.

## Post-install

```sh
DRY_RUN=1 ./scripts/install-links.sh   # preview
./scripts/install-links.sh             # symlinks live paths here
./scripts/validate.sh
```

The installer moves each replaced file to
`~/.local/state/dotfiles-backup/<stamp>` before linking. Then start Sway
(`theme.sh` runs at login) or run `~/.config/sway/scripts/theme.sh` by hand.

Two menu entries drive the desktop:

- **Mod+Shift+x → Papel de parede**: wallpaper, palette, light/dark
- **Mod+Shift+x → Esquemas de cores**: one of the 1247 Gogh schemes

## Layout

```text
sway/         Sway config and scripts
sway/schemes/ Vendored Gogh scheme library (see sway/schemes/README.md)
foot/         Foot configuration
yambar/       Yambar configuration
tofi/         Tofi config and themes
mako/         Mako configuration
kanshi/       Kanshi hotplug profiles (auto; manual stays in sway/scripts/outputs.sh)
pcmanfm/      PCManFM clean config + context actions (gram/micro/foot)
gtk/          GTK settings used by the theme pipeline
shell/        Bash startup files
systemd/      User-service files and notes
.opencode/    Project-local OpenCode skills
docs/         Environment notes
scripts/      Validation helpers
```

## Source/generated files

Edit the source files, not generated output:

- `sway/scripts/colorlib.sh`, `schemelib.sh`, `theme-mode.sh`, `render.sh`,
  `theme.sh`, `wallpaper.sh`, `scheme-menu.sh`
- `tofi/themes/*/config`

`sway/schemes/gogh-themes-min.json` is vendored data: refresh it with
`scripts/update-schemes.sh`, never by hand. The `overrides/*.env` files are
curated by hand.

Generated snapshots, marked in their headers:

- `foot/foot.ini` color section and `initial-color-theme`
- `yambar/config.yml`
- `tofi/config` color block
- `mako/config`
- `sway/scripts/swaynag-exit.sh`

## Validate

```sh
./scripts/validate.sh
```

Or the checks by hand:

```sh
sway --validate -c sway/config
foot --check-config -c foot/foot.ini
dash -n sway/scripts/*.sh
checkbashisms sway/scripts/*.sh
```

Scripts target `dash`. `validate.sh` runs the syntax and bashism checks on
every script under `sway/scripts/` and `scripts/`, plus
`scripts/test-schemelib.sh` and the `sway/schemes` data check.

## Wallpaper

Sway restores the last image with `waypaper --restore` at startup
(`--no-post-command`; `sway/config` already ran `theme.sh` once, so the
palette is generated a single time per session). Waypaper's `post_command`
runs `theme.sh`, so picking an image also updates the palette and the
rendered theme. No wallpaper shortcut is created.

Two invariants when editing this path:

- `wallpaper.sh` never passes `--backend` to waypaper (the backend stays in
  `waypaper/config.ini`). Waypaper finds the previous `swaybg` with
  `pgrep -f swaybg`, and a command line containing `swaybg` matched waypaper
  itself: it could kill its own process before `post_command`, so the
  wallpaper changed but the theme did not (the "press twice" bug), and
  orphaned `swaybg` processes piled up.
- `theme.sh` takes a `flock` on `$XDG_RUNTIME_DIR/waltheme.lock` and runs
  its body in a subshell with the lock fd closed, so concurrent runs
  serialize instead of racing, while long-lived children (`yambar`, `mako`)
  cannot keep the lock forever.

### Ícones

`theme-mode.sh` chama `icon-recolor.sh`, que gera
`~/.local/share/icons/yamis-wal`: cópia do YAMIS com as cores
`.ColorScheme-Text`, `.ColorScheme-Highlight` e o tom secundário trocadas
pelos tokens FG / ACCENT / MUTED. A cópia usa hardlinks e reescrita com
tmp+rename; o tema base nunca é alterado. Ativação via gsettings,
`settings.ini`, `.gtkrc-2.0` e `kdeglobals`. Custo: ~0,7 s por troca de
wallpaper.

### GTK backgrounds

`theme-mode.sh apply` writes `~/.config/gtk-3.0/gtk.css`,
`~/.config/gtk-4.0/gtk.css`, `colors.css` and `~/.gtkrc-2.0` (marker
`wal-gtk`, regenerated on every run). Qogir hardcodes hex values, so the
file carries explicit `.background`, `headerbar`, `entry`, `.view`, `button`,
menu and selection rules that re-tint the theme with the palette. GTK reads
CSS only at startup: restart an open application to see a new wallpaper's
colors.

## Esquemas de cores

**Mod+Shift+x → "Esquemas de cores"** lista os 1247 esquemas Gogh no Tofi.
A escolha grava o nome em `~/.cache/theme-scheme` e roda `theme.sh`; apagar
o arquivo volta ao caminho sem esquema (constantes Apprentice atuais,
byte-idêntico ao comportamento original). O picker valida o nome contra o
JSON antes de gravar (escrita atômica) e `TOFI_SCHEME=<nome>` aplica sem
abrir o menu.

Wallpaper ainda manda no light/dark: quando a `variant` do esquema não bate
com o modo, o L de cada papel espelha (`L' = 100 − L`, S intacto).

**Divisão de trabalho: a imagem dá a cor, o esquema dá o contraste.**
`schemelib.sh` lê a assinatura do wallpaper no pywal (`WALL_H` hue médio
circular, `WALL_S` croma médio, `WALL_SPREAD` maior diferença circular entre
matizes) e exporta as envelopes de L do esquema para `BG FG ACC MUT BRI`. Com
âncora do wallpaper, as duas últimas peças entram em jogo:

- **Hue** — `ENV_<papel>_H = WALL_H`: BG/FG/ACC/MUT saem na família da imagem.
  O fundo claro também sobe o L preservando H e S do pywal, em vez de
  `mix(cor, branco, 0.80)`, que dissolvia o croma e dava cinza neutro num
  wallpaper azul.
- **Croma** — as envelopes de S são descartadas (`_chroma_free`) e só sobra o
  teto `WALL_S × 1.8` (`_chroma_cap`), para o esquema não importar mais cor
  do que a imagem tem (um S=100 num wallpaper de S=23 punha um azul elétrico
  de seleção). O accent ganha piso no próprio `WALL_S`, que é o único papel
  que precisa gritar "isto está selecionado".
- **Janela de matiz** — os 16 ANSI do foot saem do `color_01..16` do JSON (sem
  eles um wallpaper pastel sem croma gerava 16 cinzas), mas cada hue é
  **preso a `WALL_H ± spread×2+12`**, com `spread` da própria imagem: wallpaper
  monocromático (spread 4°) recebe janela estreita, wallpaper colorido
  (spread 150°) recebe janela larga. Nem comprimir o spread (colava os 8
  slots na mesma cor) nem só rotacionar (deixava o spread de ~300° do
  esquema pintar o terminal de magenta) resolvem os dois. O croma dos slots
  é reescalado por `WALL_S / S_scheme`.
- **Slots 0/7/8/15** (black/white e os "bright") saem com S=0: são acromáticos
  por convenção do ANSI, e o clamp de S os tingiria — o "black" do terminal
  saía marrom.

Envelopes de override (`sway/schemes/overrides/<nome>.env`) ficam de fora
desse ajuste: são curadas à mão, e `apprentice.env` precisa continuar
byte-idêntico no dark. Esquema desconhecido/ausente ⇒ fallback completo nas
constantes atuais. Detalhes em `sway/schemes/README.md`.

## OpenCode

The global OpenCode configuration restricts the filesystem MCP to this
repository. Actions are allowed by default; only a direct `git push` asks
for explicit approval. Keep API keys in environment variables.

The project-local `wl` skill (from `~/Downloads/SKILL.md`, symlinked at
`~/.config/opencode/skills/wl`) documents `ov eval wl` automation for
containerized/selkies environments. This host has no `ov`, `wlrctl` or
`wlr-randr`; use native Sway tools for local desktop actions.
