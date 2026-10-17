#!/usr/bin/dash
# tofi-menu.sh — hub estilo Ajustes Apple (categorias → diálogo → ação).
#
# Padrão (Mod+Shift+x): busca global flat — todas as ações numa lista só,
# digita filtra, Enter executa e volta à lista (toggles atualizam o estado
# na hora). Fallback hierárquico: ./tofi-menu.sh --hub (categorias).
#
# Nível 1 (menu): Aplicativos, Conectividade, Aparência, Janelas, Sistema,
# com o estado atual à direita (" · Ativada", " · 99%") e " >" onde há
# subnível. Setas ASCII minimalistas (< voltar, > avançar); o prompt vira
# título sem dois-pontos (a digitação continua visível para filtrar — sem
# ela o Enter não casa nada). Grupos separados só por respiro (U+2800), sem
# títulos decorativos.
# Nível 2 (diálogos): um tofi por categoria. Alternadores ficam abertos e
# atualizam o estado; sub-diálogos (Energia, Bloqueio automático, Monitores,
# Luz noturna/Temperatura, Esquemas, Fonte, Tofi, Ícones, Variante do Papirus,
# área de transferência, Emoji) rodam e VOLTAM ao
# mesmo diálogo da categoria, já com o estado novo. Apps externos
# (Terminal, Arquivos, Navegador, papel de parede, bloqueio, Rede,
# Bluetooth) trocam de processo. Todo diálogo tem "< Voltar" como primeira
# linha; Esc faz o mesmo.
#
# Separadores invisíveis: PAD vazio (sem margem esquerda — itens colados
# na borda; U+0020 quebrava o Pango no meio da linha, ver brightness.sh)
# e GAP=U+2800 (linha em branco
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

# PAD vazio (itens colados na borda) e U+2800 (respiro entre grupos) via
# escapes: o arquivo segue legível e o grep continua achando os rótulos.
PAD=$(printf '')
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
    # ui-font.sh guarda a família direto; chaves antigas continuam válidas
    v=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/ui-font" 2>/dev/null || printf 'noto')
    case "$v" in
        sf) printf 'SF Pro Display' ;;
        segoe) printf 'Segoe UI' ;;
        noto|"") printf 'Noto Sans' ;;
        *) printf '%s' "$v" ;;
    esac
}
size_label() { cat "${XDG_CACHE_HOME:-$HOME/.cache}/ui-font-size" 2>/dev/null || printf '14'; }
term_label() {
    v=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/term-font" 2>/dev/null || printf 'jetbrains')
    case "$v" in
        jetbrains|"") printf 'JetBrains Mono' ;;
        lexend) printf 'Lexend' ;;
        atkinson) printf 'Atkinson Hyperlegible Mono' ;;
        *) printf '%s' "$v" ;;
    esac
}
mono_label() {
    v=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/mono-font" 2>/dev/null || printf 'auto')
    case "$v" in
        auto|"") printf 'Automática' ;;
        noto) printf 'Noto Sans Mono' ;;
        jetbrains) printf 'JetBrains Mono' ;;
        atkinson) printf 'Atkinson Hyperlegible Mono' ;;
        *) printf '%s' "$v" ;;
    esac
}
scheme_label() { cat "${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme" 2>/dev/null || printf 'Apprentice'; }
icon_label() {
    case "$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme" 2>/dev/null || printf 'yamis')" in
        papirus) printf 'Papirus' ;;
        *) printf 'YAMIS' ;;
    esac
}
papirus_variant_label() {
    case "$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme-papirus-variant" 2>/dev/null || printf 'auto')" in
        Papirus) printf 'Base' ;;
        Papirus-Dark) printf 'Escura' ;;
        Papirus-Light) printf 'Clara' ;;
        *) printf 'Automática' ;;
    esac
}
papirus_folders_label() {
    cur=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme-papirus-folders" 2>/dev/null || printf 'auto')
    case "$cur" in
        auto) printf 'Automática' ;;
        default) printf 'Padrão' ;;
        *) printf '%s' "$cur" ;;
    esac
    unset cur
}
fm_label() {
    case "$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/file-manager" 2>/dev/null || printf 'pcmanfm')" in
        dolphin) printf 'Dolphin' ;;
        *) printf 'PCManFM' ;;
    esac
}
tofi_label() { cat "$HOME/.cache/tofi-layout" 2>/dev/null || printf 'padrao'; }
fastfetch_label() {
    s=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch-style" 2>/dev/null || printf 'padrao')
    sed -n '1p' "$HOME/.config/fastfetch/presets/$s.jsonc" 2>/dev/null | sed -e 's|^// ||' -e 's| — .*||' || printf '%s' "$s"
    unset s
}
lock_label() { # segundos de ~/.cache/lock-timeout → "5 min" / "1 h" / "Nunca"
    v=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/lock-timeout" 2>/dev/null || printf '300')
    case "$v" in '' | *[!0-9]*) v=300 ;; esac
    if [ "$v" -eq 0 ] 2>/dev/null; then
        printf 'Nunca'
    elif [ "$v" -ge 3600 ] 2>/dev/null; then
        printf '%s h' "$((v / 3600))"
    else
        printf '%s min' "$((v / 60))"
    fi
    unset v
}
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
        _ask_choice=$(TOFI_REOPEN=1 "$tofi" --config "$conf" --prompt-text "$prompt" --height="$height" --padding-left=0 || true)
    else
        _ask_choice=$(TOFI_REOPEN=1 "$tofi" --config "$conf" --prompt-text "$prompt" --padding-left=0 || true)
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
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}Terminal" "${PAD}Arquivos · $(fm_label)" "${PAD}Gerenciador padrão · $(fm_label) >" "${PAD}Navegador" | ask "Aplicativos")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *Terminal*) exec foot ;;
            *Gerenciador*) sub_fm ;;
            *Arquivos*) exec "$script_dir/file-manager.sh" open ;;
            *Navegador*) exec librewolf ;;
        esac
    done
}

