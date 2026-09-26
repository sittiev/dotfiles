#!/usr/bin/dash
# test-schemelib.sh — asserções do contrato schemelib.sh (T2 do plano).
# Roda via validate.sh. Usa os dados Gogh reais do repo, mas paths de
# estado/override apontados para um TMP — não toca no cache do usuário.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAILED=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { printf '[OK] %s\n' "$1"; }
bad() { printf '[FAIL] %s\n' "$1" >&2; FAILED=1; }

export SCHEME_JSON="$ROOT/sway/schemes/gogh-themes-min.json"
export SCHEME_OVERRIDE_DIR="$ROOT/sway/schemes/overrides"
export SCHEME_STATE="$TMP/theme-scheme"   # não existe por padrão

. "$ROOT/sway/scripts/colorlib.sh"
. "$ROOT/sway/scripts/schemelib.sh"

env_isset() {
    [ -n "${ENV_BG_S_MIN:-}${ENV_FG_S_MIN:-}${ENV_ACC_S_MIN:-}${ENV_MUT_S_MIN:-}${ENV_BRI_S_MIN:-}" ]
}

# ---- 1. sem estado ⇒ fallback (zero ENV_*) ----
scheme_init dark
if env_isset; then
    bad '1: sem estado exportou ENV_* (esperado: fallback)'
else
    ok '1: sem estado ⇒ fallback (nenhuma ENV_*)'
fi

# ---- 2. Apprentice + dark ⇒ constantes históricas do colorlib (override) ----
printf '%s' 'Apprentice' > "$SCHEME_STATE"
scheme_init dark
_e2=ok
[ "${ENV_ACC_S_MIN:-x}" = 20 ] && [ "${ENV_ACC_S_MAX:-x}" = 35 ] &&
[ "${ENV_ACC_L_MIN:-x}" = 45 ] && [ "${ENV_ACC_L_MAX:-x}" = 55 ] || _e2=fail
[ "${ENV_MUT_S_MIN:-x}" = 0 ]  && [ "${ENV_MUT_S_MAX:-x}" = 12 ] &&
[ "${ENV_MUT_L_MIN:-x}" = 26 ] && [ "${ENV_MUT_L_MAX:-x}" = 40 ] || _e2=fail
[ "${ENV_BRI_S_MIN:-x}" = 20 ] && [ "${ENV_BRI_S_MAX:-x}" = 40 ] &&
[ "${ENV_BRI_L_MIN:-x}" = 55 ] && [ "${ENV_BRI_L_MAX:-x}" = 70 ] || _e2=fail
[ "${ENV_BG_S_MIN:-x}" = 0 ]   && [ "${ENV_BG_S_MAX:-x}" = 8 ]   &&
[ "${ENV_BG_L_MIN:-x}" = 12 ]  && [ "${ENV_BG_L_MAX:-x}" = 18 ]  || _e2=fail
[ "${ENV_FG_S_MIN:-x}" = 0 ]   && [ "${ENV_FG_S_MAX:-x}" = 8 ]   &&
[ "${ENV_FG_L_MIN:-x}" = 68 ]  && [ "${ENV_FG_L_MAX:-x}" = 76 ]  || _e2=fail
if [ "$_e2" = ok ]; then
    ok '2: Apprentice+dark ⇒ constantes históricas (override)'
else
    bad "2: Apprentice+dark ≠ constantes (ACC=${ENV_ACC_S_MIN:-?} ${ENV_ACC_S_MAX:-?} ${ENV_ACC_L_MIN:-?} ${ENV_ACC_L_MAX:-?})"
fi

# ---- 3. derivação real (Dracula, sem override) ⇒ 0 ≤ min ≤ max ≤ 100 ----
printf '%s' 'Dracula' > "$SCHEME_STATE"
scheme_init dark
_e3=ok
for _r in BG FG ACC MUT BRI; do
    eval "_smin=\$ENV_${_r}_S_MIN _smax=\$ENV_${_r}_S_MAX _lmin=\$ENV_${_r}_L_MIN _lmax=\$ENV_${_r}_L_MAX"
    case "${_smin:-}${_smax:-}${_lmin:-}${_lmax:-}" in
        ''|*[!0-9]*) _e3=fail ;;
    esac
    [ "${_smin:-101}" -le "${_smax:--1}" ] 2>/dev/null || _e3=fail
    [ "${_lmin:-101}" -le "${_lmax:--1}" ] 2>/dev/null || _e3=fail
    [ "${_smin:--1}" -ge 0 ] && [ "${_smax:-101}" -le 100 ] &&
    [ "${_lmin:--1}" -ge 0 ] && [ "${_lmax:-101}" -le 100 ] || _e3=fail
done
if [ "$_e3" = ok ]; then
    ok '3: Dracula deriva envelopes dentro de 0..100'
else
    bad "3: Dracula fora da faixa (ACC=${ENV_ACC_S_MIN:-?} ${ENV_ACC_S_MAX:-?} ${ENV_ACC_L_MIN:-?} ${ENV_ACC_L_MAX:-?})"
fi

# ---- 4. espelhamento: variante light + modo dark ⇒ L' = 100 − L, S intacto ----
printf '%s' '1984 Light' > "$SCHEME_STATE"
scheme_init light
_e4=ok
for _r in BG FG ACC MUT BRI; do
    eval "_n_${_r}=\"\$ENV_${_r}_S_MIN \$ENV_${_r}_S_MAX \$ENV_${_r}_L_MIN \$ENV_${_r}_L_MAX\""
