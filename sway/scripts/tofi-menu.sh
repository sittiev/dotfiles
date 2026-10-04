#!/usr/bin/dash
# tofi-menu.sh — hub estilo Ajustes Apple (categorias → diálogo → ação).
#
# Nível 1 (menu): Aplicativos, Conectividade, Aparência, Janelas, Sistema,
# com o estado atual à direita (" · Ativada", " · 99%") e " →" onde há
# subnível — o mesmo vocabulário visual do iOS (valor + seta).
# Nível 2 (diálogos): um tofi por categoria, com subcategorias nomeadas em
# "— CAPS —" e ações abaixo. Alternadores ficam abertos e atualizam o
# estado; sub-diálogos (Energia, Monitores, Temperatura, Esquemas, Fonte,
# Tofi, área de transferência, Emoji) rodam e VOLTAM ao mesmo diálogo da
# categoria, já com o estado novo. Apps externos (Terminal, Arquivos,
# Navegador, papel de parede, bloqueio, Rede, Bluetooth) trocam de processo.
# Todo diálogo tem "← Voltar" como primeira linha; Esc faz o mesmo.
#
# Separadores invisíveis: PAD=U+00A0 (margem esquerda; U+0020 quebrava o
# Pango no meio da linha, ver brightness.sh) e GAP=U+2800 (linha em branco
# entre grupos). U+0000 (nulo) é impossível aqui: string POSIX/argv é
# terminada em NUL, então o menu nunca o receberia — U+2800 o substitui.
# Cabeçalhos ("—") e GAPs selecionados voltam ao mesmo diálogo (no-op).
# Setas ← (U+2190) e → (U+2192): ver lista de setas Unicode.
#
# Janelas: "Divisão automática" liga/desliga o autotiling-rs. Desligada, o
# mod+w (abas) e o mod+s (pilha) viram monocle manual, um app por vez.
# Hook não-interativo de teste: TOFI_SEQ com uma escolha exata por linha é
# consumida em ordem (menu, depois diálogo); esgotada, volta/sai. Ex.:
# TOFI_SEQ="$(printf 'Janelas · Desativada →\n← Voltar')" ./tofi-menu.sh
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
    # ask <prompt> — lê as entradas da stdin e devolve a escolha.
    # Fila de teste em arquivo: ask roda dentro de $(...) (subshell), então
    # consumir TOFI_SEQ em memória nunca persistiria (loop infinito) — o
    # main despeja a fila num temporário e cada askretira a 1ª linha.
    prompt=$1
    if [ -n "${TOFI_SEQ_FILE:-}" ]; then
        line=$(head -n 1 "$TOFI_SEQ_FILE" 2>/dev/null || true)
        tail -n +2 "$TOFI_SEQ_FILE" > "$TOFI_SEQ_FILE.next" 2>/dev/null || true
        mv -f "$TOFI_SEQ_FILE.next" "$TOFI_SEQ_FILE" 2>/dev/null || true
        printf '%s\n' "$line"
        unset line
        return 0
    fi
    "$tofi" --config "$conf" --prompt-text "$prompt" || true
}

toggle_autotiling() {
    if is_autotiling_on; then
        pkill -x autotiling-rs >/dev/null 2>&1 || true
        notify-send "Divisão automática desligada" "Para monocle, use mod+w (abas) ou mod+s (pilha)." 2>/dev/null || true
    else
        pkill -x autotiling-rs >/dev/null 2>&1 || true
        sleep 0.2
        autotiling-rs >/dev/null 2>&1 &
        notify-send "Divisão automática ativada" "Novas janelas alternam direção sozinhas." 2>/dev/null || true
    fi
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
        c=$(printf '%s\n' "${PAD}← Voltar" "${PAD}Terminal" "${PAD}Arquivos" "${PAD}Navegador" | ask "Aplicativos: ")
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
        c=$(printf '%s\n' "${PAD}← Voltar" "${PAD}Rede →" "${PAD}Bluetooth" | ask "Conectividade: ")
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
        c=$(printf '%s\n' "${PAD}← Voltar" \
            "${PAD}— TEMA —" \
            "${PAD}Claro ou escuro · $(theme_label)" \
            "${PAD}Esquemas de cores" \
            "${PAD}Tema do Tofi" \
            "$GAP" \
            "${PAD}— TEXTO —" \
            "${PAD}Fonte · $(font_label)" \
            "${PAD}Tamanho da fonte · $(size_label)" \
            "$GAP" \
            "${PAD}— FUNDO —" \
            "${PAD}Papel de parede" \
            "${PAD}Luz noturna · $(night_label)" \
            "${PAD}Temperatura da luz →" \
            "${PAD}Barra superior · $(yambar_label)" | ask "Aparência: ")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|*—*|"$GAP") continue ;;
            *Claro*) "$script_dir/theme-toggle.sh" toggle ;;
            *Esquemas*) "$script_dir/scheme-menu.sh" ;;
            "*Tema do Tofi*") "$script_dir/tofi-themes.sh" ;;
            "*Fonte ·*") "$script_dir/ui-font.sh" ;;
            *Tamanho*) "$script_dir/ui-font-size.sh" ;;
            *Papel*) exec "$script_dir/wallpaper.sh" ;;
            "*Luz noturna*") "$script_dir/nightlight.sh" ;;
            *Temperatura*) "$script_dir/nightmenu.sh" ;;
            *Barra*) "$script_dir/yambar-toggle.sh" ;;
        esac
    done
}

sub_windows() {
    while true; do
        c=$(printf '%s\n' "${PAD}← Voltar" \
            "${PAD}— DIVISÃO —" \
            "${PAD}Divisão automática · $(div_label)" \
            "$GAP" \
            "${PAD}— FOCO —" \
            "${PAD}Avisos · $(dnd_label)" \
            "${PAD}Modo jogo · $(game_label)" | ask "Janelas: ")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|*—*|"$GAP") continue ;;
            *Divisão*) toggle_autotiling ;;
            *Avisos*) toggle_dnd ;;
            "*Modo jogo*") "$script_dir/game-mode.sh" toggle ;;
        esac
    done
}

sub_sys() {
    while true; do
        c=$(printf '%s\n' "${PAD}← Voltar" \
            "${PAD}— CONTEÚDO —" \
            "${PAD}Área de transferência" \
            "${PAD}Emoji" \
            "$GAP" \
            "${PAD}— TELA E ENERGIA —" \
            "${PAD}Monitores →" \
            "${PAD}Energia →" \
            "${PAD}Bateria · $(bat_label)" \
            "$GAP" \
            "${PAD}— INFORMAÇÃO —" \
            "${PAD}Hora · $(time_label)" \
            "${PAD}Data" \
            "${PAD}Bloquear tela" | ask "Sistema: ")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|*—*|"$GAP") continue ;;
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
            "${PAD}Aplicativos →" \
            "${PAD}Conectividade →" \
            "${PAD}Aparência · $(theme_label) →" \
            "${PAD}Janelas · $(div_label) →" \
            "${PAD}Sistema · $(bat_label) →" \
            | ask "Ajustes: ")
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
