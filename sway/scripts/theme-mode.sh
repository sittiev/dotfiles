#!/usr/bin/dash
# theme-mode.sh — determina light/dark pela paleta (luminância do wallpaper)
# e aplica nos apps nativos: GTK (gsettings + gtk.css + settings.ini),
# Qt/KDE (colorscheme Pywal + kdeglobals) e Discord (tema BetterDiscord que
# segue prefers-color-scheme automaticamente).
#   theme-mode.sh compute <wallpaper>   → imprime light|dark
#   theme-mode.sh apply   <light|dark>  → aplica usando ~/.cache/wal/colors
# Estado persistido em ~/.cache/theme-mode

set -u
LOG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/theme-mode.log"
STATE="$HOME/.cache/theme-mode"
MODE_LOCK="$HOME/.cache/theme-mode-lock"

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }

update_ini_value() {
    ini=$1
    key=$2
    value=$3
    temporary=$ini.tmp.$$
    sed "s|^${key}=.*|${key}=${value}|" "$ini" > "$temporary"
    cat "$temporary" > "$ini"
    rm -f "$temporary"
}

# pywal is optional until a wallpaper provider is configured. Keep a valid
# Apprentice-compatible seed so manual light/dark switching always works.
seed_wal_cache() {
    mkdir -p "$HOME/.cache/wal"
    cat > "$HOME/.cache/wal/colors.sh" <<'EOF'
background='#1c3143'
foreground='#c6cbd0'
color0='#758593'
color1='#8a9199'
color2='#7f92a1'
color3='#8e9da9'
color4='#97a5ae'
color5='#9ba0a6'
color6='#9ea0a2'
color7='#898e92'
color8='#9db2c4'
color9='#b9c2cc'
color10='#abc3d8'
color11='#bdd2e1'
color12='#cadde9'
color13='#d0d6de'
color14='#c8cacc'
color15='#c8cacc'
EOF
    {
        sed -n "s/^background='\(.*\)'$/\1/p" "$HOME/.cache/wal/colors.sh"
        for i in $(seq 0 15); do sed -n "s/^color$i='\(.*\)'$/\1/p" "$HOME/.cache/wal/colors.sh"; done
    } > "$HOME/.cache/wal/colors"
}

ensure_wal_cache() {
    if [ ! -f "$HOME/.cache/wal/colors.sh" ] || [ ! -f "$HOME/.cache/wal/colors" ]; then
        log "pywal cache absent; using Apprentice seed"
        seed_wal_cache
    fi
}

# PCManFM is GTK3, so LXQt/Qt QSS themes cannot be loaded by it. Qogir
# provides the requested GTK3 variants; Default is only a last-resort
# fallback.
gtk_theme_pick() {
    fallback=$1
    shift
    for candidate in "$@"; do
        for root in "$HOME/.themes" "$HOME/.local/share/themes" /usr/local/share/themes /usr/share/themes; do
            if [ -f "$root/$candidate/index.theme" ] || [ -f "$root/$candidate/gtk-3.0/index.theme" ]; then
                printf '%s' "$candidate"
                return 0
            fi
        done
    done
    printf '%s' "$fallback"
}

icon_theme_pick() {
    fallback=$1
    shift
    for candidate in "$@"; do
        for root in "$HOME/.icons" "$HOME/.local/share/icons" /usr/local/share/icons /usr/share/icons; do
            if [ -f "$root/$candidate/index.theme" ]; then
                printf '%s' "$candidate"
                return 0
            fi
        done
    done
    printf '%s' "$fallback"
}

palette_hex() { # <bg|N> → hex sem # via colors.sh (fonte única, imune a formato)
    # colors.sh referencia $FZF_DEFAULT_OPTS/${LS_COLORS} — desliga -u no source
    set +u
    # shellcheck disable=SC1091
    . "$HOME/.cache/wal/colors.sh" 2>/dev/null
    _ph_rc=$?
    set -u
    [ $_ph_rc -ne 0 ] && return 1
    # colors.sh define: background foreground color0..color15 (com #)
    case "$1" in
        bg) printf '%s' "${background#\#}" ;;
        fg) printf '%s' "${foreground#\#}" ;;
        *) eval "printf '%s' \"\${color$1#\#}\"" ;;
    esac
}

lum() { # <wallpaper> → luminância 0..1 (magick IM7, fallback convert IM6, fail-loud)
    if command -v magick >/dev/null 2>&1; then
        magick "$1" -resize 1x1! -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null && return 0
    fi
    if command -v convert >/dev/null 2>&1; then
        convert "$1" -resize 1x1! -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null && return 0
    fi
    echo "theme-mode.sh: nem magick nem convert disponíveis" >&2
    echo 0
}

