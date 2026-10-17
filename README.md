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
    ttf-jetbrains-mono-nerd noto-fonts notcurses
```

AUR, via `paru`:

```sh
paru -S tofi yambar python-pywal16 qogir-gtk-theme swaylock-effects-git lexend-fonts-git ttf-atkinson-hyperlegible-next-mono
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
- **Clique no chip de tarefas (yambar)**: abre a TUI de tarefas do vault
  Obsidian (binário C `yambar-tasks-c` em `foot` floating, notcurses;
  `yambar-tasks.py` de fallback) — espaço conclui/reabre
  o checkbox no arquivo (carimbando `✅`), `/` busca sem acento,
  `o` alterna a ordem (recentes, antigas, texto A–Z, arquivo, criadas),
  d mostra detalhes (criada/concluída), n cria tarefa nova no
  `Inbox/Notepad.md` (carimbo `➕`), Enter abre a nota no Obsidian.
  Compila com `make -C sway/scripts yambar-tasks-c` (exige `notcurses`)
- **Mod+Shift+f → Busca de arquivos**: FSearch-like instantânea via
  `plocate` + tofi (`fsearch.sh`) — índice do timer systemd, zero daemon
- **Clique no chip "directories" (extremo esquerdo do yambar)**: TUI em
  `foot` floating com diretórios pinados (`~/.cache/dirs-pinadas`,
  `yambar-dirs.py`); `a` fixa, `d` remove, Enter abre no gerenciador

## Stack

Coleção awesome do rice: componente, 1 linha, onde mora aqui, fonte.
`—` = autoral/local, sem upstream.

### Compositor e sessão

