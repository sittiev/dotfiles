#!/usr/bin/dash
# Keep one text and one primary-selection clipboard watcher.
set -eu

if ! pgrep -f '[w]l-paste --type text --watch cliphist store' >/dev/null 2>&1; then
    wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
fi
if ! pgrep -f '[w]l-paste --type primary --watch cliphist store' >/dev/null 2>&1; then
    wl-paste --type primary --watch cliphist store >/dev/null 2>&1 &
fi
