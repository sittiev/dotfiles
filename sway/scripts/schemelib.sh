#!/usr/bin/dash
# schemelib.sh — envelopes HSL do esquema Gogh selecionado.
#   . "$HOME/.config/sway/scripts/schemelib.sh"
#   scheme_init <dark|light>
#
# Contrato: exporta ENV_<PAPEL>_{S,L}_{MIN,MAX} (0 ≤ min ≤ max ≤ 100) para os
# papéis BG FG ACC MUT BRI, mais SCHEME_NAME/SCHEME_VARIANT/SCHEME_MATCH.
# Sem estado / jq ausente / JSON ausente / esquema desconhecido ⇒ exporta
# NADA: o colorlib cai nas constantes Apprentice atuais (${ENV_*:-default}).
#
# Derivação: cores do esquema → rgb2hsl_hex (colorlib) → min/max por papel
# com pad S±4 L±3, clamp 0..100. Override (sway/schemes/overrides/<slug>[.light].env)
# tem precedência e é orientado por modo: <slug>.env = dark, <slug>.light.env = light.
# Se variante ≠ modo (sem override) ⇒ espelha L: lmin'=100−lmax, lmax'=100−lmin.
#
# Paths sobrescrevíveis por env (usado pelos testes): SCHEME_STATE,
# SCHEME_JSON, SCHEME_OVERRIDE_DIR.

if ! command -v rgb2hsl_hex >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    . "$HOME/.config/sway/scripts/colorlib.sh"
fi

_scheme_unset() {
    for _r in BG FG ACC MUT BRI; do
        unset "ENV_${_r}_S_MIN" "ENV_${_r}_S_MAX" "ENV_${_r}_L_MIN" "ENV_${_r}_L_MAX"
    done
    unset SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH
}

_scheme_slug() { # "1984 Light" → "1984-light"
    LC_ALL=C printf '%s' "$1" | LC_ALL=C awk '{
        s = tolower($0)
        gsub(/[^a-z0-9]+/, "-", s)
        gsub(/^-+/, "", s); gsub(/-+$/, "", s)
        printf "%s", s
    }'
}

_env1() { # "hex,hex,..." → "smin smax lmin lmax" (pad S±4 L±3, clamp 0..100)
    # printf '%s\n' garante newline final (sem ele o read descarta a 1ª linha
    # quando não há vírgula); cada cor vira uma linha "H S L" pro awk.
    printf '%s\n' "$1" | tr ',' '\n' |
        while IFS= read -r _h; do
            [ -n "$_h" ] || continue
            rgb2hsl_hex "${_h#\#}"
            printf '\n'
        done |
        LC_ALL=C awk '
        {
            s = $2 + 0; l = $3 + 0
            if (NR == 1) { smin = smax = s; lmin = lmax = l }
            else {
                if (s < smin) smin = s
                if (s > smax) smax = s
                if (l < lmin) lmin = l
                if (l > lmax) lmax = l
            }
        }
        END {
            if (NR == 0) exit 1
            smin = int(smin - 4 + 0.5); smax = int(smax + 4 + 0.5)
            lmin = int(lmin - 3 + 0.5); lmax = int(lmax + 3 + 0.5)
            if (smin < 0) smin = 0; if (smax > 100) smax = 100
            if (lmin < 0) lmin = 0; if (lmax > 100) lmax = 100
            if (smin > smax) smax = smin
            if (lmin > lmax) lmax = lmin
            printf "%d %d %d %d", smin, smax, lmin, lmax
        }'
}

_mirror() { # "smin smax lmin lmax" → L espelhado em torno de 50%, S intacto
    LC_ALL=C printf '%s\n' "$1" | LC_ALL=C awk \
        '{ printf "%d %d %d %d", $1, $2, 100 - $4, 100 - $3 }'
}

