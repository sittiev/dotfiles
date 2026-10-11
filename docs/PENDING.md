# Pendências de instalação

Consumidores do tema que dependem de pacotes locais. Os writers em
`sway/scripts/render.sh` (e o wrapper `sway/scripts/swaylock.sh`) já são
guardados: só escrevem se o app/config existir. Instalar o pacote é o que
falta — nada no pipeline quebra sem eles.

| Pacote | Consumidor | Depois de instalar |
|---|---|---|
| `qt6ct` | UIs Qt6 | `pacman -S qt6ct`. Abra o app uma vez (gera `~/.config/qt6ct/qt6ct.conf`); a partir daí o render grava `colors/dotfiles.conf` e ativa sozinho (`color_scheme_path` + `custom_palette=true`). Apps Qt só leem o palette no início. |
| `qt5ct` | UIs Qt5 | `pacman -S qt5ct`; mesmo comportamento do qt6ct. |
| `swaylock-effects-git` (AUR) | screenlocker | `paru -S swaylock-effects-git` (conflita com `swaylock`: remove o oficial). Binding `$mod+Shift+Escape` → `sway/scripts/swaylock.sh` (paleta via `--color/--inside-color/--ring-color`; relógio `--clock --timestr "%H:%M" --datestr` ativo no fork). Singleton via `pgrep -x swaylock` (sem empilhar = sem senha dupla); before-sleep usa `--pre-sleep` (`-f/--daemonize`, libera o delay lock do logind). |
| `swayidle` | idle daemon | `sudo pacman -S swayidle`. `sway/scripts/idle.sh` (exec_always): trava após `~/.cache/lock-timeout` (padrão 300 s; menu Mod+Shift+x → Sistema → Bloqueio automático, 0 = nunca), apaga telas 5min na bateria e 10min na tomada, `lock` + `before-sleep`, suspende em `~/.cache/suspend-timeout` (limitado a 10min na bateria). `sway/scripts/battery.sh` (exec_always): descarregando avisa em `~/.cache/battery-warn` (20), `battery-critical` (10) e suspende em `battery-suspend` (5) com aviso antes; troca tomada/bateria reinicia o idle. Críticos usam `urgency=critical` (borda FAIL no mako). |
| `overskride` (AUR) | bluetooth GUI (bluez) | `paru -S overskride`; backend `bluez` + `bluez-utils` já instalados → `sudo systemctl enable --now bluetooth.service`. Menu Mod+Shift+x → Bluetooth. |
| `iwgtk` (AUR) | wifi GUI (iwd puro) | `paru -S iwgtk`. NM e wpa_supplicant REMOVIDOS; rede = iwd + systemd-networkd (`/etc/systemd/network/25-wireless.network`, DHCP) + systemd-resolved. iwgtk fala com iwd via D-Bus. Menu Mod+Shift+x → Rede. |
| ly (já instalado) | greeter | `/etc/ly/config.ini` é root-only ⇒ o writer pula. Para ativar: `sudo chown $USER /etc/ly/config.ini` (as cores entram no próximo apply; pacman pode voltar a assumir o dono após update — repetir). As cores só valem no próximo login/greeter. |
| `papirus-icon-theme` | ícones Papirus (base, Dark, Light) | `sudo pacman -S papirus-icon-theme`. Sem ele o seletor `Aparência → Ícones` avisa e mantém o YAMIS-wal; com ele, `theme-mode.sh apply` usa a variante (`Automática` segue o modo claro/escuro) no GTK, KDE e XWayland. |
| `papirus-folders` (AUR) | cor das pastas do Papirus | `paru -S papirus-folders-git`. Sem ele a escolha `Variante do Papirus → Cor das pastas` avisa e nada muda; com ele, `Automática` pinta as pastas com o matiz do ACCENT da paleta (`-C <cor> --theme <variante>`). O tema em `/usr/share/icons` é root-owned: se o apply falhar por permissão, rode o comando com `sudo` uma vez. |
| `wallust` (opcional) | template engine de cor | Não faz falta hoje: o pipeline é pywal + `theme-mode.sh`. Só considerar se quiser templates por-app gerenciados por um template engine dedicado. |

## Notas

- Formatos verificados na fonte (não em man pages): slots do `[ColorScheme]`
  do qt5ct/qt6ct = ordem de `QPalette::ColorRole(0..20)` (Qt5 header local +
  código dos dois projetos); `ly` = chaves planas `key = 0xSSRRGGBB`.
- swaylock-effects-git (AUR, fork do swaylock 1.8 com relógio e efeitos):
  o wrapper usa flags para herdar a paleta viva sem duplicar estado em
  `~/.swaylock/config`; `--clock/--timestr/--datestr` ativos (verificado no
  binário instalado). Sem o fork, o wrapper degrada para o upstream sem
  relógio.
