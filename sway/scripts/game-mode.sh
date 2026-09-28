#!/usr/bin/dash
# game-mode.sh — modo jogo: menos wakeups, sem suspend/power-off, CPU em performance.
#
# Uso: game-mode.sh on|off|toggle|status
#   on  — salva o perfil do power-profiles-daemon, poe performance, DND no
#         mako, desliga wlsunset, swayidle (power-off aos 600s / suspend aos
#         900s), autotiling-rs e os watchers do cliphist.
#   off — restaura o perfil PPD, tira o DND e religa cliphist, swayidle e
#         autotiling-rs (mesmos comandos do exec_always do sway/config).
#
# O jogo em si lance com: gamemoderun <jogo>
# Atalho sugerido (sway/config): bindsym $mod+g exec ~/.config/sway/scripts/game-mode.sh toggle
#
# Swap: o on tenta `swapoff -a` e, se falhar (ex. RAM cheia), cai para
# `vm.swappiness=10`; o off desfaz. Ambos exigem root sem senha, liberado
# UMA vez pelo usuário com:
#   echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/swapoff -a, /usr/sbin/swapon -a, /usr/sbin/sysctl -w vm.swappiness=*, /usr/sbin/cpupower frequency-set -g *" \
#     | sudo tee /etc/sudoers.d/game-mode >/dev/null && sudo chmod 0440 /etc/sudoers.d/game-mode
# Sem isso o script segue sem tocar no swap. Feche o browser ANTES do on:
# com 3.5G swapados e 1G livre o swapoff falha por falta de RAM.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Dir próprio: ~/.cache/game-mode (arquivo) já existe e pertence a outra
# ferramenta — não colidir com ele.
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/sway-game-mode
active_file=$cache_dir/active
ppd_file=$cache_dir/ppd-profile
gov_file=$cache_dir/cpu-governor
swap_state_file=$cache_dir/swap-state
swap_sysctl_file=$cache_dir/swap-swappiness
wlsunset_file=$cache_dir/wlsunset-was-on
swayidle_file=$cache_dir/swayidle-was-on

notify() { notify-send "Modo jogo" "$1" 2>/dev/null || true; }

is_on() { [ -f "$active_file" ]; }

mode_on() {
    if is_on; then
        notify "já ativo"
        return 0
    fi
    mkdir -p "$cache_dir"

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl get > "$ppd_file" 2>/dev/null || true
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # PPD sozinho não troca o governor aqui (acpi-cpufreq segue ondemand):
    # força performance direto e salva para restaurar no off.
    if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] \
        && command -v sudo >/dev/null 2>&1; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > "$gov_file" 2>/dev/null || true
        if [ "$(cat "$gov_file" 2>/dev/null || printf '')" != performance ]; then
            sudo -n cpupower frequency-set -g performance >/dev/null 2>&1 || true
        fi
    fi

    # Swap: tenta desligar; sem RAM livre ou sem sudo cai para swappiness=10.
    # Estado em swap-state: off (swapoff ok) | low (só swappiness) | none.
    swap_state=none
    if [ "$(wc -l < /proc/swaps 2>/dev/null || printf '1')" -gt 1 ] \
        && command -v sudo >/dev/null 2>&1; then
        if sudo -n swapoff -a >/dev/null 2>&1; then
            swap_state=off
        else
            cat /proc/sys/vm/swappiness > "$swap_sysctl_file" 2>/dev/null || true
            if sudo -n sysctl -w vm.swappiness=10 >/dev/null 2>&1; then
                swap_state=low
            fi
        fi
    fi
    printf '%s\n' "$swap_state" > "$swap_state_file"

    if pgrep -x mako >/dev/null 2>&1; then
        makoctl mode -s do-not-disturb >/dev/null 2>&1 || true
    fi

    if pgrep -x wlsunset >/dev/null 2>&1; then
        printf '1\n' > "$wlsunset_file"
        pkill -x wlsunset >/dev/null 2>&1 || true
    else
        printf '0\n' > "$wlsunset_file"
    fi

    if pgrep -x swayidle >/dev/null 2>&1; then
        printf '1\n' > "$swayidle_file"
        pkill -x swayidle >/dev/null 2>&1 || true
    else
        printf '0\n' > "$swayidle_file"
    fi

    pkill -x autotiling-rs >/dev/null 2>&1 || true
    pkill -f '[w]l-paste --type text --watch cliphist store' >/dev/null 2>&1 || true
    pkill -f '[w]l-paste --type primary --watch cliphist store' >/dev/null 2>&1 || true

    printf 'on\n' > "$active_file"
    if [ "$swap_state" = off ]; then
        notify "ON — performance, swap off, sem idle/suspend, DND. Lance com gamemoderun."
    elif [ "$swap_state" = low ]; then
        notify "ON — performance, swappiness 10 (swapoff falhou: feche o browser antes)."
    else
        notify "ON — performance, sem idle/suspend, DND. Swap intocado (sem sudo? veja o cabeçalho)."
    fi
}

