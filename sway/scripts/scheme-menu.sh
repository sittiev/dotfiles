#!/usr/bin/dash
# Pick a Gogh color scheme and apply it (Mod+Shift+x -> "Esquemas de cores").
# Writes the scheme name to ~/.cache/theme-scheme and re-applies the theme;
# with the state absent everything falls back to the Apprentice constants.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
json="$HOME/.config/sway/schemes/gogh-themes-min.json"
state="${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme"

[ -f "$json" ] || {
    notify-send "Biblioteca de esquemas ausente" "Para listar esquemas, rode scripts/update-schemes.sh." 2>/dev/null || true
    exit 1
}
command -v jq >/dev/null 2>&1 || {
    notify-send "Lista de esquemas indisponível" "Para listar esquemas, instale jq: sudo pacman -S jq." 2>/dev/null || true
    exit 1
}

# Lista "Nome (variant)" — a variante desambigua light/dark na mesma lista.
# Apprentice (dark) lidera a lista (entrada inicial do menu).
_sorted=$(jq -r '.[] | "\(.name) (\(.variant))"' "$json" | sort)
if printf '%s\n' "$_sorted" | grep -q '^Apprentice (dark)$'; then
    names=$(printf 'Apprentice (dark)\n%s\n' \
        "$(printf '%s\n' "$_sorted" | grep -v '^Apprentice (dark)$')")
else
    names=$_sorted
fi
unset _sorted
[ -n "$names" ] || {
    notify-send "Nenhum esquema encontrado" "Para listar esquemas, restaure a biblioteca com scripts/update-schemes.sh." 2>/dev/null || true
    exit 1
}

if [ -n "${TOFI_SCHEME:-}" ]; then
    choice=$TOFI_SCHEME
else
    choice=$(printf '%s\n' "$names" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Esquema: " || true)
fi
[ -n "$choice" ] || exit 0

# Desfaz só o sufixo final " (variant)" — nomes podem ter parênteses próprios.
name=$(printf '%s' "$choice" | sed -e 's/ (dark)$//' -e 's/ (light)$//')

if ! jq -e --arg n "$name" 'any(.[]; .name == $n)' "$json" >/dev/null 2>&1; then
    notify-send "Esquema inválido" "Para aplicar, escolha um nome da lista. Recebido: $choice" 2>/dev/null || true
    exit 1
fi

# Escrita atômica (leitores em paralelo nunca veem o arquivo vazio).
mkdir -p -- "${state%/*}"
tmp="$state.tmp.$$"
trap 'rm -f -- "$tmp"' EXIT
printf '%s' "$name" > "$tmp"
mv -f -- "$tmp" "$state"
trap - EXIT

exec "$script_dir/theme.sh"
