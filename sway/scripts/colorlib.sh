#!/usr/bin/dash
# colorlib.sh — matematica de cor compartilhada (theme.sh + theme-mode.sh).
# Uma fonte da verdade: dessaturacao apprentice, mistura, contraste WCAG
# com luminancia gamma-corrigida, hex<->rgb. POSIX dash + awk (mawk-safe:
# sem strtonum, sem ** — usa exp/log e index()).
#   . "$HOME/.config/sway/scripts/colorlib.sh"

# LOWC_SAT = % de croma mantido (45 = apprentice legado; 100 = pywal puro).
# Novo: apprentice_clamp() abaixo é o mapeamento preferido (HSL, hue preservado).
LOWC_SAT="${LOWC_SAT:-45}"

# rgb2hsl_hex <rrggbb> → "H S L" (H 0-360, S/L 0-100). awk puro, mawk-safe.
rgb2hsl_hex() {
    LC_ALL=C printf '%s' "$1" | LC_ALL=C awk '{
        h = tolower($0)
        r = hd(substr(h, 1, 2)) / 255; g = hd(substr(h, 3, 2)) / 255; b = hd(substr(h, 5, 2)) / 255
        mx = r; if (g > mx) mx = g; if (b > mx) mx = b
        mn = r; if (g < mn) mn = g; if (b < mn) mn = b
        l = (mx + mn) / 2
        d = mx - mn
        if (d == 0) { s = 0; hue = 0 }
        else {
            if (l < 0.5) s = d / (mx + mn); else s = d / (2 - mx - mn)
            if (mx == r) hue = 60 * ((g - b) / d)
            else if (mx == g) hue = 60 * ((b - r) / d) + 120
            else hue = 60 * ((r - g) / d) + 240
            if (hue < 0) hue += 360
        }
        printf "%.2f %.2f %.2f", hue, s * 100, l * 100
    }
    function hd(s,   v, i, d) { v = 0; for (i = 1; i <= length(s); i++) { d = index("0123456789abcdef", substr(s, i, 1)) - 1; v = v * 16 + d }; return v }'
}

# hsl2rgb_hex <H 0-360> <S 0-100> <L 0-100> → rrggbb. Algoritmo padrão C-X-m.
hsl2rgb_hex() {
    LC_ALL=C awk -v h="$1" -v s="$2" -v l="$3" 'BEGIN{
        s /= 100; l /= 100
        # normaliza H
        while (h < 0) h += 360
        while (h >= 360) h -= 360
        d = (2 * l - 1); if (d < 0) d = -d
        c = (1 - d) * s
        hm = h / 60
        # (hm mod 2): parte fracionária segura em mawk
        m2 = hm - int(hm / 2) * 2
        t = m2 - 1; if (t < 0) t = -t
        x = c * (1 - t)
        m = l - c / 2
        sec = int(hm) % 6
        if (sec == 0) { rp = c; gp = x; bp = 0 }
        else if (sec == 1) { rp = x; gp = c; bp = 0 }
        else if (sec == 2) { rp = 0; gp = c; bp = x }
        else if (sec == 3) { rp = 0; gp = x; bp = c }
        else if (sec == 4) { rp = x; gp = 0; bp = c }
        else { rp = c; gp = 0; bp = x }
        r = int((rp + m) * 255 + 0.5); g = int((gp + m) * 255 + 0.5); b = int((bp + m) * 255 + 0.5)
        if (r < 0) r = 0; if (r > 255) r = 255
        if (g < 0) g = 0; if (g > 255) g = 255
        if (b < 0) b = 0; if (b > 255) b = 255
        printf "%02x%02x%02x", r, g, b
    }'
}

# apprentice_clamp <rrggbb> <s_min> <s_max> <l_min> <l_max> → rrggbb
# Preserva hue do wallpaper, prende S/L no envelope Apprentice.
apprentice_clamp() {
    _ac_hex="$1"; _ac_smin="$2"; _ac_smax="$3"; _ac_lmin="$4"; _ac_lmax="$5"
    _ac_hsl="$(rgb2hsl_hex "$_ac_hex")"
    _ac_h="${_ac_hsl%% *}"; _ac_rest="${_ac_hsl#* }"
    _ac_s="${_ac_rest%% *}"; _ac_l="${_ac_rest#* }"
    _ac_s="$(LC_ALL=C awk -v s="$_ac_s" -v mn="$_ac_smin" -v mx="$_ac_smax" 'BEGIN{v=s+0; if(v<mn)v=mn; if(v>mx)v=mx; print v}')"
    _ac_l="$(LC_ALL=C awk -v l="$_ac_l" -v mn="$_ac_lmin" -v mx="$_ac_lmax" 'BEGIN{v=l+0; if(v<mn)v=mn; if(v>mx)v=mx; print v}')"
    hsl2rgb_hex "$_ac_h" "$_ac_s" "$_ac_l"
}

