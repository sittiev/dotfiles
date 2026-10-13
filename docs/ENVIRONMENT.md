# Environment notes

Recorded from the live host on 2026-09-23.

| Component | Version / state |
|---|---|
| Distribution | CachyOS rolling, Arch-based |
| Kernel | 7.2.6-1-cachyos |
| Session | Wayland, `sway:wlroots` |
| Window manager | Sway 1.12 |
| Terminal | Foot 1.28.0 |
| Launcher | Tofi |
| Status panel | Yambar 1.11.0 |
| Theme backend | `python-pywal16` / `wal` |
| Script shell | dash 0.5.13 |
| GPU | AMD Radeon 610M |
| OpenCode | v2.0.14 |

The live configuration passed `sway --validate`, `foot --check-config`,
`dash -n`, and `checkbashisms` for the Sway scripts at the time this
repository was created.

## Optional tools

`wtype`, `wl-copy`, `grim`, `slurp`, and `swaymsg` are available locally.
`ov`, `wlrctl`, and `wlr-randr` are not currently installed; the `wl` skill is
for a separate `ov`/selkies automation environment.

## Vault tasks chip (2026-10-11)

| Piece | State |
|---|---|
| Chip | `render.sh` writes a second yambar particle (left of the clock): `yambar-tasks.sh` polled every 2s emits `NN` open checkboxes |
| Scan | `sway/scripts/tasks-core.c` owns the task scope (C port of `yambar-tasks.py`, same contract): `~/Documentos/Vault/**/*.md`, skipping `Arquivo/`, `Memória de Agentes/`, `Recursos/AI/`, dot dirs, and fenced code blocks; open first, then file mtime desc |
| TUI | `sway/scripts/yambar-tasks.c` (notcurses, built by `sway/scripts/Makefile` → `yambar-tasks-c`, gitignored); click opens `foot -a yambar-tasks` (floating rule in `sway/config`); space toggles the checkbox in place (tmp+rename), stamping `✅ YYYY-MM-DD HH:MM` when completing (removed on reopen; Tasks-plugin style, plain text); Enter opens the note via `obsidian://open`, `/` live search (fold manual Latin-1/Extended-A/grego/cirílico + ß/ﬁ/ﬂ, sem libunistring; paridade NFD em 400 linhas reais), `o` cycles order, d shows details (created/done stamps, statx birth fallback), n creates a task appended under `## todo` in `Inbox/Notepad.md` stamped `➕ YYYY-MM-DD HH:MM`, r reloads, q quits; `yambar-tasks.py` stays as fallback until dirs + menu land in C |
| Deps | `notcurses` 3.0.17 (extra; `sudo pacman -S notcurses`), `cc` C17; core selftest (`tasks-core.c -DTASKS_CORE_TEST`) is libc-only and runs in `validate.sh` without TTY; no Obsidian CLI/plugin needed — sync is the markdown file itself |

## File search & dirs chip (2026-10-12)

| Piece | State |
|---|---|
| Search | `Mod+Shift+f` → `fsearch.sh`: tofi (`config-search`, 780x420 central) asks the term, `plocate -b` matches substring on basename (case-insensitive), second tofi lists up to 200 home paths; Enter opens via `xdg-open` (dirs go to the default file manager) |
| Index | `plocate` db (`/var/lib/plocate`, 58M) refreshed daily by the stock `plocate-updatedb.timer`; no daemon running — 3–15ms per query |
| Dirs chip | static-left yambar particle; click abre a TUI `yambar-dirs-c` (C/notcurses, `sway/scripts/yambar-dirs.c`, `yambar-dirs.py` de fallback) em foot floating (toggle `yambar-dirs-toggle.sh`, regra `app_id="yambar-dirs"`); pinned list in `~/.cache/dirs-pinadas` (seeded with Vault/dotfiles/Documentos/Downloads), `a`/`+` pins a validated path, `d`/`-` unpicks, Enter opens |

## Scheme pipeline (2026-09-25)

| Piece | State |
|---|---|
| Library | `sway/schemes/gogh-themes-min.json` — 1247 Gogh schemes (978 dark / 269 light); refreshed by `scripts/update-schemes.sh` (needs `jq`) |
| State | `~/.cache/theme-scheme` — active scheme name; absent ⇒ fallback to the current Apprentice constants |
| Contract | `schemelib.sh::scheme_init <dark\|light>` exports `ENV_{BG,FG,ACC,MUT,BRI}_{S,L}_{MIN,MAX}`; `SCHEME_NAME/SCHEME_VARIANT/SCHEME_MATCH` are exported only when the envelopes are complete |
| Clamp | `theme-mode.sh apply` clamps wallpaper colors into the scheme envelopes before python; with a scheme active `LOWC_SAT=100` makes the python desaturation the identity (k=1) |
| Mirror | when `variant` ≠ current mode, each role mirrors `L' = 100 − L` (S unchanged) |

