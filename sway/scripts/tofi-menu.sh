#!/usr/bin/dash
# tofi-menu.sh — hub estilo Ajustes Apple (categorias → diálogo → ação).
#
# Nível 1 (menu): Aplicativos, Conectividade, Aparência, Janelas, Sistema,
# com o estado atual à direita (" · Ativada", " · 99%") e " >" onde há
# subnível. Setas ASCII minimalistas (< voltar, > avançar); o prompt vira
# título sem dois-pontos (a digitação continua visível para filtrar — sem
# ela o Enter não casa nada). Grupos separados só por respiro (U+2800), sem
# títulos decorativos.
# Nível 2 (diálogos): um tofi por categoria. Alternadores ficam abertos e
# atualizam o estado; sub-diálogos (Energia, Monitores, Temperatura,
# Esquemas, Fonte, Tofi, área de transferência, Emoji) rodam e VOLTAM ao
# mesmo diálogo da categoria, já com o estado novo. Apps externos
# (Terminal, Arquivos, Navegador, papel de parede, bloqueio, Rede,
# Bluetooth) trocam de processo. Todo diálogo tem "< Voltar" como primeira
# linha; Esc faz o mesmo.
#
# Separadores invisíveis: PAD=U+00A0 (margem esquerda; U+0020 quebrava o
# Pango no meio da linha, ver brightness.sh) e GAP=U+2800 (linha em branco
# entre grupos). U+0000 (nulo) é impossível aqui: string POSIX/argv é
# terminada em NUL, então o menu nunca o receberia — U+2800 o substitui.
# GAPs selecionados voltam ao mesmo diálogo (no-op).
#
# Janelas: "Divisão automática" liga/desliga o autotiling-rs. Desligada, o
# mod+w (abas) e o mod+s (pilha) viram monocle manual, um app por vez.
# O desligado persiste em ~/.cache/autotiling-off: o exec_always do
# sway/config e o game-mode.sh respeitam o arquivo, então um
# `swaymsg reload` (render.sh) não ressuscita o processo.
# Hook não-interativo de teste: TOFI_SEQ com uma escolha exata por linha é
# consumida em ordem (menu, depois diálogo); esgotada, volta/sai. Ex.:
# TOFI_SEQ="$(printf 'Janelas · Desativada >\n< Voltar')" ./tofi-menu.sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tofi="$script_dir/tofi-safe.sh"
conf="$HOME/.config/tofi/config"

# U+00A0 (margem) e U+2800 (respiro entre grupos) via escapes: o arquivo
# segue legível e o grep continua achando os rótulos.
PAD=$(printf '\302\240')
GAP=$(printf '\342\240\200')

is_autotiling_on() { pgrep -x autotiling-rs >/dev/null 2>&1; }
is_night_on() { pgrep -x wlsunset >/dev/null 2>&1; }
is_yambar_on() { pgrep -x yambar >/dev/null 2>&1; }
is_dnd_on() { makoctl mode 2>/dev/null | grep -q do-not-disturb; }
is_game_on() { [ -f "${XDG_CACHE_HOME:-$HOME/.cache}/sway-game-mode/active" ]; }

theme_label() {
    case "$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf 'dark')" in
        light) printf 'Claro' ;;
        *) printf 'Escuro' ;;
    esac
}
font_label() {
    case "$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/ui-font" 2>/dev/null || printf 'noto')" in
        sf) printf 'SF Pro' ;;
        segoe) printf 'Segoe UI' ;;
        *) printf 'Noto Sans' ;;
    esac
}
size_label() { cat "${XDG_CACHE_HOME:-$HOME/.cache}/ui-font-size" 2>/dev/null || printf '14'; }
scheme_label() { cat "${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme" 2>/dev/null || printf 'Apprentice'; }
tofi_label() { cat "$HOME/.cache/tofi-layout" 2>/dev/null || printf 'padrao'; }
clock_label() {
    if [ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yambar-clock-full" ]; then
        printf 'Data e hora'
    else
        printf 'Hora'
    fi
}
div_label() { if is_autotiling_on; then printf 'Ativada'; else printf 'Desativada'; fi; }
night_label() { if is_night_on; then printf 'Ligada'; else printf 'Desligada'; fi; }
yambar_label() { if is_yambar_on; then printf 'Visível'; else printf 'Oculta'; fi; }
dnd_label() { if is_dnd_on; then printf 'Silenciados'; else printf 'Ativados'; fi; }
game_label() { if is_game_on; then printf 'Ativado'; else printf 'Desligado'; fi; }
bat_label() {
    cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 || true)
    case "$cap" in '' | *[!0-9]*) printf '—' ;; *) printf '%s%%' "$cap" ;; esac
    unset cap
}
time_label() { date '+%H:%M'; }

