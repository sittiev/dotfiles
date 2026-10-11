#!/usr/bin/dash
# Escolhe o estilo do fastfetch (Aparência -> "Estilo do fastfetch").
# Biblioteca em ~/.config/fastfetch/presets/*.jsonc, um arquivo por estilo
# da discussão fastfetch #971, com cores do schema (paleta do terminal).
# Sem arg: abre o seletor no tofi. Salva o slug em ~/.cache/fastfetch-style
# e copia o preset para ~/.config/fastfetch/config.jsonc (ausente = padrao).
# Uso: fastfetch-menu.sh [slug]   (TOFI_FASTFETCH dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
presets="$HOME/.config/fastfetch/presets"
dest="$HOME/.config/fastfetch/config.jsonc"
state="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch-style"

[ -d "$presets" ] || {
    notify-send "Estilos do fastfetch ausentes" "Para escolher um estilo, restaure ~/.config/fastfetch/presets." 2>/dev/null || true
    exit 1
}

# Rótulo = 1ª linha do preset ("// Título — fonte: ..."): estilo novo é só
# um arquivo novo, sem mapear nada aqui.
title_of() { sed -n '1p' "$presets/$1.jsonc" 2>/dev/null | sed -e 's|^// ||' -e 's| — .*||' || printf '%s' "$1"; }

names=$(ls "$presets" 2>/dev/null | sed -n 's/\.jsonc$//p' | sort) || names=''
[ -n "$names" ] || {
    notify-send "Nenhum estilo encontrado" "Para escolher um estilo, restaure a biblioteca em ~/.config/fastfetch/presets." 2>/dev/null || true
    exit 1
}

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_FASTFETCH:-}" ]; then
        choice=$TOFI_FASTFETCH
    else
        list=$(for n in $names; do printf '%s\n' "$(title_of "$n")"; done)
        choice=$(printf '%s\n' '< Voltar' "$list" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fastfetch" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in *Voltar*) exit 0 ;; esac
    # Título -> slug: casa pela 1ª linha do preset.
    pick=''
    for n in $names; do
        if [ "$(title_of "$n")" = "$choice" ]; then pick=$n; break; fi
    done
    [ -n "$pick" ] || {
        notify-send "Estilo inválido" "Para aplicar, escolha um nome da lista. Recebido: $choice" 2>/dev/null || true
        exit 1
    }
    unset list
fi

pick=$(basename -- "$pick")
[ -f "$presets/$pick.jsonc" ] || {
    notify-send "Estilo inválido" "Para aplicar, escolha um nome da lista. Recebido: $pick" 2>/dev/null || true
    exit 1
}

# Escrita atômica (leitores em paralelo nunca veem o arquivo vazio).
mkdir -p -- "${state%/*}" "$(dirname -- "$dest")"
tmp="$state.tmp.$$"
trap 'rm -f -- "$tmp" "$dest.tmp.$$"' EXIT
printf '%s' "$pick" > "$tmp"
mv -f -- "$tmp" "$state"
cp -f -- "$presets/$pick.jsonc" "$dest.tmp.$$"
mv -f -- "$dest.tmp.$$" "$dest"
trap - EXIT

notify-send "Estilo do fastfetch" "$(title_of "$pick") aplicado." 2>/dev/null || true
