#!/usr/bin/dash
# schemelib.sh — envelopes HSL do esquema Gogh selecionado.
#   . "$HOME/.config/sway/scripts/schemelib.sh"
#   scheme_init <dark|light>
#
# Contrato: exporta ENV_<PAPEL>_{S,L}_{MIN,MAX} (0 ≤ min ≤ max ≤ 100) para os
# papéis BG FG ACC MUT BRI, mais SCHEME_BG_HEX/SCHEME_FG_HEX (fundo e texto do
# próprio scheme, L já espelhado quando variante ≠ modo — é o que faz o fundo,
# inclusive o chip do yambar, mudar ao trocar de scheme). Scheme cromático
# (bg com S≥6) também exporta ENV_BG_H/ENV_FG_H/ENV_ACC_H (hue em graus) — o
# clamp de papel preserva o hue do wallpaper, e sem isso um envelope saturado
# pintava o verde do wallpaper num scheme azul. Scheme quase acromático não
# exporta _H: o humor do wallpaper segue como antes.
# SCHEME_NAME/SCHEME_VARIANT/SCHEME_MATCH são
# exportados SÓ quando as ENV_* estão completas — presença de SCHEME_NAME é
# marcador confiável de sucesso. Sem estado / jq ausente / JSON ausente /
# esquema desconhecido ⇒ exporta NADA: o colorlib cai nas constantes
# Apprentice atuais (${ENV_*:-default}).
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
        unset "ENV_${_r}_S_MIN" "ENV_${_r}_S_MAX" "ENV_${_r}_L_MIN" "ENV_${_r}_L_MAX" "ENV_${_r}_H"
    done
    unset SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH SCHEME_BG_HEX SCHEME_FG_HEX SCHEME_ACC_CAND
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