compute() {
    local wall prev l lock
    wall="${1:-$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null)}"
    # lock manual sobrevive ao próximo wallpaper (toggle força modo)
    lock="$(cat "$MODE_LOCK" 2>/dev/null)"
    if [ "$lock" = light ] || [ "$lock" = dark ]; then echo "$lock"; return 0; fi
    prev="$(cat "$STATE" 2>/dev/null)"
    if [ "$prev" != light ] && [ "$prev" != dark ]; then prev="dark"; fi
    if [ ! -f "$wall" ]; then echo "$prev"; return 0; fi
    l="$(lum "$wall")"
    # faixa de histerese: [0.45, 0.55] mantém o modo atual (evita oscilação)
    if   awk -v l="$l" 'BEGIN{exit !(l >= 0.55)}'; then echo light
    elif awk -v l="$l" 'BEGIN{exit !(l <= 0.45)}'; then echo dark
    else echo "$prev"; fi
}

apply() {
    local mode="${1:-}"
    if [ "$mode" != light ] && [ "$mode" != dark ]; then mode="$(compute)"; fi
    ensure_wal_cache
    local walc="$HOME/.cache/wal/colors"
    if [ ! -f "$walc" ]; then
        log "sem paleta ($walc) — pulando"
        return 1
    fi

    local BACKGROUND FG C0 C1 C2 C3 C5 C8
    BACKGROUND="$(palette_hex bg)"
    FG="$(palette_hex 7)"
    C0="$(palette_hex 0)"; C1="$(palette_hex 1)"; C2="$(palette_hex 2)"
    C3="$(palette_hex 3)"; C5="$(palette_hex 5)"; C8="$(palette_hex 8)"

    # low-contrast estilo apprentice: dessatura o croma (LOWC_SAT% mantido).
    # BG/FG intactos (humor do wallpaper + leitura); chrome (acentos) muted.
    # theme.sh filtra igual em awk — mesma constante, mesmo resultado.
    export LOWC_SAT="${LOWC_SAT:-45}"

    # gera gtk colors.css, colorscheme KDE e tema Discord (cores derivadas da paleta)
    python3 - "$mode" "$BACKGROUND" "$FG" "$C0" "$C1" "$C2" "$C3" "$C5" "$C8" "$HOME" <<'PY'
import os, sys, shutil, configparser, re

mode, BG, FG, C0, C1, C2, C3, C5, C8, HOME = sys.argv[1:11]

def mix(a, b, w):
    a = [int(a[i:i+2], 16) for i in (0, 2, 4)]
    b = [int(b[i:i+2], 16) for i in (0, 2, 4)]
    return "".join("%02x" % round((1 - w) * x + w * y) for x, y in zip(a, b))

def rgb(h): return "%d,%d,%d" % tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def _lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

def _lum(h):
    c = [int(h[i:i+2], 16) for i in (0, 2, 4)]
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])

def _ratio(a, b):
    la, lb = _lum(a), _lum(b)
    hi, lo = (la, lb) if la > lb else (lb, la)
    return (hi + 0.05) / (lo + 0.05)

def ensure(fg, bg, minimum):
    extreme = "ffffff" if _lum(bg) < 0.35 else "000000"
    c = fg
    for _ in range(24):
        if _ratio(c, bg) >= minimum:
            break
        c = mix(c, extreme, 0.15)
    return c

def desat(h):
    k = int(os.environ.get("LOWC_SAT", "45")) / 100.0
    h = h.lstrip("#").lower()
    c = [int(h[i:i+2], 16) for i in (0, 2, 4)]
    g = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    return "".join("%02x" % round(g + (x - g) * k) for x in c)

C0, C1, C2, C3, C5, C8 = (desat(c) for c in (C0, C1, C2, C3, C5, C8))

# ---- paleta por modo (ambas sempre calculadas; toggle nunca usa stub) ----
def _dark_pal():
    _bg = BG.lstrip("#").lower()
    _fg = FG.lstrip("#").lower()
    return {"bg": _bg, "fg": _fg, "base": C0.lstrip("#").lower(),
            "accent": C5.lstrip("#").lower(), "muted": C8.lstrip("#").lower(),
            "border": mix(_bg, _fg, 0.25), "fail": C1.lstrip("#").lower()}

def _light_pal():
    _w = mix(BG.lstrip("#"), "ffffff", 0.80)
    _f = mix(FG.lstrip("#"), "000000", 0.72)
    # base (campo) MAIS CLARA que window — convenção light, corrige inversão
    _b = mix(_w, "ffffff", 0.55)
    _a = mix(C5.lstrip("#"), "000000", 0.15)
    _m = mix(FG.lstrip("#"), "000000", 0.55)
    _bo = mix(_w, "ffffff", 0.45)
    return {"bg": _w, "fg": _f, "base": _b, "accent": _a, "muted": _m,
            "border": _bo, "fail": C1.lstrip("#").lower()}

