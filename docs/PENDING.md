# Pendências de instalação

Consumidores do tema que dependem de pacotes locais. Os writers em
`sway/scripts/render.sh` (e o wrapper `sway/scripts/waylock.sh`) já são
guardados: só escrevem se o app/config existir. Instalar o pacote é o que
falta — nada no pipeline quebra sem eles.

| Pacote | Consumidor | Depois de instalar |
|---|---|---|
| `qt6ct` | UIs Qt6 | `pacman -S qt6ct`. Abra o app uma vez (gera `~/.config/qt6ct/qt6ct.conf`); a partir daí o render grava `colors/dotfiles.conf` e ativa sozinho (`color_scheme_path` + `custom_palette=true`). Apps Qt só leem o palette no início. |
| `qt5ct` | UIs Qt5 | `pacman -S qt5ct`; mesmo comportamento do qt6ct. |
| `waylock` | screenlocker | `sudo pacman -S waylock`. Binding `$mod+Shift+l` → `sway/scripts/waylock.sh` (`-init-color 0x$BG -input-color 0x$ACCENT -fail-color 0x$FAIL`). Singleton via `pgrep -x waylock` (sem empilhar = sem senha dupla); before-sleep usa `--pre-sleep` (`-fork-on-lock`, libera o delay lock do logind). |
| `swayidle` | idle daemon | `sudo pacman -S swayidle`. `sway/scripts/idle.sh` (exec_always): na tomada trava 5min, apaga telas 10min, `lock` + `before-sleep`; descarregando trava 3min, apaga 5min, suspende em min(`~/.cache/suspend-timeout`, 10min). `sway/scripts/battery.sh` (exec_always): descarregando avisa em `~/.cache/battery-warn` (20), `battery-critical` (10) e suspende em `battery-suspend` (5) com aviso antes; troca tomada/bateria reinicia o idle. Críticos usam `urgency=critical` (borda FAIL no mako). |
| `overskride` (AUR) | bluetooth GUI (bluez) | `paru -S overskride`; backend `bluez` + `bluez-utils` já instalados → `sudo systemctl enable --now bluetooth.service`. Menu Mod+Shift+x → Bluetooth. |
| `iwgtk` (AUR) | wifi GUI (iwd puro) | `paru -S iwgtk`. NM e wpa_supplicant REMOVIDOS; rede = iwd + systemd-networkd (`/etc/systemd/network/25-wireless.network`, DHCP) + systemd-resolved. iwgtk fala com iwd via D-Bus. Menu Mod+Shift+x → Rede. |
| ly (já instalado) | greeter | `/etc/ly/config.ini` é root-only ⇒ o writer pula. Para ativar: `sudo chown $USER /etc/ly/config.ini` (as cores entram no próximo apply; pacman pode voltar a assumir o dono após update — repetir). As cores só valem no próximo login/greeter. |
| `wallust` (opcional) | template engine de cor | Não faz falta hoje: o pipeline é pywal + `theme-mode.sh`. Só considerar se quiser templates por-app gerenciados por um template engine dedicado. |

## Notas

- Formatos verificados na fonte (não em man pages): slots do `[ColorScheme]`
  do qt5ct/qt6ct = ordem de `QPalette::ColorRole(0..20)` (Qt5 header local +
  código dos dois projetos); `ly` = chaves planas `key = 0xSSRRGGBB`.
- waylock 1.6.0 (repositório cachyos-extra-v3): sem opção de config file,
  só flags — por isso o wrapper em vez de um writer de config.