ask() {
    # ask <prompt> [altura] — lê as entradas da stdin e devolve a escolha.
    # Fila de teste em arquivo: ask roda dentro de $(...) (subshell), então
    # consumir TOFI_SEQ em memória nunca persistiria (loop infinito) — o
    # main despeja a fila num temporário e cada ask retira a 1ª linha.
    prompt=$1
    height=${2:-}
    if [ -n "${TOFI_SEQ_FILE:-}" ]; then
        line=$(head -n 1 "$TOFI_SEQ_FILE" 2>/dev/null || true)
        tail -n +2 "$TOFI_SEQ_FILE" > "$TOFI_SEQ_FILE.next" 2>/dev/null || true
        mv -f "$TOFI_SEQ_FILE.next" "$TOFI_SEQ_FILE" 2>/dev/null || true
        printf '%s\n' "$line"
        unset line
        return 0
    fi
    if [ -n "$height" ]; then
        _ask_choice=$(TOFI_REOPEN=1 "$tofi" --config "$conf" --prompt-text "$prompt" --height="$height" || true)
    else
        _ask_choice=$(TOFI_REOPEN=1 "$tofi" --config "$conf" --prompt-text "$prompt" || true)
    fi
    if [ "${TOFI_MENU_DEBUG:-0}" = 1 ]; then
        printf '%s prompt=%s choice=%s\n' "$(date '+%H:%M:%S')" "$prompt" "$_ask_choice" >> /tmp/tofi-menu-debug.log
    fi
    # tofi devolve a escolha em NFD (e + combinante) e os literais do
    # case sao NFC: sem normalizar, a comparacao byte a byte nunca casa
    # e o dialogo volta ao menu (Aparencia, Divisao, transferencia...).
    if command -v python3 >/dev/null 2>&1; then
        _ask_nfc=$(printf '%s' "$_ask_choice" | python3 -c 'import sys,unicodedata; sys.stdout.write(unicodedata.normalize("NFC", sys.stdin.read()))' 2>/dev/null) && _ask_choice=$_ask_nfc
        unset _ask_nfc
    fi
    printf '%s\n' "$_ask_choice"
    unset _ask_choice
}

toggle_autotiling() {
    flag=${XDG_CACHE_HOME:-$HOME/.cache}/autotiling-off
    if is_autotiling_on; then
        pkill -x autotiling-rs >/dev/null 2>&1 || true
        printf '' > "$flag" 2>/dev/null || true
        notify-send "Divisão automática desligada" "Para monocle, use mod+w (abas) ou mod+s (pilha)." 2>/dev/null || true
    else
        rm -f "$flag" 2>/dev/null || true
        pkill -x autotiling-rs >/dev/null 2>&1 || true
        sleep 0.2
        autotiling-rs >/dev/null 2>&1 &
        notify-send "Divisão automática ativada" "Novas janelas alternam direção sozinhas." 2>/dev/null || true
    fi
    unset flag
}

toggle_dnd() {
    if is_dnd_on; then
        makoctl mode -r do-not-disturb 2>/dev/null || true
        notify-send "Avisos ativados" 2>/dev/null || true
    else
        notify-send "Avisos silenciados" 2>/dev/null || true
        makoctl mode -a do-not-disturb 2>/dev/null || true
    fi
}

open_bluetooth() {
    if command -v overskride >/dev/null 2>&1; then exec overskride; fi
    if command -v bluetoothctl >/dev/null 2>&1; then exec foot -e bluetoothctl; fi
    notify-send "Bluetooth indisponível" "Para configurar, instale overskride: paru -S overskride." 2>/dev/null || true
}

open_rede() {
    if command -v iwgtk >/dev/null 2>&1; then exec iwgtk; fi
    notify-send "Rede indisponível" "Para configurar, instale iwgtk: paru -S iwgtk." 2>/dev/null || true
}

sub_apps() {
    while true; do
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}Terminal" "${PAD}Arquivos" "${PAD}Navegador" | ask "Aplicativos")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *Terminal*) exec foot ;;
            *Arquivos*) exec pcmanfm ;;
            *Navegador*) exec librewolf ;;
        esac
    done
}

sub_net() {
    while true; do
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}Rede >" "${PAD}Bluetooth" | ask "Conectividade")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *Rede*) open_rede ;;
            *Bluetooth*) open_bluetooth ;;
        esac
    done
}

