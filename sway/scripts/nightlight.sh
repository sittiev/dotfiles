#!/usr/bin/dash
# nightlight.sh — manual night-light toggle (Super+n).
#
# On  = 1000 K on every active output.  Off = normal gamma.
# No clocks, no automation: while on, a wlsunset instance stays resident.

set -eu

# shellcheck disable=SC1091
. "${0%/*}/nightlib.sh"

main() {
    if night_is_on; then
        night_off || true
    else
        night_apply 1000
    fi
}

main "$@"
