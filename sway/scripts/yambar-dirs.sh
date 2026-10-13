#!/usr/bin/dash
# Chip "directories" do yambar: rótulo fixo via tag (o módulo script exige
# transação de tags; poll de 1h é só heartbeat, custo zero). O clique
# dispara yambar-dirs-toggle.sh (on-click no render.sh) — nunca este script.
set -eu
printf 'display|string| directories\n\n'
