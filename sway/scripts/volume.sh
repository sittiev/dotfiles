#!/usr/bin/dash
# PipeWire volume controls with the Mako OSD from the rice backup.
set -eu

action=${1:-}
sink='@DEFAULT_AUDIO_SINK@'

get_vol_info() {
    raw=$(LC_ALL=C wpctl get-volume "$sink")
    vol=$(printf '%s' "$raw" | LC_ALL=C awk '{printf "%.0f", $2 * 100}')
    if printf '%s' "$raw" | grep -q 'MUTED'; then
        muted=1
    else
        muted=0
    fi
    printf '%s:%s' "$vol" "$muted"
}

build_bar() {
    percent=$1
    bar=''
    fill='⠿'
    empty='⠀'
    i=1
    while [ "$i" -le 12 ]; do
        if [ "$((i * 100))" -le "$((percent * 12))" ]; then
            bar="$bar$fill"
        else
            bar="$bar$empty"
        fi
        i=$((i + 1))
    done
    printf '%s' "$bar"
}

osd_notify() {
    info=$(get_vol_info)
    vol=${info%%:*}
    muted=${info##*:}
    if [ "$muted" -eq 1 ]; then
        notify-send --app-name=media-osd --expire-time=600 --print-id \
            -h boolean:transient:true \
            -h string:x-canonical-private-synchronous:osd \
            'Volume' 'Mudo' >/dev/null
    else
        notify-send --app-name=media-osd --expire-time=600 --print-id \
            -h boolean:transient:true \
            -h string:x-canonical-private-synchronous:osd \
            'Volume' "$(build_bar "$vol") $vol<b>%</b>" >/dev/null
    fi
}

case "$action" in
    up)
        wpctl set-volume -l 1.5 "$sink" 5%+
        osd_notify
        ;;
    down)
        wpctl set-volume "$sink" 5%-
        osd_notify
        ;;
    toggle)
        wpctl set-mute "$sink" toggle
        osd_notify
        ;;
    mic_toggle)
        wpctl set-mute '@DEFAULT_AUDIO_SOURCE@' toggle
        ;;
    show)
        info=$(get_vol_info)
        vol=${info%%:*}
        muted=${info##*:}
        if [ "$muted" -eq 1 ]; then
            notify-send --app-name=media-osd --expire-time=1500 \
                -h boolean:transient:true \
                -h string:x-canonical-private-synchronous:volume \
                'Volume' 'Mudo' >/dev/null
        else
            notify-send --app-name=media-osd --expire-time=1500 \
                -h boolean:transient:true \
                -h string:x-canonical-private-synchronous:volume \
                'Volume' "$vol<b>%</b>" >/dev/null
        fi
        ;;
    *) exit 1 ;;
esac
