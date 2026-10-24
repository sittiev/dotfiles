# User services

Sway itself launches from `sway/config` with `exec`/`exec_always`; do not run
Sway as a systemd service.

Two units live here:

- `hora.timer` + `hora.service`: sends a mako notification on the hour and
  every half hour (`OnCalendar=*:00,30:00`, `AccuracySec=1s`). The service is
  oneshot, so nothing stays resident between triggers: no polling, no idle
  background process. It talks to the session bus via
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus`; mako must already be
  running (it is, from `sway/config`).

Enable with:

```sh
systemctl --user daemon-reload
systemctl --user enable --now hora.timer
```

For other units added later:

- keep them under `systemd/user/`;
- use `systemctl --user`, not system units;
- import `WAYLAND_DISPLAY`, `SWAYSOCK`, and `XDG_CURRENT_DESKTOP` from Sway
  when the unit needs them;
- bind application units to `sway-session.target` where appropriate.