sub_fm() {
    while true; do
        if [ "$(fm_label)" = Dolphin ]; then mdolphin=' · Padrão'; mpcmanfm=''; else mdolphin=''; mpcmanfm=' · Padrão'; fi
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}PCManFM${mpcmanfm}" "${PAD}Dolphin${mdolphin}" | ask "Gerenciador padrão")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *PCManFM*) "$script_dir/file-manager.sh" pcmanfm ;;
            *Dolphin*) "$script_dir/file-manager.sh" dolphin ;;
        esac
        unset mdolphin mpcmanfm
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

sub_noite() {
    while true; do
        c=$(printf '%s\n' "${PAD}< Voltar" \
            "${PAD}Luz noturna · $(night_label)" \
            "${PAD}Temperatura da luz >" | ask "Luz noturna")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *noturna*) "$script_dir/nightlight.sh" ;;
            *Temperatura*) "$script_dir/nightmenu.sh" ;;
        esac
    done
}

sub_look() {
    while true; do
        if [ "$(theme_label)" = Claro ]; then mclaro=' · Ativo'; mescuro=''; else mclaro=''; mescuro=' · Ativo'; fi
        c=$(printf '%s\n' "${PAD}< Voltar" \
            "${PAD}Modo claro${mclaro}" \
            "${PAD}Modo escuro${mescuro}" \
            "$GAP" \
            "${PAD}Esquemas de cores · $(scheme_label)" \
            "${PAD}Estilo do fastfetch · $(fastfetch_label)" \
            "${PAD}Tema do Tofi · $(tofi_label)" \
            "$GAP" \
            "${PAD}Fonte · $(font_label)" \
            "${PAD}Tamanho da fonte · $(size_label)" \
            "${PAD}Fonte do terminal · $(term_label)" \
            "${PAD}Fonte mono · $(mono_label)" \
            "${PAD}Ícones · $(icon_label) >" \
            "$GAP" \
            "${PAD}Papel de parede" \
            "${PAD}Luz noturna · $(night_label) >" \
            "${PAD}Barra inferior · $(yambar_label)" \
            "${PAD}Relógio da barra · $(clock_label)" | ask "Aparência" 560)
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *claro*) "$script_dir/theme-toggle.sh" light ;;
            *escuro*) "$script_dir/theme-toggle.sh" dark ;;
            *Esquemas*) "$script_dir/scheme-menu.sh" ;;
            *fastfetch*) "$script_dir/fastfetch-menu.sh" ;;
            *Tamanho*) "$script_dir/ui-font-size.sh" ;;
            *Tema*) "$script_dir/tofi-themes.sh" ;;
            *terminal*) "$script_dir/term-font.sh" ;;
            *mono*) "$script_dir/mono-font.sh" ;;
            *Ícones*) sub_icons ;;
            *Fonte*) "$script_dir/ui-font.sh" ;;
            *Papel*) exec "$script_dir/wallpaper.sh" ;;
            *noturna*) sub_noite ;;
            *Barra*) "$script_dir/yambar-toggle.sh" ;;
            *Relógio*) "$script_dir/yambar-clock-toggle.sh" ;;
        esac
        unset mclaro mescuro
    done
}