sub_look() {
    while true; do
        if [ "$(theme_label)" = Claro ]; then mclaro=' · Ativo'; mescuro=''; else mclaro=''; mescuro=' · Ativo'; fi
        c=$(printf '%s\n' "${PAD}< Voltar" \
            "${PAD}Modo claro${mclaro}" \
            "${PAD}Modo escuro${mescuro}" \
            "${PAD}Automático (pela luz)" \
            "$GAP" \
            "${PAD}Esquemas de cores · $(scheme_label)" \
            "${PAD}Tema do Tofi · $(tofi_label)" \
            "$GAP" \
            "${PAD}Fonte · $(font_label)" \
            "${PAD}Tamanho da fonte · $(size_label)" \
            "$GAP" \
            "${PAD}Papel de parede" \
            "${PAD}Luz noturna · $(night_label)" \
            "${PAD}Temperatura da luz >" \
            "${PAD}Barra superior · $(yambar_label)" \
            "${PAD}Relógio da barra · $(clock_label)" | ask "Aparência" 520)
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *claro*) "$script_dir/theme-toggle.sh" light ;;
            *escuro*) "$script_dir/theme-toggle.sh" dark ;;
            *Automático*) "$script_dir/theme-toggle.sh" auto ;;
            *Esquemas*) "$script_dir/scheme-menu.sh" ;;
            *Tamanho*) "$script_dir/ui-font-size.sh" ;;
            *Tema*) "$script_dir/tofi-themes.sh" ;;
            *Fonte*) "$script_dir/ui-font.sh" ;;
            *Papel*) exec "$script_dir/wallpaper.sh" ;;
            *noturna*) "$script_dir/nightlight.sh" ;;
            *Temperatura*) "$script_dir/nightmenu.sh" ;;
            *Barra*) "$script_dir/yambar-toggle.sh" ;;
            *Relógio*) "$script_dir/yambar-clock-toggle.sh" ;;
        esac
        unset mclaro mescuro
    done
}

sub_windows() {
    while true; do
        c=$(printf '%s\n' "${PAD}< Voltar" \
            "${PAD}Divisão automática · $(div_label)" \
            "$GAP" \
            "${PAD}Avisos · $(dnd_label)" \
            "${PAD}Modo jogo · $(game_label)" | ask "Janelas")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *Divisão*) toggle_autotiling ;;
            *Avisos*) toggle_dnd ;;
            *jogo*) "$script_dir/game-mode.sh" toggle ;;
        esac
    done
}

sub_sys() {
    while true; do
        c=$(printf '%s\n' "${PAD}< Voltar" \
            "${PAD}Área de transferência" \
            "${PAD}Emoji" \
            "$GAP" \
            "${PAD}Monitores >" \
            "${PAD}Energia >" \
            "${PAD}Bateria · $(bat_label)" \
            "$GAP" \
            "${PAD}Hora · $(time_label)" \
            "${PAD}Data" \
            "${PAD}Bloquear tela" | ask "Sistema" 420)
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *transferência*) "$script_dir/clipboard.sh" ;;
            *Emoji*) "$script_dir/emoji.sh" ;;
            *Monitores*) "$script_dir/monitormenu.sh" ;;
            *Energia*) "$script_dir/powermenu.sh" ;;
            *Bateria*)
                cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 || printf '?')
                notify-send "Bateria" "$cap%"
                unset cap ;;
            *Hora*) notify-send "Hora" "$(date '+%H:%M')" ;;
            *Data*) notify-send "Data" "$(date '+%A, %d de %B de %Y')" ;;
            *Bloquear*) exec "$script_dir/waylock.sh" ;;
        esac
    done
}

main() {
    if [ -n "${TOFI_SEQ+set}" ]; then
        TOFI_SEQ_FILE=$(mktemp "${TMPDIR:-/tmp}/tofi-menu-seq.XXXXXX")
        printf '%s' "$TOFI_SEQ" > "$TOFI_SEQ_FILE"
        unset TOFI_SEQ
        trap 'rm -f "$TOFI_SEQ_FILE"' EXIT
    fi
    while true; do
        choice=$(printf '%s\n' \
            "${PAD}Aplicativos >" \
            "${PAD}Conectividade >" \
            "${PAD}Aparência · $(theme_label) >" \
            "${PAD}Janelas · $(div_label) >" \
            "${PAD}Sistema · $(bat_label) >" \
            | ask "Ajustes")
        [ -n "$choice" ] || exit 0
        case "$choice" in
            *Aplicativos*) sub_apps ;;
            *Conectividade*) sub_net ;;
            *Aparência*) sub_look ;;
            *Janelas*) sub_windows ;;
            *Sistema*) sub_sys ;;
        esac
    done
}

main "$@"
