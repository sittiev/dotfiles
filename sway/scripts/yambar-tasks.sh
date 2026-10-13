#!/usr/bin/dash
# Chip de tarefas do yambar: emite a contagem de checkboxes abertos no
# vault Obsidian (o backend C e o .py têm o mesmo contrato de scan —
# mesma exclusão de pastas; aqui só o print) e, no on-click, abre a TUI.
# O poll-interval fica na config do yambar (render.sh); o custo por tick
# é um scan de ~80 arquivos .md (<0,1s medido).
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${1:-}" = "--toggle" ]; then
    exec "$script_dir/yambar-tasks-toggle.sh"
fi

# Binário C primeiro (make em sway/scripts); .py de fallback.
if [ -x "$script_dir/yambar-tasks-c" ]; then
    n=$("$script_dir/yambar-tasks-c" --count)
else
    n=$("$script_dir/yambar-tasks.py" --count)
fi
printf 'display|string|%s\n\n' "$( [ "$n" -gt 0 ] && printf ' %s' "$n" || printf ' ' )"
