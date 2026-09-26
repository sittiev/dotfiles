#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
# Prompt minimalista: só onde estou (~ no home), sem user@host.
PS1='\w\$ '
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

# yabridge + Wine 11.18 (equalizacao de voz)
[ -f "$HOME/.config/audio-eq/env.sh" ] && . "$HOME/.config/audio-eq/env.sh"
