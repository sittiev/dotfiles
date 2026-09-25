#!/usr/bin/dash
# Toggle the clock-only Yambar bar.
set -eu
if pgrep -x yambar >/dev/null 2>&1; then
    pkill -x yambar
else
    LC_TIME=C yambar >/dev/null 2>&1 &
fi
