# Pendências de instalação

Consumidores do tema que dependem de pacotes locais. Os writers em
`sway/scripts/render.sh` (e o wrapper `sway/scripts/waylock.sh`) já são
guardados: só escrevem se o app/config existir. Instalar o pacote é o que
falta — nada no pipeline quebra sem eles.

| Pacote | Consumidor | Depois de instalar |
|---|---|---|
| `qt6ct` | UIs Qt6 | `pacman -S qt6ct`. Abra o app uma vez (gera `~/.config/qt6ct/qt6ct.conf`); a partir daí o render grava `colors/dotfiles.conf` e ativa sozinho (`color_scheme_path` + `custom_palette=true`). Apps Qt só leem o palette no início. |
| `qt5ct` | UIs Qt5 | `pacman -S qt5ct`; mesmo comportamento do qt6ct. |
| `waylock` | screenlocker | `pacman -S waylock`. Não tem arquivo de config (só flags de CLI) → aponte o binding de lock para `sway/scripts/waylock.sh`, que passa `-init-color 0x$BG -input-color 0x$ACCENT -fail-color 0x$FAIL`. |
| ly (já instalado) | greeter | `/etc/ly/config.ini` é root-only ⇒ o writer pula. Para ativar: `sudo chown $USER /etc/ly/config.ini` (as cores entram no próximo apply; pacman pode voltar a assumir o dono após update — repetir). As cores só valem no próximo login/greeter. |
| `wallust` (opcional) | template engine de cor | Não faz falta hoje: o pipeline é pywal + `theme-mode.sh`. Só considerar se quiser templates por-app gerenciados por um template engine dedicado. |

## Notas

- Formatos verificados na fonte (não em man pages): slots do `[ColorScheme]`
  do qt5ct/qt6ct = ordem de `QPalette::ColorRole(0..20)` (Qt5 header local +
  código dos dois projetos); `ly` = chaves planas `key = 0xSSRRGGBB`.
- waylock 1.6.0 (repositório cachyos-extra-v3): sem opção de config file,
  só flags — por isso o wrapper em vez de um writer de config.
