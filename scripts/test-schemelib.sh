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

exit "$FAILED"