_dark = _dark_pal()
_light = _light_pal()
for _p in (_dark, _light):
    _p["fg"] = ensure(_p["fg"], _p["bg"], 4.5)
    _p["muted"] = ensure(_p["muted"], _p["bg"], 3.0)
    if _ratio(_p["fg"], _p["muted"]) < 1.8:
        _p["muted"] = mix(_p["muted"], _p["bg"], 0.35)

P = _dark if mode == "dark" else _light
bg, fg, base, accent, muted, border = P["bg"], P["fg"], P["base"], P["accent"], P["muted"], P["border"]
C1 = P["fail"]

# ---- GTK colors.css (paleta; backup da versao anterior) ----
# theme_base_color = base (campo) — corrige contraste light (base mais clara que window).
# Inclui tokens libadwaita/GTK4 no mesmo arquivo (window/view/accent/headerbar/card).
gtk_css = """/* colors.css — gerado por theme-mode.sh (pywal) — nao editar */
@define-color theme_bg_color %(bg)s;
@define-color theme_fg_color %(fg)s;
@define-color theme_base_color %(base)s;
@define-color theme_text_color %(fg)s;
@define-color theme_selected_bg_color %(accent)s;
@define-color theme_selected_fg_color %(bg)s;
@define-color theme_unfocused_bg_color %(bg)s;
@define-color theme_unfocused_fg_color %(fg)s;
@define-color borders %(border)s;
@define-color insensitive_bg_color %(border)s;
@define-color insensitive_fg_color %(muted)s;
@define-color error_color #da4453;
@define-color warning_color #f67400;
@define-color success_color #27ae60;
@define-color link_color %(accent)s;
@define-color tooltip_bg_color %(bg)s;
@define-color tooltip_fg_color %(fg)s;
@define-color window_bg_color %(bg)s;
@define-color window_fg_color %(fg)s;
@define-color view_bg_color %(base)s;
@define-color view_fg_color %(fg)s;
@define-color accent_bg_color %(accent)s;
@define-color accent_fg_color %(bg)s;
@define-color accent_color %(accent)s;
@define-color headerbar_bg_color %(bg)s;
@define-color headerbar_fg_color %(fg)s;
@define-color card_bg_color %(base)s;
@define-color card_fg_color %(fg)s;
@define-color sidebar_bg_color %(bg)s;
@define-color sidebar_fg_color %(fg)s;
""" % {"bg": "#" + bg, "fg": "#" + fg, "base": "#" + base, "accent": "#" + accent,
       "border": "#" + border, "muted": "#" + muted}

for ver in ("3.0", "4.0"):
    d = os.path.join(HOME, ".config/gtk-%s" % ver)
    os.makedirs(d, exist_ok=True)
    css = os.path.join(d, "colors.css")
    if os.path.isfile(css) and not os.path.isfile(css + ".bak"):
        shutil.copyfile(css, css + ".bak")
    with open(css, "w") as f:
        f.write(gtk_css)

# ---- user gtk.css: recolor explicito -------------------------------------
# O Qogir grava hex fixo em todas as regras (.background, headerbar, entry,
# .view, button...) e nunca referencia os proprios @define-color, entao so
# definir cores nao recolore nada. O user gtk.css carrega DEPOIS do tema,
# logo regras empatadas em especificidade vencem por ordem de carga.
# Cores literais (sem @import) para o arquivo ser autocontido.
accent_fg = ensure("000000", accent, 4.5)
C = {"bg": "#" + bg, "fg": "#" + fg, "base": "#" + base,
     "accent": "#" + accent, "accent_fg": "#" + accent_fg,
     "border": "#" + border, "muted": "#" + muted,
     "btn": "#" + mix(bg, fg, 0.08),
     "btn_hover": "#" + mix(bg, fg, 0.18),
     "btn_active": "#" + mix(bg, fg, 0.30),
     "sb": "#" + mix(bg, fg, 0.40),
     "sb_hover": "#" + mix(bg, fg, 0.55)}

