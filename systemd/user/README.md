# User services

No user units were copied because the live Sway session currently launches its
components from `sway/config` with `exec`/`exec_always`.

If services are added later:

- keep them under `systemd/user/`;
- use `systemctl --user`, not system units;
- import `WAYLAND_DISPLAY`, `SWAYSOCK`, and `XDG_CURRENT_DESKTOP` from Sway;
- bind application units to `sway-session.target` where appropriate;
- do not run Sway itself as a systemd service.