_set_env() { # <PAPEL> <smin smax lmin lmax>
    _r=$1 _smin=$2 _smax=$3 _lmin=$4 _lmax=$5
    eval "ENV_${_r}_S_MIN=\$_smin ENV_${_r}_S_MAX=\$_smax ENV_${_r}_L_MIN=\$_lmin ENV_${_r}_L_MAX=\$_lmax"
    eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX"
}

scheme_init() {
    _mode=${1:-dark}
    case "$_mode" in dark|light) ;; *) _mode=dark ;; esac
    _scheme_unset

    _state="${SCHEME_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme}"
    _json="${SCHEME_JSON:-$HOME/.config/sway/schemes/gogh-themes-min.json}"
    _ovr="${SCHEME_OVERRIDE_DIR:-$HOME/.config/sway/schemes/overrides}"

    SCHEME_NAME=$(cat "$_state" 2>/dev/null) || SCHEME_NAME=''
    [ -n "$SCHEME_NAME" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    [ -f "$_json" ] || return 0

    _rows=$(jq -r --arg n "$SCHEME_NAME" '
        .[] | select(.name == $n) |
        ["VARIANT=" + .variant,
         "BG=" + .background,
         "FG=" + .foreground,
         "ACC=" + ([.color_02,.color_03,.color_04,.color_05,.color_06,.color_07] | join(",")),
         "MUT=" + ([.color_08,.color_09] | join(",")),
         "BRI=" + ([.color_10,.color_11,.color_12,.color_13,.color_14,.color_15,.color_16] | join(","))] | .[]
    ' "$_json") || _rows=''
    [ -n "$_rows" ] || return 0   # esquema desconhecido ⇒ fallback

    _v='' _bg='' _fg='' _acc='' _mut='' _bri=''
    while IFS= read -r _line; do
        case $_line in
            VARIANT=*) _v=${_line#VARIANT=} ;;
            BG=*)      _bg=${_line#BG=} ;;
            FG=*)      _fg=${_line#FG=} ;;
            ACC=*)     _acc=${_line#ACC=} ;;
            MUT=*)     _mut=${_line#MUT=} ;;
            BRI=*)     _bri=${_line#BRI=} ;;
        esac
    done <<EOF
$_rows
EOF
    case "$_v" in dark|light) ;; *) return 0 ;; esac
    [ -n "$_bg$_fg$_acc$_mut$_bri" ] || return 0

    SCHEME_VARIANT=$_v
    if [ "$_v" = "$_mode" ]; then SCHEME_MATCH=1; else SCHEME_MATCH=0; fi
    export SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH

    # ---- override por modo (precedência sobre derivação) ----
    _slug=$(_scheme_slug "$SCHEME_NAME")
    if [ "$_mode" = light ]; then
        _ov="$_ovr/$_slug.light.env"
    else
        _ov="$_ovr/$_slug.env"
    fi
    if [ -f "$_ov" ]; then
        # shellcheck disable=SC1090
        . "$_ov" || return 0
        for _r in BG FG ACC MUT BRI; do
            eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX" 2>/dev/null || true
        done
        return 0
    fi

    # ---- derivação + espelhamento (variante ≠ modo) ----
    _e_bg=$(_env1 "$_bg")   || return 0
    _e_fg=$(_env1 "$_fg")   || return 0
    _e_acc=$(_env1 "$_acc") || return 0
    _e_mut=$(_env1 "$_mut") || return 0
    _e_bri=$(_env1 "$_bri") || return 0
    if [ "$SCHEME_MATCH" -eq 0 ]; then
        _e_bg=$(_mirror "$_e_bg")
        _e_fg=$(_mirror "$_e_fg")
        _e_acc=$(_mirror "$_e_acc")
        _e_mut=$(_mirror "$_e_mut")
        _e_bri=$(_mirror "$_e_bri")
    fi
    _set_env BG $_e_bg
    _set_env FG $_e_fg
    _set_env ACC $_e_acc
    _set_env MUT $_e_mut
    _set_env BRI $_e_bri
    return 0
}
