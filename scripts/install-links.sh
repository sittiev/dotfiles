#!/usr/bin/dash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DRY_RUN=${DRY_RUN:-0}
STAMP=$(date +%Y%m%d-%H%M%S)-$$
BACKUP_ROOT=${DOTFILES_BACKUP_ROOT:-$HOME/.local/state/dotfiles-backup/$STAMP}

link_path() {
    source=$1
    target=$2
    desired=$(readlink -f "$source" 2>/dev/null || printf '%s' "$source")

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$desired" ]; then
        printf '[keep] %s\n' "$target"
        return 0
    fi

    if [ "$DRY_RUN" = 1 ]; then
        printf '[dry]  %s -> %s\n' "$target" "$source"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$target")"
    if [ -e "$target" ] || [ -L "$target" ]; then
        relative=${target#"$HOME"/}
        backup=$BACKUP_ROOT/$relative
        mkdir -p -- "$(dirname -- "$backup")"
        mv -- "$target" "$backup"
        printf '[backup] %s -> %s\n' "$target" "$backup"
    fi
    ln -s -- "$source" "$target"
    printf '[link]  %s -> %s\n' "$target" "$source"
}

link_path "$ROOT/sway/config" "$HOME/.config/sway/config"
link_path "$ROOT/sway/scripts" "$HOME/.config/sway/scripts"
link_path "$ROOT/sway/schemes" "$HOME/.config/sway/schemes"
link_path "$ROOT/foot/foot.ini" "$HOME/.config/foot/foot.ini"
link_path "$ROOT/yambar/config.yml" "$HOME/.config/yambar/config.yml"
link_path "$ROOT/tofi/config" "$HOME/.config/tofi/config"
link_path "$ROOT/tofi/config-clipboard" "$HOME/.config/tofi/config-clipboard"
link_path "$ROOT/tofi/config-emoji" "$HOME/.config/tofi/config-emoji"
link_path "$ROOT/tofi/themes" "$HOME/.config/tofi/themes"
link_path "$ROOT/mako/config" "$HOME/.config/mako/config"
link_path "$ROOT/gtk/3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
link_path "$ROOT/gtk/4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
link_path "$ROOT/shell/.bashrc" "$HOME/.bashrc"
link_path "$ROOT/shell/.bash_profile" "$HOME/.bash_profile"
link_path "$ROOT/shell/environment.d/10-qt-theme.conf" "$HOME/.config/environment.d/10-qt-theme.conf"
link_path "$ROOT/apps/osu-lazer.desktop" "$HOME/.local/share/applications/osu-lazer.desktop"

if [ "$DRY_RUN" = 1 ]; then
    printf '%s\n' 'dry run complete; no files changed'
else
    printf 'backup root: %s\n' "$BACKUP_ROOT"
    printf '%s\n' 'links installed'
fi