wal_gtk_block = """/* wal-gtk-begin — gerado por theme-mode.sh (pywal) — nao editar */

/* janela e chrome */
window,
.background,
.gtkstyle-fallback {
  background-color: %(bg)s;
  color: %(fg)s;
}

headerbar,
.maximized headerbar,
headerbar:backdrop,
headerbar.default-decoration {
  background-color: %(base)s;
  color: %(fg)s;
}

menubar,
statusbar,
toolbar,
.primary-toolbar,
notebook > header {
  background-color: %(bg)s;
  color: %(fg)s;
}

/* menus, popovers e tooltips */
menu,
.menu,
.context-menu,
popover.background,
popover.background.menu,
tooltip,
tooltip.background {
  background-color: %(bg)s;
  color: %(fg)s;
}

/* campos de texto e views (base, igual ao headerbar) */
.view,
.iconview,
textview,
textview > text,
textview text,
treeview.view,
treeview entry,
treeview entry.flat,
window.thunar notebook scrolledwindow.frame.standard-view .view:not(.rubberband) {
  background-color: %(base)s;
  color: %(fg)s;
}

entry,
.entry,
entry:focus,
spinbutton,
spinbutton:focus,
combobox entry,
treeview entry:focus {
  background-color: %(base)s;
  color: %(fg)s;
  border-color: %(border)s;
}

/* botoes */
button {
  background-color: %(btn)s;
  color: %(fg)s;
  border-color: %(border)s;
}
button:hover {
  background-color: %(btn_hover)s;
}
button:active {
  background-color: %(btn_active)s;
}
button:checked,
button.selected,
check:checked,
radio:checked,
progressbar progress,
levelbar block,
scale highlight,
switch:checked {
  background-color: %(accent)s;
  color: %(accent_fg)s;
}

/* selecao */
*:selected,
selection,
text selection,
label selection,
entry selection,
.view selection,
treeview.view:selected,
treeview.view:selected:focus,
row:selected,
row.activatable:selected,
calendar:selected,
modelbutton.flat:selected {
  background-color: %(accent)s;
  color: %(accent_fg)s;
}

/* separadores e setas de menu (antes #32343d do tema) */
menu separator,
.menu separator,
.context-menu separator,
popover.background.touch-selection separator,
.csd .context-menu separator,
menu > arrow,
.menu > arrow,
.context-menu > arrow {
  background-color: %(border)s;
}

/* hover/selecao de menus (antes #5294e2 do tema) */
menubar > menuitem:hover,
.menubar > menuitem:hover,
menubar > menuitem:selected,
.menubar > menuitem:selected,
menu menuitem:hover,
.menu menuitem:hover,
.context-menu menuitem:hover,
popover.background.touch-selection menuitem:hover {
  background-color: %(accent)s;
  color: %(accent_fg)s;
  border-color: %(accent)s;
}

/* scrollbar (antes cinza-azulado do tema) */
scrollbar slider {
  background-color: %(sb)s;
}
scrollbar slider:hover {
  background-color: %(sb_hover)s;
}
scrollbar slider:hover:active {
  background-color: %(accent)s;
}

/* wal-gtk-end */
""" % C

for ver in ("3.0", "4.0"):
    path = os.path.join(HOME, ".config/gtk-%s" % ver, "gtk.css")
    with open(path, "w") as f:
        f.write("/* gtk.css — gerado por theme-mode.sh (pywal) — nao editar */\n"
                + wal_gtk_block)

# ---- colorscheme KDE (PywalLight/PywalDark) ----
scheme_name = "Pywal" + ("Dark" if mode == "dark" else "Light")
base_file = "/usr/share/color-schemes/%s.colors" % ("BreezeDark" if mode == "dark" else "BreezeLight")
scheme_dir = os.path.join(HOME, ".local/share/color-schemes")
os.makedirs(scheme_dir, exist_ok=True)
out_file = os.path.join(scheme_dir, scheme_name + ".colors")

cfg = configparser.RawConfigParser()
cfg.optionxform = str
cfg.read(base_file)

# seções padrao (Breeze)
updates = {
    "Colors:Window":      {"BackgroundNormal": bg, "BackgroundAlternate": base,
                           "ForegroundNormal": fg, "DecorationFocus": accent, "DecorationHover": accent},
    "Colors:View":        {"BackgroundNormal": base, "ForegroundNormal": fg, "DecorationFocus": accent},
    "Colors:Button":      {"BackgroundNormal": base, "ForegroundNormal": fg,
                           "DecorationFocus": accent, "DecorationHover": accent},
    "Colors:Selection":   {"BackgroundNormal": accent, "ForegroundNormal": bg, "DecorationFocus": accent},
    "Colors:Tooltip":     {"BackgroundNormal": bg, "ForegroundNormal": fg},
    "Colors:Complementary": {"BackgroundNormal": bg, "ForegroundNormal": fg},
}
for sec, pairs in updates.items():
    if not cfg.has_section(sec):
        continue
    for k, v in pairs.items():
        if cfg.has_option(sec, k):
            cfg.set(sec, k, rgb(v))