# Envelopes Apprentice por role (dark). Light espelha L em torno de 50%.
#   BG/FG:     S 0-8   (quase acromático, como #262626 / #BCBCBC)
#   ACCENT:    S 20-35 L 45-55 (como color1-6)
#   MUTED:     S 0-12  L 26-40 (como color8)
#   BRIGHT:    S 20-40 L 55-70 (como color10/12/13/14)
#   Light: BG L88-94 FG L22-30 ACCENT S15-28 L45-55 MUTED L60-74 S0-12
apprentice_bg() { apprentice_clamp "$1" 0 8 12 18; }
apprentice_fg() { apprentice_clamp "$1" 0 8 68 76; }
apprentice_accent() { apprentice_clamp "$1" 20 35 45 55; }
apprentice_muted() { apprentice_clamp "$1" 0 12 26 40; }
apprentice_bright() { apprentice_clamp "$1" 20 40 55 70; }
apprentice_bg_light() { apprentice_clamp "$1" 0 8 88 94; }
apprentice_fg_light() { apprentice_clamp "$1" 0 8 22 30; }
apprentice_accent_light() { apprentice_clamp "$1" 15 28 45 55; }
apprentice_muted_light() { apprentice_clamp "$1" 0 12 60 74; }

lowc_hex() { # <rrggbb> → stdout rrggbb dessaturada rumo ao cinza
    LC_ALL=C printf '%s' "$1" | LC_ALL=C awk -v k="$LOWC_SAT" '{
        h = tolower($0)
        r = hd(substr(h, 1, 2)); g = hd(substr(h, 3, 2)); b = hd(substr(h, 5, 2))
        gr = 0.299 * r + 0.587 * g + 0.114 * b
        printf "%02x%02x%02x", gr + (r - gr) * k / 100, gr + (g - gr) * k / 100, gr + (b - gr) * k / 100
    }
    function hd(s,   v, i, d) { v = 0; for (i = 1; i <= length(s); i++) { d = index("0123456789abcdef", substr(s, i, 1)) - 1; v = v * 16 + d }; return v }'
}

# mix_hex <rrggbb> <rrggbb> <0..1> → mistura das duas cores
mix_hex() {
    LC_ALL=C printf '%s %s %s' "$1" "$2" "$3" | LC_ALL=C awk '{
        a=$1; b=$2; w=$3
        printf "%02x%02x%02x", ch(a,1)*(1-w)+ch(b,1)*w, ch(a,2)*(1-w)+ch(b,2)*w, ch(a,3)*(1-w)+ch(b,3)*w
    }
    function hd(s) { s=tolower(s); v=0; for(i=1;i<=length(s);i++) v=v*16+index("0123456789abcdef",substr(s,i,1))-1; return v }
    function ch(h,n) { return hd(substr(h,(n-1)*2+1,2)) }'
}

# contrast_ratio <rrggbb> <rrggbb> → razão WCAG (ex.: 4.50). Só mede, não ajusta.
contrast_ratio() {
    LC_ALL=C printf '%s %s' "$1" "$2" | LC_ALL=C awk '{
        la = lum($1); lb = lum($2)
        hi = la; lo = lb; if (lo > hi) { hi = lb; lo = la }
        printf "%.2f", (hi + 0.05) / (lo + 0.05)
    }
    function hexd(s,   i, v, d) {
        s = tolower(s); v = 0
        for (i = 1; i <= length(s); i++) { d = index("0123456789abcdef", substr(s, i, 1)) - 1; v = v * 16 + d }
        return v
    }
    function sl(v) { return (v <= 0.03928 ? v / 12.92 : exp(2.4 * log((v + 0.055) / 1.055))) }
    function lum(h,   r, g, b) {
        r = sl(hexd(substr(h, 1, 2)) / 255); g = sl(hexd(substr(h, 3, 2)) / 255); b = sl(hexd(substr(h, 5, 2)) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }'
}