sub_icons() {
    while true; do
        if [ "$(icon_label)" = Papirus ]; then mpapirus=' · Padrão'; myamis=''; else mpapirus=''; myamis=' · Padrão'; fi
        if [ "$(icon_label)" = Papirus ]; then
            c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}YAMIS-wal${myamis}" "${PAD}Papirus${mpapirus}" \
                "${PAD}Variante do Papirus · $(papirus_variant_label) >" | ask "Ícones")
        else
            c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}YAMIS-wal${myamis}" "${PAD}Papirus${mpapirus}" | ask "Ícones")
        fi
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *Variante*) sub_papirus ;;
            *YAMIS*) "$script_dir/icon-theme.sh" yamis || true ;;
            *Papirus*) "$script_dir/icon-theme.sh" papirus || true ;;
        esac
        unset myamis mpapirus
    done
}

sub_papirus() {
    while true; do
        case "$(papirus_variant_label)" in
            Base) mb=' · Ativo'; me=''; mc=''; ma='' ;;
            Escura) mb=''; me=' · Ativo'; mc=''; ma='' ;;
            Clara) mb=''; me=''; mc=' · Ativo'; ma='' ;;
            *) mb=''; me=''; mc=''; ma=' · Ativo' ;;
        esac
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}Automática${ma}" "${PAD}Base${mb}" "${PAD}Escura${me}" "${PAD}Clara${mc}" \
            "$GAP" \
            "${PAD}Cor das pastas · $(papirus_folders_label) >" \
            "${PAD}Corrigir ícones fixos" | ask "Variante do Papirus")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *Automática*) "$script_dir/icon-theme.sh" variant auto || true ;;
            *Base*) "$script_dir/icon-theme.sh" variant Papirus || true ;;
            *Escura*) "$script_dir/icon-theme.sh" variant Papirus-Dark || true ;;
            *Clara*) "$script_dir/icon-theme.sh" variant Papirus-Light || true ;;
            *pastas*) sub_papirus_folders ;;
            *fixos*) "$script_dir/icon-theme.sh" hardcode || true ;;
        esac
        unset ma mb me mc
    done
}