# Colors:Header — barra de titulo de apps KDE (Dolphin, Kate, etc.)
header_inactive_bg = mix(bg, fg, 0.06)
header_inactive_fg = mix(fg, bg, 0.18)
header_data = {
    "BackgroundNormal": mix(bg, fg, 0.04), "BackgroundAlternate": bg,
    "ForegroundNormal": fg, "ForegroundActive": accent, "ForegroundInactive": header_inactive_fg,
    "ForegroundLink": accent, "ForegroundNegative": "da4453",
    "ForegroundNeutral": "f67400", "ForegroundPositive": "27ae60",
    "DecorationFocus": accent, "DecorationHover": accent,
}
header_inactive_data = {
    "BackgroundNormal": header_inactive_bg, "BackgroundAlternate": bg,
    "ForegroundNormal": fg, "ForegroundActive": accent,
    "ForegroundInactive": header_inactive_fg,
    "DecorationFocus": accent, "DecorationHover": accent,
}
for sec, data in [("Colors:Header", header_data), ("Colors:Header][Inactive", header_inactive_data)]:
    if not cfg.has_section(sec):
        cfg.add_section(sec)
    for k, v in data.items():
        cfg.set(sec, k, rgb(v))

# WM — cores da barra de titulo sway (via cfg, nao via kwriteconfig — garante consistencia)
wm_data = {
    "activeBackground": mix(bg, fg, 0.04), "activeBlend": mix(bg, fg, 0.04),
    "activeForeground": fg,
    "inactiveBackground": header_inactive_bg, "inactiveBlend": header_inactive_bg,
    "inactiveForeground": header_inactive_fg,
}
if not cfg.has_section("WM"):
    cfg.add_section("WM")
for k, v in wm_data.items():
    cfg.set("WM", k, rgb(v))

if cfg.has_section("General"):
    cfg.set("General", "Name", scheme_name)
    cfg.set("General", "ColorScheme", scheme_name)
with open(out_file, "w") as f:
    cfg.write(f)

# ---- Kvantum PywalDark/Light (kvconfig + svg completos, pywal low-contrast) ----
# Base dark: Ant-Dark (moderno, usuário atual). Base light: KvFlatLight (flat, fácil de recolorir).
# Gera ~/.config/Kvantum/PywalDark|Light/ e aponta kvantum.kvconfig para eles.
def _hex_alpha(orig, new_hex):
    o = (orig or "").strip()
    if len(o) == 9 and o.startswith("#"):
        return "#" + new_hex + o[7:9].lower()
    if len(o) == 7 and o.startswith("#"):
        return "#" + new_hex
    return "#" + new_hex

def _patch_kvantum(theme, base_kv, base_svg, cmap):
    import configparser
    out_dir = os.path.join(HOME, ".config/Kvantum", theme)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except Exception:
        return
    # --- kvconfig --- (strict=False: Ant-Dark tem 'interior' duplicado em [StatusBar])
    if os.path.isfile(base_kv):
        kc = configparser.RawConfigParser(strict=False)
        kc.optionxform = str
        try:
            kc.read(base_kv, encoding="utf-8")
        except Exception:
            return
        if kc.has_section("GeneralColors"):
            def _set(k, new_hex):
                if kc.has_option("GeneralColors", k):
                    try:
                        orig = kc.get("GeneralColors", k)
                    except Exception:
                        orig = ""
                    kc.set("GeneralColors", k, _hex_alpha(orig, new_hex))
            _set("window.color", cmap["bg"])
            _set("base.color", cmap["base"])
            _set("alt.base.color", mix(cmap["base"], cmap["fg"], 0.10))
            _set("button.color", cmap["base"])
            _set("light.color", cmap["base"])
            _set("mid.light.color", mix(cmap["base"], cmap["fg"], 0.15))
            _set("dark.color", mix(cmap["bg"], "000000", 0.30))
            _set("mid.color", mix(cmap["bg"], cmap["fg"], 0.20))
            _set("highlight.color", cmap["accent"])
            _set("inactive.highlight.color", cmap["accent"])
            _set("text.color", cmap["fg"])
            _set("window.text.color", cmap["fg"])
            _set("button.text.color", cmap["fg"])
            _set("tooltip.text.color", cmap["fg"])
            _set("highlight.text.color", cmap["bg"])
            _set("disabled.text.color", cmap["muted"])
            _set("link.color", cmap["accent"])
            _set("link.visited.color", cmap["muted"])
        # renomeia General>Name se existir
        for sec in ("General", "%General"):
            if kc.has_section(sec) and kc.has_option(sec, "comment"):
                try:
                    kc.set(sec, "comment", "Pywal %s (gerado por theme-mode.sh) — base %s" % (theme, os.path.basename(base_kv)))
                except Exception:
                    pass
        try:
            with open(os.path.join(out_dir, theme + ".kvconfig"), "w") as f:
                kc.write(f)
        except Exception:
            pass
    # --- svg ---
    if os.path.isfile(base_svg):
        try:
            with open(base_svg, "r", encoding="utf-8", errors="ignore") as f:
                svg = f.read()
        except Exception:
            return
        for old, new in cmap["svg_map"]:
            try:
                svg = re.sub(re.escape(old), "#" + new, svg, flags=re.IGNORECASE)
            except Exception:
                pass
        try:
            with open(os.path.join(out_dir, theme + ".svg"), "w", encoding="utf-8") as f:
                f.write(svg)
        except Exception:
            pass

