#!/usr/bin/dash
# nightlib.sh — shared routines for the manual night light (wlsunset).
#
# POSIX sh (dash). Source it, do not execute it:
#   . "${0%/*}/nightlib.sh"
# shellcheck shell=dash
#
# Design notes (Google Shell Style Guide + POSIX):
#   - no bashisms: no arrays, [[ ]], (( )), here-strings, pipefail
#   - UPPER_CASE readonly constants, lower_case functions (s7)
#   - every function documented (s4.2); intentional word-splitting
#     is marked with shellcheck disable=SC2086 plus rationale
#   - lib changes no global shell state (no set -e here; callers opt in)
#
# Provides:
#   night_outputs      print active output names, one per line
#   night_apply TEMP [GAMMA]
#                      (re)start wlsunset with TEMP on every active output
#   night_off          stop wlsunset (exit status ignored by callers)
#   night_is_on        true iff a wlsunset instance is managed
#
# Dependencies (external): wlsunset, swaymsg+jq (outputs), pkill/pgrep.

# Day temperature: wlsunset only models a sun curve, so "manual" mode is
# expressed as a ~24h night (23:59 -> 00:00). One minute of day remains.
readonly NIGHT_DAY_TEMP=6500
readonly NIGHT_SUNRISE=23:59
readonly NIGHT_SUNSET=00:00

# night_outputs: active outputs, one name per line.
# Empty output (compositor unknown) means "let wlsunset cover all outputs".
night_outputs() {
    if [ -n "${SWAYSOCK:-}" ] && command -v swaymsg >/dev/null 2>&1; then
        swaymsg -t get_outputs 2>/dev/null \
            | jq -r '.[] | select(.active) | .name' 2>/dev/null
    fi
    return 0
}

# night_apply TEMP [GAMMA]: (re)start wlsunset.
# TEMP is 1000..6500 K. GAMMA is optional (e.g. 0.8 darkens mid-tones).
night_apply() {
    temp=${1:?night_apply: TEMP is required}
    gamma=${2:-}
    night_off 2>/dev/null || true
    set -- -t "$temp" -T "$NIGHT_DAY_TEMP" \
        -S "$NIGHT_SUNRISE" -s "$NIGHT_SUNSET"
    if [ -n "$gamma" ]; then
        set -- "$@" -g "$gamma"
    fi
    out=$(night_outputs) || out=""
    if [ -n "$out" ]; then
        # Output names are DRM connector names (no whitespace by construction),
        # so word-splitting one "-o NAME" pair per line is safe here.
        # shellcheck disable=SC2046
        set -- "$@" $(printf '%s\n' "$out" | sed 's/^/-o /')
    fi
    wlsunset "$@" >/dev/null 2>&1 &
}

# night_off: stop any managed wlsunset. Always succeeds from caller view.
night_off() {
    pkill -x wlsunset 2>/dev/null
}

# night_is_on: true iff wlsunset is currently managing outputs.
night_is_on() {
    pgrep -x wlsunset >/dev/null 2>&1
}