sub_papirus_folders() {
    while true; do
        cur=$(papirus_folders_label)
        c=$(printf '%s\n' "${PAD}< Voltar" "${PAD}Automática" "${PAD}Padrão" \
            "${PAD}adwaita" "${PAD}black" "${PAD}blue" "${PAD}bluegrey" "${PAD}breeze" "${PAD}brown" \
            "${PAD}carmine" "${PAD}cyan" "${PAD}darkcyan" "${PAD}deeporange" "${PAD}green" "${PAD}grey" \
            "${PAD}indigo" "${PAD}magenta" "${PAD}nordic" "${PAD}orange" "${PAD}palebrown" "${PAD}paleorange" \
            "${PAD}pink" "${PAD}teal" "${PAD}white" "${PAD}yellow" | ask "Cor das pastas")
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*) return 0 ;;
            *Automática*) "$script_dir/icon-theme.sh" folders auto || true ;;
            *Padrão*) "$script_dir/icon-theme.sh" folders default || true ;;
            *) "$script_dir/icon-theme.sh" folders "$c" || true ;;
        esac
        unset cur
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
            "${PAD}Bloqueio automático · $(lock_label) >" \
            "${PAD}Bateria · $(bat_label)" \
            "$GAP" \
            "${PAD}Hora · $(time_label)" \
            "${PAD}Data" \
            "${PAD}Bloquear tela" | ask "Sistema" 470)
        [ -n "$c" ] || return 0
        case "$c" in
            *Voltar*|"$GAP") continue ;;
            *transferência*) "$script_dir/clipboard.sh" ;;
            *Emoji*) "$script_dir/emoji.sh" ;;
            *Monitores*) "$script_dir/monitormenu.sh" ;;
            *Energia*) "$script_dir/powermenu.sh" ;;
            *Bloqueio*) "$script_dir/lockmenu.sh" ;;
            *Bateria*)
                cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 || printf '?')
                notify-send "Bateria" "$cap%"
                unset cap ;;
            *Hora*) notify-send "Hora" "$(date '+%H:%M')" ;;
            *Data*) notify-send "Data" "$(date '+%A, %d de %B de %Y')" ;;
            *Bloquear*) exec "$script_dir/dewlock.sh" ;;
        esac
    done
}