try:
    # ambas as paletas já calculadas (_dark/_light) — sem stub, sem estado velho
    _dark_map = [
        ("#192124", _dark["bg"]), ("#101618", mix(_dark["bg"], "000000", 0.35)),
        ("#1e282c", mix(_dark["bg"], "000000", 0.25)), ("#1d2133", mix(_dark["bg"], "000000", 0.20)),
        ("#9bbfbf", _dark["accent"]),
        ("#c3c7d1", _dark["fg"]), ("#dadadc", _dark["fg"]), ("#d2d2d4", _dark["fg"]), ("#c8c8ca", _dark["fg"]),
        ("#aaaaac", _dark["muted"]), ("#bdc3c7", _dark["muted"]),
        ("#324349", mix(_dark["bg"], _dark["fg"], 0.25)), ("#323b3f", mix(_dark["bg"], _dark["fg"], 0.20)),
    ]
    _light_map = [
        ("#fcfcfc", _light["bg"]), ("#eaeaeb", _light["base"]), ("#f0f0f0", _light["base"]),
        ("#e1dcd7", mix(_light["base"], _light["fg"], 0.10)), ("#f3f3f3", _light["base"]), ("#ececec", _light["base"]),
        ("#2d82ad", _light["accent"]), ("#3daee9", _light["accent"]), ("#39ace9", _light["accent"]),
        ("#0057ae", _light["accent"]),
    ]
    _home_ant_kv = os.path.join(HOME, ".config/Kvantum/Ant-Dark/Ant-Dark.kvconfig")
    _home_ant_svg = os.path.join(HOME, ".config/Kvantum/Ant-Dark/Ant-Dark.svg")
    _flat_light_kv = "/usr/share/Kvantum/KvFlatLight/KvFlatLight.kvconfig"
    _flat_light_svg = "/usr/share/Kvantum/KvFlatLight/KvFlatLight.svg"
    _patch_kvantum("PywalDark", _home_ant_kv, _home_ant_svg,
        {"bg": _dark["bg"], "base": _dark["base"], "fg": _dark["fg"],
         "accent": _dark["accent"], "muted": _dark["muted"], "svg_map": _dark_map})
    _patch_kvantum("PywalLight", _flat_light_kv, _flat_light_svg,
        {"bg": _light["bg"], "base": _light["base"], "fg": _light["fg"],
         "accent": _light["accent"], "muted": _light["muted"], "svg_map": _light_map})
except Exception:
    pass

kvantum_cfg = os.path.join(HOME, ".config/Kvantum/kvantum.kvconfig")
kv_theme = "PywalDark" if mode == "dark" else "PywalLight"
if os.path.isfile(kvantum_cfg):
    with open(kvantum_cfg, "w") as f:
        f.write("[General]\ntheme=%s\n" % kv_theme)

# Sincroniza WM no kdeglobals (kwriteconfig so muda ColorScheme, nao as cores reais)
kdeg = os.path.join(HOME, ".config/kdeglobals")
if os.path.isfile(kdeg):
    with open(kdeg) as f:
        lines = f.readlines()
    out, in_wm = [], False
    for line in lines:
        if line.strip() == "[WM]":
            in_wm = True
            out.append(line)
            continue
        if in_wm and line.startswith("["):
            in_wm = False
        if in_wm and "=" in line:
            key = line.split("=", 1)[0]
            if key in wm_data:
                out.append("%s=%s\n" % (key, rgb(wm_data[key])))
                continue
        out.append(line)
    with open(kdeg, "w") as f:
        f.writelines(out)

