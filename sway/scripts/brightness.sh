#!/usr/bin/dash
# Brilho integrado: interno (eDP via brightnessctl) + externo (HDMI via DDC/CI).
# Fn keys chamam "up"/"down" e ajustam os dois juntos.
# O externo roda em background com flock para nao travar repeticao da tecla.
set -u

DEV="amdgpu_bl1"
EXT_SEL="--model T22B300"
STEP_INT="5%"
STEP_EXT=5
LOCK="/tmp/brightness-ddc.lock"

icon='
⠀⠀⠀⠀⠀⠀⠀⠀⢠⡄⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠠⣄⠀⠀⠸⠇⠀⠀⣠⠄⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⢁⣤⠶⠶⣤⡈⠁⠀⠀⠀⠀⠀
⠀⠀⠀⣤⣤⠀⣾⠁⠀⠀⠈⣷⠀⣤⣤⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠹⣦⣀⣀⣴⠏⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⡴⠂⠀⢉⡉⠀⠐⢦⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⠀
'

# Build a 12-cell bar from an integer percent (0–100)
build_bar() {
  local percent bar fill empty i
  percent="$1"
  bar=""
  fill="⠿"
  empty="⠀"

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

ext_adjust() { # $1 = + ou -
  (
    flock -n 9 || exit 0
    # shellcheck disable=SC2086
    ddcutil $EXT_SEL --sleep-multiplier 2.0 setvcp 10 "$1" "$STEP_EXT" >/dev/null 2>&1
  ) 9>"$LOCK" &
}

case "${1:-}" in
  show) ;; # só exibe o OSD, sem alterar o brilho
  up)
    brightnessctl -d "$DEV" set "$STEP_INT"+ >/dev/null 2>&1
    ext_adjust "+"
    ;;
  down)
    brightnessctl -d "$DEV" set "$STEP_INT"- >/dev/null 2>&1
    ext_adjust "-"
    ;;
  int-up)
    brightnessctl -d "$DEV" set "$STEP_INT"+ >/dev/null 2>&1
    ;;
  int-down)
    brightnessctl -d "$DEV" set "$STEP_INT"- >/dev/null 2>&1
    ;;
esac

cur=$(brightnessctl -d "$DEV" g 2>/dev/null || echo 0)
max=$(brightnessctl -d "$DEV" m 2>/dev/null || echo 1)
if [ "$max" -gt 0 ]; then
  bri_int=$(( (cur * 100 + max / 2) / max ))
else
  bri_int=0
fi

bar="$(build_bar "$bri_int")"

notify-send \
  --app-name="brightness-osd" \
  --expire-time=600 \
  --print-id \
  -h boolean:transient:true \
  -h string:x-canonical-private-synchronous:osd \
  "$icon$bar $bri_int%"
