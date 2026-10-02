#!/usr/bin/dash
# Alterna o relogio do yambar entre so-horario e data+horario.
# Chamado pelo on-click nativo da particula (sem shell no meio).
set -eu
state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yambar-clock-full"
if [ -f "$state" ]; then
    rm -f "$state"
else
    : > "$state"
fi
