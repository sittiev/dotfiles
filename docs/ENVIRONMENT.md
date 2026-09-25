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