# ---- Discord (tema BetterDiscord; segue prefers-color-scheme) ----
def discord_vars(p):
    bg, base, fg, accent, muted = p["bg"], p["base"], p["fg"], p["accent"], p["muted"]
    return {
        "background-primary": bg,
        "background-secondary": base,
        "background-secondary-alt": mix(base, fg, 0.12),
        "background-tertiary": mix(base, fg, 0.20),
        "background-floating": mix(base, fg, 0.06),
        "background-accent": mix(accent, bg, 0.60),
        "background-modifier-hover": mix(bg, fg, 0.07),
        "background-modifier-active": mix(bg, fg, 0.13),
        "background-modifier-selected": mix(bg, fg, 0.15),
        "background-modifier-accent": mix(accent, bg, 0.65),
        "channeltextarea-background": mix(base, fg, 0.08),
        "text-normal": fg,
        "text-muted": muted,
        "text-link": mix(accent, fg, 0.25),
        "header-primary": fg,
        "header-secondary": muted,
        "interactive-normal": mix(fg, bg, 0.25),
        "interactive-hover": fg,
        "interactive-active": accent,
        "interactive-muted": muted,
        "brand-experiment": accent,
        "brand-500": accent,
        "button-secondary-background": base,
        "button-secondary-background-hover": mix(base, fg, 0.12),
        "scrollbar-auto-thumb": mix(base, fg, 0.28),
        "scrollbar-thin-thumb": mix(base, fg, 0.28),
        "status-danger": "da4453",
        "status-positive": "27ae60",
        "status-warning": "f67400",
    }

def discord_css(vars_):
    lines = ["  --%s: #%s;" % (k, v) for k, v in vars_.items()]
    return ":root {\n" + "\n".join(lines) + "\n}"

disc = discord_vars({"bg": bg, "base": base, "fg": fg, "accent": accent, "muted": muted})
disc_light = discord_vars({"bg": _light["bg"], "base": _light["base"], "fg": _light["fg"],
                           "accent": _light["accent"], "muted": _light["muted"]})
css = ("/* pywal — Discord theme — gerado por theme-mode.sh — nao editar\n"
       "   Ative uma vez no BetterDiscord (Themes > pywal). Depois disso ele\n"
       "   segue o prefers-color-scheme do sistema sozinho. */\n" +
       discord_css(disc) + "\n@media (prefers-color-scheme: light) {\n" +
       discord_css(disc_light) + "}\n")

cache_disc = os.path.join(HOME, ".cache/wal/discord-pywal.theme.css")
with open(cache_disc, "w") as f:
    f.write(css)
bd_dir = os.path.join(HOME, ".config/BetterDiscord/themes")
os.makedirs(bd_dir, exist_ok=True)
with open(os.path.join(bd_dir, "pywal.theme.css"), "w") as f:
    f.write(css)

# mako tem dono único: render.sh/theme.sh (bloco removido — era no-op sem marcadores).
# ---- paletas persistidas (atual + dark + light; inclui BASE p/ campos) ----
pal_file = os.path.join(HOME, ".cache/theme-palette")
def _write_pal(path, p):
    with open(path, "w") as f:
        f.write("BG=%s\nFG=%s\nBASE=%s\nACCENT=%s\nMUTED=%s\nBORDER=%s\nFAIL=%s\n" % (
            p["bg"], p["fg"], p["base"], p["accent"], p["muted"], p["border"], p["fail"]))
_write_pal(pal_file, P)
_write_pal(os.path.join(HOME, ".cache/theme-palette.dark"), _dark)
_write_pal(os.path.join(HOME, ".cache/theme-palette.light"), _light)
PY

    # ---- mako (recarrega com o theme.conf recém-gerado) ----
    if pgrep -x mako >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || true
    else
        mako >/dev/null 2>&1 &
    fi

    # ---- GTK: preferência (gsettings + settings.ini + GTK2 + xsettingsd) ----
    # PCManFM 1.4 usa GTK3; Qogir fornece as variantes GTK3.
    # Default é somente o fallback caso o tema local não esteja disponível.
    if [ "$mode" = dark ]; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        GTK_THEME="$(gtk_theme_pick Default Qogir-Dark)"
        ICON_THEME="$(icon_theme_pick Papirus-Dark yet-another-monochrome-icon-set)"
        GTK_PREFER="true"
    else
        gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
        GTK_THEME="$(gtk_theme_pick Default Qogir-Light)"
        ICON_THEME="$(icon_theme_pick Papirus-Light yet-another-monochrome-icon-set)"
        GTK_PREFER="false"
    fi

    # YAMIS recolorido pela paleta (cópia gerada em ~/.local/share/icons/yamis-wal;
    # o tema base fica intocado). Quando o recolorimento é possível, ele tem
    # prioridade sobre o fallback Papirus.
    ICON_WAL="$("$HOME/.config/sway/scripts/icon-recolor.sh" 2>/dev/null || true)"
    if [ -n "$ICON_WAL" ]; then
        ICON_THEME="$ICON_WAL"
    fi

    # YAMIS is a native monochrome icon theme; Papirus remains the fallback.
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    for v in 3.0 4.0; do
        local gtk_dir="$HOME/.config/gtk-$v"
        local ini="$gtk_dir/settings.ini"
        mkdir -p "$gtk_dir"
        if [ ! -f "$ini" ]; then
            cat > "$ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-application-prefer-dark-theme=$GTK_PREFER