| Componente | Descrição | Neste repo | Fonte |
| --- | --- | --- | --- |
| [Sway](https://github.com/swaywm/sway/wiki) | Compositor Wayland tiling | `sway/` | [wiki](https://github.com/swaywm/sway/wiki) · [guia i3](https://i3wm.org/docs/userguide.html) |
| autotiling-rs | Alterna split h/v pela proporção da janela | `sway/config` (exec_always) | binário AUR |
| [swaytiles](https://github.com/sertacartun/swaytiles) | Layouts por workspace (master, dwindle, grid) | `Mod+Shift+t` | [repo](https://github.com/sertacartun/swaytiles) |
| [sway-alttab-gui](https://github.com/itsjfx/sway-alttab-gui) | Alt-Tab estilo Windows via IPC, daemon sem polling | `Alt+Tab` | [repo](https://github.com/itsjfx/sway-alttab-gui) |
| [kanshi](https://github.com/emersion/kanshi) | Perfis de saída no hotplug | `kanshi/` | [repo](https://github.com/emersion/kanshi) |
| [ly](https://codeberg.org/fairyglade/ly) | Login TUI leve | — | [repo](https://codeberg.org/fairyglade/ly) · [archwiki](https://wiki.archlinux.org/title/Ly) |
| [swayidle](https://github.com/swaywm/swayidle) + idle.sh | Bloqueio/suspend por inatividade | `sway/scripts/idle.sh` | [repo](https://github.com/swaywm/swayidle) |
| [swaylock-effects](https://github.com/mortie/swaylock-effects) | Locker com efeitos | `sway/scripts/swaylock.sh` | [repo](https://github.com/mortie/swaylock-effects) · [man](https://man.archlinux.org/man/swaylock.1.en) |

### Barra e menus

| Componente | Descrição | Neste repo | Fonte |
| --- | --- | --- | --- |
| [Yambar](https://github.com/neonkore/yambar) | Barra leve e configurável p/ Wayland | `yambar/` | [repo](https://github.com/neonkore/yambar) · [AUR](https://aur.archlinux.org/packages/yambar) |
| Tarefas | Chip + TUI curses dos checkboxes do vault | `sway/scripts/yambar-tasks.py` | — |
| Directories | Chip + TUI curses de diretórios pinados | `sway/scripts/yambar-dirs.py` | — |
| Relógio | Chip hora; clique alterna data+hora | `sway/scripts/yambar-clock.sh` | — |
| Tofi | Launcher/dmenu Wayland | `tofi/` | pacote AUR |
| Hub tofi-menu | Menu estilo Ajustes Apple (busca flat + categorias) | `sway/scripts/tofi-menu.sh` | — |

### Terminal e shell

| Componente | Descrição | Neste repo | Fonte |
| --- | --- | --- | --- |
| [Foot](https://codeberg.org/dnkl/foot) | Terminal Wayland leve | `foot/` | [repo](https://codeberg.org/dnkl/foot) |
| [dash](https://wiki.archlinux.org/title/Dash) | Shell de todos os scripts (latência) | `sway/scripts/*.sh` | [archwiki](https://wiki.archlinux.org/title/Dash) |
| Bash | Shell interativo | `shell/` | — |

### Tema e aparência

| Componente | Descrição | Neste repo | Fonte |
| --- | --- | --- | --- |
| python-pywal16 | Paleta extraída do wallpaper | `sway/scripts/theme.sh` | pacote AUR |
| Gogh (1247) | Biblioteca de esquemas p/ clamp de contraste | `sway/schemes/` | `scripts/update-schemes.sh` |
| [Qogir](https://github.com/vinceliuice/Qogir-theme) | Tema GTK | — | [repo](https://github.com/vinceliuice/Qogir-theme) |
| [Kvantum](https://github.com/tsujan/Kvantum) + qt5ct/qt6ct | Qt com cara de GTK | — | [repo](https://github.com/tsujan/Kvantum) · [guia](https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications) |
| [nwg-look](https://github.com/nwg-piotr/nwg-look) | Ajuste GTK com preview ao vivo | — | [repo](https://github.com/nwg-piotr/nwg-look) |
| YAMIS | Ícones monocromáticos (cópia `yamis-wal` recolorida) | `~/.local/share/icons/` | — |
| Waypaper | Seletor de wallpaper (dono do swaybg) | `sway/scripts/wallpaper.sh` | pacote oficial |
| Fontes pixel | Minecraft, Monocraft, VT323, Pixel Operator… vendidas no repo | `fonts/` · `scripts/install-fonts.sh` | `fonts/pixel/SOURCES.md` |

### Apps e captura

| Componente | Descrição | Neste repo | Fonte |
| --- | --- | --- | --- |
| [PCManFM](https://wiki.archlinux.org/title/PCManFM) | Gerenciador de arquivos + actions | `pcmanfm/` | [archwiki](https://wiki.archlinux.org/title/PCManFM) |
| [Mako](https://github.com/emersion/mako) | Daemon de notificações/OSD | `mako/` | [repo](https://github.com/emersion/mako) |
| [grim](https://github.com/emersion/grim) + [slurp](https://github.com/emersion/slurp) | Screenshot de região p/ clipboard | binds `Print` | [grim](https://github.com/emersion/grim) · [slurp](https://github.com/emersion/slurp) |
| [cliphist](https://github.com/sentriz/cliphist) | Histórico do clipboard | `sway/scripts/cliphist-watch.sh` | [repo](https://github.com/sentriz/cliphist) |
| plocate + fsearch.sh | Busca de arquivos instantânea, zero daemon | `Mod+Shift+f` | pacote oficial |
| [Obsidian](https://obsidian.md) | Vault fonte das tarefas do chip | TUI de tarefas | [site](https://obsidian.md) |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | Sysinfo no terminal | `fastfetch/` | [repo](https://github.com/fastfetch-cli/fastfetch) |

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
- `sway/scripts/yambar-tasks.py` (TUI de tarefas do vault; `yambar-tasks.sh`
  emite a contagem do chip e o clique delega a `yambar-tasks-toggle.sh`)

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

## Bloqueio automático

**Mod+Shift+x → Sistema → Bloqueio automático** define o tempo até o
`swaylock` travar a tela sozinho: 1 min, 2 min, 5 min, 10 min, 15 min,
30 min, 1 h ou nunca. A escolha grava `~/.cache/lock-timeout` em segundos e
reinicia `sway/scripts/idle.sh`, dono do `swayidle`:

- o valor vale na tomada e na bateria (`battery.sh` só escolhe quando apagar
  as telas: 5 min na bateria, 10 min na tomada);
- "Nunca bloquear" (0) remove o `timeout` do travamento, mas `lock` e
  `before-sleep` continuam — o `Mod+Shift+Escape` e a suspensão travam igual;
- apagar telas e suspender (`Mod+Shift+x → Energia`,
  `~/.cache/suspend-timeout`) são independentes: escolher 1 h de bloqueio não
  muda o suspend;
- sem o arquivo, `idle.sh` usa 300 s.

## OpenCode

The global OpenCode configuration restricts the filesystem MCP to this
repository. Actions are allowed by default; only a direct `git push` asks
for explicit approval. Keep API keys in environment variables.

The project-local `wl` skill (from `~/Downloads/SKILL.md`, symlinked at
`~/.config/opencode/skills/wl`) documents `ov eval wl` automation for
containerized/selkies environments. This host has no `ov`, `wlrctl` or
`wlr-randr`; use native Sway tools for local desktop actions.