Test hooks (all optional): `TOFI_SCHEME=<name>` applies a scheme without the
Tofi menu; `LY_CONF=<path>` retargets the ly writer; `SCHEME_STATE`,
`SCHEME_JSON`, and `SCHEME_OVERRIDE_DIR` retarget the schemelib inputs;
`XDG_CONFIG_HOME` retargets the qt6ct/qt5ct writers.

## Window tiling and switching (2026-10-11)

| Piece | State |
|---|---|
| swaytiles | Git clone em `~/.local/src/swaytiles` (instalado por `./install.sh` em `~/.local/{bin,lib}`); daemon Python stdlib via `systemctl --user enable --now swaytiles.service`. Bindings: `$mod+Shift+t` menu (tofi), `$mod+m` swap |
| sway-alttab-gui | Pacman (AUR `sway-alttab-gui-bin` 0.0.6 + `gtk4-layer-shell`); daemon Rust/GTK iniciado por `exec_always` no config do sway (pidfile auto-desduplica em reload), `--mode all` (janelas de todas as workspaces; focar troca de workspace). Binding: `Mod1+Tab` (Alt+Tab) |
| autotiling-rs | Inalterado; convive com o swaytiles enquanto os workspaces ficam no layout `default` (swaytiles não toca na árvore). Ao escolher um layout num workspace, desligar via menu Janelas (`~/.cache/autotiling-off`) |

Runtime model dos dois novos daemons: orientados a evento, inscritos no IPC
do sway (socket Unix) — sem polling. Medido parado em sessão ativa:
~0,5% de um core cada; em jogo fullscreen (sem eventos de janela) o
swaytiles fica bloqueado no socket e o custo tende a 0. O `show` do
alt-tab é um SIGUSR1 via pidfile (spawn de processo só no keypress); a
janela GTK fica pre-realizada escondida no daemon.

Manutenção: swaytiles atualiza com `git pull` + `./install.sh` no clone
(reinicia o serviço sozinho); remove com `./install.sh --uninstall`.
sway-alttab-gui atualiza com o pacman/paru junto do resto do sistema.

## Menu de utilitários Rust (2026-10-13)

| Piece | State |
|---|---|
| Binding | `$mod+Shift+x` → `sway/scripts/menu.sh`: `foot -a menu --override="initial-window-size-chars=110x34"` (regra floating `app_id="menu"` centrada, junto das do yambar-tasks/dirs); toggle fecha a janela; sem o binário cai no `tofi-menu.sh` |
| Binário | `menu/` (Rust 2024, ratatui 0.29 + crossterm 0.28 + serde_json; perfil release LTO/codegen-units=1/strip/panic=abort ≈ 770 KB) → `~/.local/bin/menu` via `make -C menu install` |
| UI | Abas (Todas/Aplicativos/Conectividade/Aparência/Janelas/Sistema) + filtro fuzzy com fold de acentos (subsequência com score; highlight do match) + estados vivos ao lado dos itens + submenus (Esquemas dos 1247 Gogh, fastfetch, temas do tofi, fontes, Papirus, energia, monitores, lock, temperatura) + painel direito com a paleta do pywal (16 cores + BG/FG). Texto herda o tema do terminal; cor absoluta só nos swatches (colors.sh defasado do terminal deixa o menu ilegível) |
| Ações | Executam os scripts do rice pelos hooks `TOFI_*` (TOFI_SCHEME/TOFI_PICK/TOFI_FASTFETCH) + args diretos; toggles de divisão/avisos replicados do tofi-menu (flag `autotiling-off`, `makoctl mode`). keep=true mantém o menu aberto e recarrega estados; apps externos fecham. Estados com TTL (pgrep 2 s, bateria 5 s, hora 10 s) — zero fork por frame |
| Verificação | `make -C menu e2e` (MENU_SEQ injeta teclas no binário: casos de estados, filtro+Hora, toggle da divisão ida/volta) + `cargo test`/`clippy -D warnings`; no `scripts/validate.sh` (SKIP sem cargo). E2E visual validado em workspace limpo (Zen fullscreen no ws 1 esconde janelas novas — normal do sway) |
| Fallback | `tofi-menu.sh` intacto no repo; quem quiser volta trocando o binding |