mode_off() {
    if ! is_on; then
        notify "já desligado"
        return 0
    fi

    if [ -f "$ppd_file" ] && command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$(cat "$ppd_file")" >/dev/null 2>&1 || true
    fi

    if [ -f "$gov_file" ] && command -v sudo >/dev/null 2>&1; then
        sudo -n cpupower frequency-set -g "$(cat "$gov_file")" >/dev/null 2>&1 || true
    fi

    # Desfaz o que o on fez no swap (mesmo estado salvo em swap-state).
    if command -v sudo >/dev/null 2>&1; then
        case "$(cat "$swap_state_file" 2>/dev/null || printf 'none')" in
            off) sudo -n swapon -a >/dev/null 2>&1 || true ;;
            low)
                if [ -f "$swap_sysctl_file" ]; then
                    sudo -n sysctl -w "vm.swappiness=$(cat "$swap_sysctl_file")" >/dev/null 2>&1 || true
                fi
                ;;
        esac
    fi

    if pgrep -x mako >/dev/null 2>&1; then
        makoctl mode -s default >/dev/null 2>&1 || true
    fi

    # Mesmos comandos do exec_always do sway/config.
    "$script_dir/cliphist-watch.sh" >/dev/null 2>&1 || true
    "$script_dir/idle.sh" >/dev/null 2>&1 &
    pkill -x autotiling-rs >/dev/null 2>&1 || true
    sleep 0.2
    autotiling-rs >/dev/null 2>&1 &

    if [ "$(cat "$wlsunset_file" 2>/dev/null || printf '0')" = 1 ]; then
        notify "OFF — perfil restaurado. Night-light estava ON: reative com Super+n."
    else
        notify "OFF — perfil restaurado."
    fi
    rm -f "$active_file"
}

mode_status() {
    if is_on; then
        printf 'game-mode: ON (ppd salvo=%s swap=%s)\n' "$(cat "$ppd_file" 2>/dev/null || printf '?')" \
            "$(cat "$swap_state_file" 2>/dev/null || printf '?')"
    else
        printf 'game-mode: OFF (ppd atual=%s swappiness=%s swaps=%s)\n' "$(powerprofilesctl get 2>/dev/null || printf '?')" \
            "$(cat /proc/sys/vm/swappiness 2>/dev/null || printf '?')" \
            "$(($(wc -l < /proc/swaps 2>/dev/null || printf '1') - 1))"
    fi
    printf 'swayidle=%s autotiling=%s cliphist=%s wlsunset=%s mako_mode=%s gov=%s\n' \
        "$(pgrep -x swayidle >/dev/null 2>&1 && printf on || printf off)" \
        "$(pgrep -x autotiling-rs >/dev/null 2>&1 && printf on || printf off)" \
        "$(pgrep -f '[w]l-paste.*cliphist store' >/dev/null 2>&1 && printf on || printf off)" \
        "$(pgrep -x wlsunset >/dev/null 2>&1 && printf on || printf off)" \
        "$(makoctl mode 2>/dev/null | tr '\n' ',' || printf '?')" \
        "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || printf '?')"
}

cmd=${1:-status}
case "$cmd" in
    on) mode_on ;;
    off) mode_off ;;
    toggle)
        if is_on; then
            mode_off
        else
            mode_on
        fi
        ;;
    status) mode_status ;;
    *) printf '%s\n' "uso: $0 on|off|toggle|status" >&2; exit 1 ;;
esac