done
scheme_init dark
for _r in BG FG ACC MUT BRI; do
    eval "_n=\"\$_n_${_r}\""
    set -- $_n                       # nativo: nsmin nsmax nlmin nlmax
    _nsmin=$1 _nsmax=$2 _nlmin=$3 _nlmax=$4
    eval "_smin=\$ENV_${_r}_S_MIN _smax=\$ENV_${_r}_S_MAX _lmin=\$ENV_${_r}_L_MIN _lmax=\$ENV_${_r}_L_MAX"
    [ "${_smin:-x}" = "$_nsmin" ] && [ "${_smax:-x}" = "$_nsmax" ] &&
    [ "${_lmin:-x}" = "$((100 - _nlmax))" ] &&
    [ "${_lmax:-x}" = "$((100 - _nlmin))" ] || { _e4=fail; _why4=$_r; }
done
if [ "$_e4" = ok ]; then
    ok '4: variante light + modo dark ⇒ L espelhado (100−L), S intacto'
else
    bad "4: espelhamento incorreto no papel ${_why4:-?}"
fi

# ---- 5. esquema desconhecido ⇒ exit 0, fallback e SCHEME_NAME limpo ----
printf '%s' 'Esquema Que Nao Existe' > "$SCHEME_STATE"
scheme_init dark
_rc=$?
if [ "$_rc" -eq 0 ] && ! env_isset && [ -z "${SCHEME_NAME:-}" ]; then
    ok '5: esquema desconhecido ⇒ exit 0 + fallback + SCHEME_NAME limpo'
else
    bad "5: desconhecido não degradou graciosamente (rc=$_rc, env=$(env_isset && echo sim || echo nao), name=${SCHEME_NAME:-<vazio>})"
fi

# ---- 6. chroma_mean: H, S e SPREAD ----
# SPREAD foi o que travou a janela de hue: um bug de subscript do awk
# (n não inicializado ⇒ hv[""] em vez de hv[0]) descartava a primeira cor e
# devolvia spread 153° para uma paleta de 4°, abrindo a janela e deixando o
# terminal roxo. O teste fixa os três campos.
_cm=$(chroma_mean '597da0,5f85a8,697986,6987a6,7d92a8,819cb1')
set -- $_cm
# chroma_mean devolve decimais; compara via awk (test só faz inteiro).
if [ "$#" -eq 3 ] && LC_ALL=C awk -v s="$2" -v d="$3" \
    'BEGIN { exit !(s >= 15 && s <= 35 && d >= 3 && d <= 7) }'; then
    ok "6: chroma_mean ⇒ H=$1 S=$2 SPREAD=$3 (paleta monocromática, spread pequeno)"
else
    bad "6: chroma_mean inesperado ($_cm) — esperado H S SPREAD com S 15..35 e spread 3..7"
fi
# A mesma lista com uma cor a 180° deve ter spread perto de 180.
_cm2=$(chroma_mean '597da0,ff0000')
if LC_ALL=C awk -v d="${_cm2##* }" 'BEGIN { exit !(d >= 150 && d <= 180) }'; then
    ok "6b: chroma_mean detecta spread grande (${_cm2##* })"
else
    bad "6b: chroma_mean spread=${_cm2##* } (esperado 150..180 para azul+vermelho)"
fi
# Tudo acromático tem de falhar (imagem P&B cai no caminho do scheme).
if chroma_mean '262626,303030,3a3a3a' >/dev/null 2>&1; then
    bad '6c: chroma_mean aceitou lista toda-cinza (deveria falhar)'
else
    ok '6c: chroma_mean ⇒ falha em lista toda-cinza (imagem P&B)'
fi

# ---- 7. hue_pull: janela em torno da âncora ----
# A janela é o que mantém a paleta na família do wallpaper. k=1 sem janela
# deixava o spread de ~300° do scheme pintar de magenta num wallpaper azul.
_hp=$(hue_pull d05000 208.94 1 38.54 60)
_hph=$(rgb2hsl_hex "$_hp"); _hph=${_hph%% *}
# 208.94 ± 60 ⇒ [148.94, 268.94]
if LC_ALL=C awk -v h="$_hph" 'BEGIN { exit !(h >= 148 && h <= 269) }'; then
    ok "7: hue_pull respeita a janela ±60 (23° → $_hph°)"
else
    bad "7: hue_pull escapou da janela (23° → $_hph°, esperado 149..269)"
fi
# Janela estreita tem de cortar mais.
_hp2=$(hue_pull d05000 208.94 1 38.54 10)
_hp2h=$(rgb2hsl_hex "$_hp2"); _hp2h=${_hp2h%% *}
if LC_ALL=C awk -v h="$_hp2h" 'BEGIN { exit !(h >= 198 && h <= 219) }'; then
    ok "7b: hue_pull com janela ±10 prende no ancorador (→ $_hp2h°)"
else
    bad "7b: hue_pull janela ±10 deu $_hp2h° (esperado 199..219)"
fi
# Acromático na entrada ⇒ neutro na saída (o clamp de S não pode inventar hue).
_hp3=$(hue_pull 282828 208.94 1 38.54 60)
if [ "$_hp3" = 282828 ]; then
    ok '7c: hue_pull de acromático devolve neutro (não inventa matiz)'
else
    bad "7c: hue_pull de #282828 devolveu $_hp3 (esperado 282828)"
fi

exit "$FAILED"