_hue_chroma() { # <hex> → "H" se S>=6 (scheme cromático), vazio se quase cinza
    # O clamp de papel preserva o hue do wallpaper; num envelope saturado
    # (ex.: Aardvark Blue, S56-64) isso pintava verde num scheme azul.
    # Esquema quase acromático (Apprentice #262626) não exporta nada — aí o
    # humor do wallpaper segue como antes.
    _hc=${1#\#}
    [ -n "$_hc" ] || return 0
    _hcl=$(rgb2hsl_hex "$_hc")
    _hcs=${_hcl#* }; _hcs=${_hcs%% *}
    if LC_ALL=C awk -v s="$_hcs" 'BEGIN { exit !(s + 0 < 6) }'; then
        return 0
    fi
    printf '%s' "${_hcl%% *}"
}

_acc_pick() { # "hex,hex,..." <hue-bg> → hex do accent de menor distância circular
    _ap_h=$2
    printf '%s\n' "$1" | tr ',' '\n' | while IFS= read -r _ap_c; do
        [ -n "$_ap_c" ] || continue
        _ap_hl=$(rgb2hsl_hex "${_ap_c#\#}")
        LC_ALL=C awk -v a="${_ap_hl%% *}" -v b="$_ap_h" -v c="$_ap_c" 'BEGIN {
            d = a - b; if (d < 0) d = -d; if (d > 180) d = 360 - d
            printf "%d\t%s\n", d, c }'
    done | sort -n | head -1 | cut -f2
}

_mirror_hex() { # "rrggbb" → mesma cor com L espelhado (100−L), p.ex. variante ≠ modo
    _mh=${1#\#}
    [ -n "$_mh" ] || return 0
    _mhl=$(rgb2hsl_hex "$_mh")
    _mhr=${_mhl#* }; _mhs=${_mhr%% *}; _mhlv=${_mhr#* }
    hsl2rgb_hex "${_mhl%% *}" "$_mhs" \
        "$(LC_ALL=C awk -v l="$_mhlv" 'BEGIN { printf "%.2f", 100 - l }')"
}

scheme_init() {
    _mode=${1:-dark}
    case "$_mode" in dark|light) ;; *) _mode=dark ;; esac
    _scheme_unset

    _state="${SCHEME_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme}"
    _json="${SCHEME_JSON:-$HOME/.config/sway/schemes/gogh-themes-min.json}"
    _ovr="${SCHEME_OVERRIDE_DIR:-$HOME/.config/sway/schemes/overrides}"

    _name=$(cat "$_state" 2>/dev/null) || _name=''
    [ -n "$_name" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    [ -f "$_json" ] || return 0

    _rows=$(jq -r --arg n "$_name" '
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

    if [ "$_v" = "$_mode" ]; then _match=1; else _match=0; fi

    # Fundos do próprio scheme, já no modo ativo (L espelhado em variante ≠
    # modo). É isto que faz o fundo — inclusive o chip do yambar — mudar ao
    # trocar de scheme: o envelope + hue do wallpaper convergia todos os
    # schemes escuros quase-acromáticos no mesmo carvão.
    _bgx=$_bg; _fgx=$_fg
    if [ "$_match" -eq 0 ]; then
        _bgx=$(_mirror_hex "$_bg") || return 0
        _fgx=$(_mirror_hex "$_fg") || return 0
    fi
    SCHEME_BG_HEX=${_bgx#\#} SCHEME_FG_HEX=${_fgx#\#}
    export SCHEME_BG_HEX SCHEME_FG_HEX
    # Candidatos de accent (color_02..07) pro python escolher quando o scheme é
    # quase acromático (sem ENV_ACC_H): sem isso o accent fica no hue do
    # wallpaper e a seleção do GTK/terminal não muda entre schemes.
    SCHEME_ACC_CAND=$(printf '%s' "$_acc" | tr 'A-F' 'a-f' | tr -d '#')
    export SCHEME_ACC_CAND

    # ---- override por modo (precedência sobre derivação) ----
    _slug=$(_scheme_slug "$_name")
    if [ "$_mode" = light ]; then
        _ov="$_ovr/$_slug.light.env"
    else
        _ov="$_ovr/$_slug.env"
    fi
    if [ -f "$_ov" ]; then
        # shellcheck disable=SC1090
        . "$_ov" || return 0
        # override sem envelope ACC ⇒ arquivo ruim, ignora inteiro (fallback)
        [ -n "${ENV_ACC_S_MIN:-}${ENV_ACC_S_MAX:-}${ENV_ACC_L_MIN:-}${ENV_ACC_L_MAX:-}" ] || return 0
        for _r in BG FG ACC MUT BRI; do
            eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX" 2>/dev/null || true
        done
        SCHEME_NAME=$_name SCHEME_VARIANT=$_v SCHEME_MATCH=$_match
        export SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH
        return 0
    fi

    # ---- derivação + espelhamento (variante ≠ modo) ----
    _hbg=$(_hue_chroma "$_bg") || true
    _hfg=$(_hue_chroma "$_fg") || true
    _e_bg=$(_env1 "$_bg")   || return 0
    _e_fg=$(_env1 "$_fg")   || return 0
    _e_acc=$(_env1 "$_acc") || return 0
    _e_mut=$(_env1 "$_mut") || return 0
    _e_bri=$(_env1 "$_bri") || return 0
    # Scheme cromático: accent vem do próprio scheme (o candidato mais
    # próximo do hue do bg) em vez do hue do wallpaper — seleção verde num
    # scheme azul era a última cor fora da família. Scheme quase cinza
    # (_hbg vazio, ex.: Apprentice/Ayu) mantém o humor do wallpaper.
    _acc_sel=''
    if [ -n "$_hbg" ]; then
        _acc_sel=$(_acc_pick "$_acc" "$_hbg") || return 0
        if [ -n "$_acc_sel" ]; then
            _e_acc=$(_env1 "$_acc_sel") || return 0
        fi
    fi
    if [ "$_match" -eq 0 ]; then
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
    if [ -n "$_hbg" ]; then ENV_BG_H=$_hbg; export ENV_BG_H; fi
    if [ -n "$_hfg" ]; then ENV_FG_H=$_hfg; export ENV_FG_H; fi
    if [ -n "$_acc_sel" ]; then
        _hac=$(_hue_chroma "$_acc_sel") || true
        if [ -n "$_hac" ]; then ENV_ACC_H=$_hac; export ENV_ACC_H; fi
    fi
    SCHEME_NAME=$_name SCHEME_VARIANT=$_v SCHEME_MATCH=$_match
    export SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH
    return 0
}