# ensure_contrast <fg rrggbb> <bg rrggbb> [min] → fg ajustado p/ razao >= min (4.5 = WCAG AA; 3.0 = foco/UI)
ensure_contrast() {
    LC_ALL=C printf '%s %s %s' "$1" "$2" "${3:-4.5}" | LC_ALL=C awk '{
        c = $1; bg = $2; min = ($3 == "" ? 4.5 : $3)
        bl = lum(bg)
        light = (bl < 0.5)
        for (k = 0; k < 24; k++) {
            cl = lum(c)
            hi = cl; lo = bl
            if (lo > hi) { hi = bl; lo = cl }
            if ((hi + 0.05) / (lo + 0.05) >= min) break
            c = (light ? mixw(c, 0.18) : mixb(c, 0.18))
        }
        print c
    }
    function hexd(s,   i, v, d) {
        s = tolower(s); v = 0
        for (i = 1; i <= length(s); i++) { d = index("0123456789abcdef", substr(s, i, 1)) - 1; v = v * 16 + d }
        return v
    }
    function sl(v) { return (v <= 0.03928 ? v / 12.92 : exp(2.4 * log((v + 0.055) / 1.055))) }
    function lum(h,   r, g, b) {
        r = sl(hexd(substr(h, 1, 2)) / 255); g = sl(hexd(substr(h, 3, 2)) / 255); b = sl(hexd(substr(h, 5, 2)) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    function mixw(h, w,   r, g, b) {
        r = hexd(substr(h, 1, 2)); g = hexd(substr(h, 3, 2)); b = hexd(substr(h, 5, 2))
        return sprintf("%02x%02x%02x", r + (255 - r) * w, g + (255 - g) * w, b + (255 - b) * w)
    }
    function mixb(h, w,   r, g, b) {
        r = hexd(substr(h, 1, 2)); g = hexd(substr(h, 3, 2)); b = hexd(substr(h, 5, 2))
        return sprintf("%02x%02x%02x", r * (1 - w), g * (1 - w), b * (1 - w))
    }'
}

hex2rgb() { # <rrggbb> → "r, g, b"
    LC_ALL=C printf '%s' "$1" | LC_ALL=C awk '{
        h = tolower($0)
        printf "%d, %d, %d", hd(substr(h, 1, 2)), hd(substr(h, 3, 2)), hd(substr(h, 5, 2))
    }
    function hd(s,   v, i, d) { v = 0; for (i = 1; i <= length(s); i++) { d = index("0123456789abcdef", substr(s, i, 1)) - 1; v = v * 16 + d }; return v }'
}

# sway_roles <BG> <FG> <ACCENT> <MUTED> [C1] — imprime atribuicoes shell:
# FOC UNFOC FOCB FTXT MUTC URGB UTXT BG (foco claro = convencao; FOCUS_SWAP=1 inverte)
# Contraste por role: texto 4.5, chrome/borda 2.0 (Apprentice é low-contrast proposital).
sway_roles() {
    _BG="$1"; _FG="$2"; _AC="$3"; _MU="$4"; _C1="$5"
    _UNFOC=$(mix_hex "$_BG" "$_FG" 0.30 | tr 'a-f' 'A-F')
    _FOC=$(ensure_contrast "$(apprentice_accent "$_AC")" "$_UNFOC" 2.0 | tr 'a-f' 'A-F')
    _FOCB=$(mix_hex "$_FOC" "$_BG" 0.40 | tr 'a-f' 'A-F')
    _FTXT=$(ensure_contrast "$_FG" "$_FOCB" 4.5 | tr 'a-f' 'A-F')
    _MUTC=$(ensure_contrast "$(apprentice_muted "$_MU")" "$_BG" 3.0 | tr 'a-f' 'A-F')
    _URGB=$(mix_hex "$_C1" "$_BG" 0.50 | tr 'a-f' 'A-F')
    _UTXT=$(ensure_contrast "$_FG" "$_URGB" 4.5 | tr 'a-f' 'A-F')
    if [ "${FOCUS_SWAP:-0}" = 1 ]; then
        _t="$_FOC"; _FOC="$_UNFOC"; _UNFOC="$_t"
        _t="$_FOCB"; _FOCB="$_BG"; _BG="$_t"
        _t="$_FTXT"; _FTXT="$_MUTC"; _MUTC="$_t"
    fi
    printf 'FOC=%s\nUNFOC=%s\nFOCB=%s\nFTXT=%s\nMUTC=%s\nURGB=%s\nUTXT=%s\nBG=%s\n' \
        "$_FOC" "$_UNFOC" "$_FOCB" "$_FTXT" "$_MUTC" "$_URGB" "$_UTXT" "$_BG"
}
