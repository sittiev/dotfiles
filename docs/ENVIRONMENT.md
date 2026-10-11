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
| sway-alttab-gui | Pacman (AUR `sway-alttab-gui-bin` 0.0.6 + `gtk4-layer-shell`); daemon Rust/GTK iniciado por `exec_always` no config do sway (pidfile auto-desduplica em reload). Binding: `Mod1+Tab` (Alt+Tab) |
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