EOF
        else
            grep -q '^\[Settings\]' "$ini" || printf '\n[Settings]\n' >> "$ini"
            if grep -q '^gtk-theme-name=' "$ini"; then
                update_ini_value "$ini" gtk-theme-name "$GTK_THEME"
            else
                printf 'gtk-theme-name=%s\n' "$GTK_THEME" >> "$ini"
            fi
            if grep -q '^gtk-icon-theme-name=' "$ini"; then
                update_ini_value "$ini" gtk-icon-theme-name "$ICON_THEME"
            else
                printf 'gtk-icon-theme-name=%s\n' "$ICON_THEME" >> "$ini"
            fi
            if grep -q '^gtk-application-prefer-dark-theme=' "$ini"; then
                update_ini_value "$ini" gtk-application-prefer-dark-theme "$GTK_PREFER"
            else
                printf 'gtk-application-prefer-dark-theme=%s\n' "$GTK_PREFER" >> "$ini"
            fi
        fi
    done
    # GTK2: nome do tema + icon theme + color-scheme pywal (apps legados).
    # shellcheck disable=SC1091
    . "$HOME/.cache/theme-palette" 2>/dev/null || true
    if [ -n "${BG:-}" ]; then
        [ -f "$HOME/.gtkrc-2.0" ] || : > "$HOME/.gtkrc-2.0"
        for g2 in "$HOME/.gtkrc-2.0" "$HOME/.config/gtkrc-2.0"; do
            [ -f "$g2" ] || continue
            # escrito via tmp + `cat tmp > alvo` (symlink-safe; sem mv/sed -i)
            tmp="$g2.tmp.$$"
            awk -v theme="gtk-theme-name=\"$GTK_THEME\"" \
                -v icons="gtk-icon-theme-name=\"$ICON_THEME\"" '
                /^# wal-theme-begin/,/^# wal-theme-end/ { next }
                /^gtk-theme-name=/ { if (!t++) print theme; next }
                /^gtk-icon-theme-name=/ { if (!i++) print icons; next }
                { print }
                END { if (!t) print theme; if (!i) print icons }
            ' "$g2" > "$tmp"
            {
                printf '%s\n' '# wal-theme-begin (gerado por theme-mode.sh — nao editar este bloco)'
                printf 'gtk-color-scheme = "base_color:#%s\\ntext_color:#%s\\nselected_bg_color:#%s\\nselected_fg_color:#%s\\ntooltip_bg_color:#%s\\ntooltip_fg_color:#%s"\n' \
                    "$BG" "$FG" "$ACCENT" "$BG" "$BG" "$FG"
                printf '%s\n' '# wal-theme-end'
            } >> "$tmp"
            cat "$tmp" > "$g2"
            rm -f "$tmp"
        done
    fi
    # xsettingsd: temas GTK/ícones ao vivo para XWayland/electron.
    XS="$HOME/.config/xsettingsd/xsettingsd.conf"
    if [ -f "$XS" ]; then
        sed -i "s|^Net/ThemeName .*|Net/ThemeName \"$GTK_THEME\"|" "$XS"
        sed -i "s|^Net/IconThemeName .*|Net/IconThemeName \"$ICON_THEME\"|" "$XS"
        pkill -HUP xsettingsd 2>/dev/null || true
    fi

    # ---- Qt/KDE: colorscheme e YAMIS ativos (best effort) ----
    local scheme_name="PywalDark"
    [ "$mode" = light ] && scheme_name="PywalLight"
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$scheme_name" 2>/dev/null || true
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME" 2>/dev/null || true
    sed -i '/^ColorSchemeHash=/d' "$HOME/.config/kdeglobals" 2>/dev/null || true
    qdbus6 org.kde.KGlobalSettings /KGlobalSettings notifyChange 2 0 >/dev/null 2>&1 || true
    qdbus6 org.kde.KGlobalSettings /KGlobalSettings notifyChange 6 0 >/dev/null 2>&1 || true

    # Kvantum: recarrega tema (Ant-Dark / KvFlatLight) via dbus — apps Qt pegam na hora
    if command -v dbus-send >/dev/null 2>&1; then
        dbus-send --session --type=method_call --dest=org.kde.Kvantum \
            /org/kde/Kvantum org.kde.Kvantum.reloadConfig 2>/dev/null || true
    fi

    echo "$mode" > "$STATE"
    log "aplicado: $mode (GTK/KDE/Discord)"
    # superfícies geradas: dono único render.sh (1x restart/reload — sem duplicar)
    "$HOME/.config/sway/scripts/render.sh" "$mode" || true
}

case "${1:-}" in
    compute) compute "${2:-}" ;;
    apply)   apply "${2:-}" ;;
    *)       echo "uso: theme-mode.sh compute <wallpaper> | apply <light|dark>" >&2; exit 1 ;;
esac