run_global() {
    # Busca global: uma lista flat com todas as folhas + entradas de
    # pickers (>). Sem GAPs (poluem o filtro); contexto vai no prefixo
    # "Categoria · ". Ordem do case: folhas longas antes das curtas
    # ("Fonte do terminal" antes de "Terminal", "Variante" antes de
    # "Papirus", "Bloquear" antes de "Bloqueio").
    while true; do
        if [ "$(theme_label)" = Claro ]; then mclaro=' · Ativo'; mescuro=''; else mclaro=''; mescuro=' · Ativo'; fi
        if [ "$(fm_label)" = Dolphin ]; then mdolphin=' · Padrão'; mpcmanfm=''; else mdolphin=''; mpcmanfm=' · Padrão'; fi
        if [ "$(icon_label)" = Papirus ]; then mpapirus=' · Padrão'; myamis=''; else mpapirus=''; myamis=' · Padrão'; fi
        c=$(printf '%s\n' \
            "${PAD}Terminal" \
            "${PAD}Arquivos · $(fm_label)" \
            "${PAD}PCManFM como padrão${mpcmanfm}" \
            "${PAD}Dolphin como padrão${mdolphin}" \
            "${PAD}Navegador" \
            "${PAD}Rede" \
            "${PAD}Bluetooth" \
            "${PAD}Modo claro${mclaro}" \
            "${PAD}Modo escuro${mescuro}" \
            "${PAD}Esquemas de cores · $(scheme_label) >" \
            "${PAD}Estilo do fastfetch · $(fastfetch_label) >" \
            "${PAD}Tema do Tofi · $(tofi_label) >" \
            "${PAD}Fonte · $(font_label) >" \
            "${PAD}Tamanho da fonte · $(size_label) >" \
            "${PAD}Fonte do terminal · $(term_label) >" \
            "${PAD}Fonte mono · $(mono_label) >" \
            "${PAD}Ícones YAMIS${myamis}" \
            "${PAD}Ícones Papirus${mpapirus}" \
            "${PAD}Variante do Papirus · $(papirus_variant_label) >" \
            "${PAD}Papel de parede" \
            "${PAD}Luz noturna · $(night_label)" \
            "${PAD}Temperatura da luz >" \
            "${PAD}Barra inferior · $(yambar_label)" \
            "${PAD}Relógio da barra · $(clock_label)" \
            "${PAD}Divisão automática · $(div_label)" \
            "${PAD}Avisos · $(dnd_label)" \
            "${PAD}Modo jogo · $(game_label)" \
            "${PAD}Área de transferência" \
            "${PAD}Emoji" \
            "${PAD}Monitores >" \
            "${PAD}Energia >" \
            "${PAD}Bloqueio automático · $(lock_label) >" \
            "${PAD}Bateria · $(bat_label)" \
            "${PAD}Hora · $(time_label)" \
            "${PAD}Data" \
            "${PAD}Bloquear tela" | ask "Ações" 560)
        [ -n "$c" ] || exit 0
        case "$c" in
            *Esquemas*) "$script_dir/scheme-menu.sh" ;;
            *fastfetch*) "$script_dir/fastfetch-menu.sh" ;;
            *Tamanho*) "$script_dir/ui-font-size.sh" ;;
            *Tema*Tofi*|*Tema*tofi*) "$script_dir/tofi-themes.sh" ;;
            *Fonte*terminal*) "$script_dir/term-font.sh" ;;
            *Fonte*mono*) "$script_dir/mono-font.sh" ;;
            *Variante*) sub_papirus ;;
            *YAMIS*) "$script_dir/icon-theme.sh" yamis || true ;;
            *Papirus*) "$script_dir/icon-theme.sh" papirus || true ;;
            *Fonte*|*fonte*) "$script_dir/ui-font.sh" ;;
            *Modo*claro*) "$script_dir/theme-toggle.sh" light ;;
            *Modo*escuro*) "$script_dir/theme-toggle.sh" dark ;;
            *Terminal*) exec foot ;;
            *Arquivos*) exec "$script_dir/file-manager.sh" open ;;
            *PCManFM*) "$script_dir/file-manager.sh" pcmanfm ;;
            *Dolphin*) "$script_dir/file-manager.sh" dolphin ;;
            *Navegador*) exec librewolf ;;
            *Rede*) open_rede ;;
            *Bluetooth*) open_bluetooth ;;
            *Papel*) exec "$script_dir/wallpaper.sh" ;;
            *Temperatura*) "$script_dir/nightmenu.sh" ;;
            *noturna*|*Noturna*) "$script_dir/nightlight.sh" ;;
            *Relógio*|*Relogio*) "$script_dir/yambar-clock-toggle.sh" ;;
            *Barra*) "$script_dir/yambar-toggle.sh" ;;
            *Divisão*|*Divisao*) toggle_autotiling ;;
            *Avisos*) toggle_dnd ;;
            *jogo*|*Jogo*) "$script_dir/game-mode.sh" toggle ;;
            *transferência*|*Transferencia*|*copiados*|*Copiados*) "$script_dir/clipboard.sh" ;;
            *Emoji*|*emoji*) "$script_dir/emoji.sh" ;;
            *Monitores*) "$script_dir/monitormenu.sh" ;;
            *Energia*) "$script_dir/powermenu.sh" ;;
            *Bloquear*) exec "$script_dir/dewlock.sh" ;;
            *Bloqueio*) "$script_dir/lockmenu.sh" ;;
            *Bateria*)
                cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1 || printf '?')
                notify-send "Bateria" "$cap%"
                unset cap ;;
            *Hora*) notify-send "Hora" "$(date '+%H:%M')" ;;
            *Data*) notify-send "Data" "$(date '+%A, %d de %B de %Y')" ;;
        esac
        unset mclaro mescuro mdolphin mpcmanfm myamis mpapirus
    done
}

main() {
    if [ -n "${TOFI_SEQ+set}" ]; then
        TOFI_SEQ_FILE=$(mktemp "${TMPDIR:-/tmp}/tofi-menu-seq.XXXXXX")
        printf '%s' "$TOFI_SEQ" > "$TOFI_SEQ_FILE"
        unset TOFI_SEQ
        trap 'rm -f "$TOFI_SEQ_FILE"' EXIT
    fi
    case "${1:-}" in
        --hub) hub_main ;;
        --global|"") run_global ;;
        *) run_global ;;
    esac
}

hub_main() {
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
