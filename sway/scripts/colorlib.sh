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

# apprentice_clamp <rrggbb> <s_min> <s_max> <l_min> <l_max> [hue_override] → rrggbb
# Prende S/L no envelope do scheme. hue_override, quando dado, é o hue a usar
# no lugar do da entrada: é a assinatura da imagem (WALL_H) mandando na
# família de cor, e o envelope do scheme no contraste/brilho.
#
# Caso especial — S sobe numa cor acromática: o hue de entrada não existe, e
# o clamp usaria hue 0 (vermelho), pintando o "black" do terminal de marrom.
# Nesse caso o cinza é repartido na família do scheme (SCHEME_ACC_CAND); sem
# família, S volta a 0 e o slot fica acromático, que é melhor que errado.
apprentice_clamp() {
    _ac_hex="$1"; _ac_smin="$2"; _ac_smax="$3"; _ac_lmin="$4"; _ac_lmax="$5"
    # ${6:-} e não "$6": o chamador sem âncora passa 5 args, e set -u
    # transformaria o $6 em "parameter not set" (derrubando o render).
    _ac_hover="${6:-}"
    _ac_hsl="$(rgb2hsl_hex "$_ac_hex")"
    _ac_h="${_ac_hsl%% *}"; _ac_rest="${_ac_hsl#* }"
    _ac_s0="${_ac_rest%% *}"
    _ac_s="${_ac_rest%% *}"; _ac_l="${_ac_rest#* }"
    _ac_s="$(LC_ALL=C awk -v s="$_ac_s" -v mn="$_ac_smin" -v mx="$_ac_smax" 'BEGIN{v=s+0; if(v<mn)v=mn; if(v>mx)v=mx; print v}')"
    _ac_l="$(LC_ALL=C awk -v l="$_ac_l" -v mn="$_ac_lmin" -v mx="$_ac_lmax" 'BEGIN{v=l+0; if(v<mn)v=mn; if(v>mx)v=mx; print v}')"
    # exit-status, não stdout: `exit !(cond)` não imprime nada, então
    # `[ -n "$(awk ...)" ]` é sempre falso e o ramo nunca roda.
    if [ -n "$_ac_hover" ]; then
        _ac_h=$_ac_hover
    elif LC_ALL=C awk -v s0="$_ac_s0" 'BEGIN { exit !(s0 + 0 < 0.5) }' &&
        LC_ALL=C awk -v s="$_ac_s" -v s0="$_ac_s0" \
            'BEGIN { exit !(s + 0 > s0 + 0.5) }'; then
        _ac_h=$(chroma_mean "${SCHEME_ACC_CAND:-}" 2>/dev/null) || _ac_h=''
        _ac_h=${_ac_h%% *}
        if [ -z "$_ac_h" ]; then
            _ac_s=0
            _ac_h=0
        fi
    fi
    hsl2rgb_hex "$_ac_h" "$_ac_s" "$_ac_l"
}

# hue_rotate <rrggbb> <graus> → rrggbb
# Gira o hue preservando S/L.
hue_rotate() {
    _hr_hex=${1#\#}
    _hr_d=$(LC_ALL=C awk -v d="${2:-0}" 'BEGIN { d = d % 360; if (d < 0) d += 360; printf "%.2f", d }')
    _hr_hsl=$(rgb2hsl_hex "$_hr_hex")
    _hr_tail=${_hr_hsl#* }
    _hr_h=$(LC_ALL=C awk -v h="${_hr_hsl%% *}" -v d="$_hr_d" \
        'BEGIN { h += d; while (h >= 360) h -= 360; printf "%.2f", h }')
    hsl2rgb_hex "$_hr_h" "${_hr_tail%% *}" "${_hr_tail#* }"
}

# chroma_mean <"hex,hex,..."> → "H S SPREAD"
# Assinatura de cor de um conjunto (o wallpaper ou um scheme):
#   H       hue médio circular  — a família de cor
#   S       croma médio         — o quanto aquela imagem é saturada
#   SPREAD  maior distância circular entre dois hues — o quanto a imagem
#           Variety de matiz
# Só cores cromáticas (S>=6) votam: quase cinzas puxariam o centro para o
# cinza e o hue viraria ruído.
# SPREAD é o que faz a paleta do theme varyr junto com a variety da imagem:
# wallpaper monocromático (spread ~5°) ⇒ janela de hue estreita; wallpaper
# colorido (spread 120°) ⇒ janela larga. Com um span fixo, um wallpaper azul
# de 5° recebia slots a 269° e o terminal saía roxo.
# Sai 1 (stdout vazio) se nada é cromático: imagem P&B cai no caminho do
# scheme, como antes.
chroma_mean() {
    printf '%s\n' "$1" | tr ',' '\n' | while IFS= read -r _cm_c; do
        [ -n "$_cm_c" ] || continue
        rgb2hsl_hex "${_cm_c#\#}"
        printf '\n'
    done | LC_ALL=C awk '
    BEGIN { n = 0 }
    {
        s = $2 + 0
        if (s < 6) next
        hv[n] = $1
        h = $1 * 3.14159265358979 / 180
        x += cos(h) * s
        y += sin(h) * s
        ss += s
        n++
    }
    END {
        if (n == 0) exit 1
        d = atan2(y, x) * 180 / 3.14159265358979
        if (d < 0) d += 360
        sp = 0
        for (i = 0; i < n; i++) {
            for (j = i + 1; j < n; j++) {
                dd = hv[i] - hv[j]
                if (dd < 0) dd = -dd
                if (dd > 180) dd = 360 - dd
                if (dd > sp) sp = dd
            }
        }
        printf "%.2f %.2f %.2f", d, ss / n, sp
    }'
}

# hue_pull <rrggbb> <anchor_h> <k> <src_center_h> → rrggbb
# Puxa o hue de <rrggbb> para a vizinhança de <anchor_h>, comprimindo o
# spread em torno de <src_center_h> por k. k=1 e anchor=src_center é
# identidade; k=0 joga tudo no próprio anchor (paleta monocromática).
# Usado nos 16 ANSI: o layout (qual slot é vermelho/verde/...) vem do scheme,
# a família de cor vem do wallpaper. O 5º argumento (span, default 60) é a
# janela de hue em torno da âncora: o resultado nunca sai dela, o que impede
# que o spread de ~300° do scheme escape para rosa/verde que a imagem não tem.
hue_pull() {
    _hp_hex=${1#\#}
    _hp_anchor=${2:-0}
    _hp_k=${3:-0}
    _hp_center=${4:-0}
    _hp_span=${5:-60}
    _hp_hsl=$(rgb2hsl_hex "$_hp_hex")
    _hp_tail=${_hp_hsl#* }
    _hp_s="${_hp_tail%% *}"
    _hp_l="${_hp_tail#* }"
    # Acromático: não há hue próprio para puxar. Devolve neutro (S=0) em vez de
    # inventar um — o clamp de S depois disso escolheria hue 0 (vermelho) e
    # pintava o "black" do terminal de marrom. exit-status, não stdout.
    if LC_ALL=C awk -v s="$_hp_s" 'BEGIN { exit !(s + 0 < 0.5) }'; then
        hsl2rgb_hex 0 0 "$_hp_l"
        return 0
    fi
    # Diff circular com sinal: (h - c) normalizado para (-180, 180]. Usar
    # 0..360 aqui tratava 322° como "+298°" e jogava o slot para 295° em vez
    # de 190° — o diff tem de preservar o lado do círculo em que o matiz
    # realmente está.
    # Diff circular com sinal: (h - c) normalizado para (-180, 180]. Usar
    # 0..360 aqui tratava 322° como "+298°" e jogava o slot para 295° em vez
    # de 190° — o diff tem de preservar o lado do círculo em que o matiz
    # realmente está.
    #
    # Janela, não compressão: o slot vai para anchor + diff × k e depois é
    # PRESO a anchor ± span. Comprimir (k<1) encolhia o spread inteiro até
    # os 8 slots virarem a mesma cor — uma parede de azul. Só rotacionar
    # (k=1) deixava o spread de ~300° do scheme escapar e pintar de magenta
    # num wallpaper azul. A janela usa toda a faixa liberada e não passa
    # dela: com k=1 o spread preenche a janela toda, dentro da família.
    _hp_h=$(LC_ALL=C awk -v h="${_hp_hsl%% *}" -v a="$_hp_anchor" \
        -v c="$_hp_center" -v k="$_hp_k" -v sp="${_hp_span:-60}" '
        BEGIN {
            d = h - c
            while (d > 180) d -= 360
            while (d <= -180) d += 360
            d = d * k
            if (sp >= 0) {
                if (d > sp) d = sp
                if (d < -sp) d = -sp
            }
            h = a + d
            while (h >= 360) h -= 360
            while (h < 0) h += 360
            printf "%.2f", h
        }')
    hsl2rgb_hex "$_hp_h" "$_hp_s" "$_hp_l"
}

# Envelopes por role (dark). Light espelha L em torno de 50%.
# Os números são os defaults: sem esquema selecionado o output é idêntico ao
# histórico. scheme_init (schemelib.sh) exporta ENV_* que sobrescrevem cada
# faixa conforme o esquema ativo e o modo atual.
#   BG/FG:     S 0-8   (quase acromático, como #262626 / #BCBCBC)
#   ACCENT:    S 20-35 L 45-55 (como color1-6)
#   MUTED:     S 0-12  L 26-40 (como color8)
#   BRIGHT:    S 20-40 L 55-70 (como color10/12/13/14)
#   Light: BG L88-94 FG L22-30 ACCENT S15-28 L45-55 MUTED L60-74 S0-12
# apprentice_clamp_neutral <rrggbb> <l_min> <l_max> → rrggbb
# Clamp só de L, preservando S. Para os slots acromáticos do ANSI (0, 7 e os
# "bright" correspondentes): o clamp de S os tingiria, e um "black" marrom ou
# um "white" rosado é pior do que um cinza neutro. O envelope do scheme entra
# só pelo L, que é onde está o contraste.
apprentice_clamp_neutral() {
    _acn_hex="$1"; _acn_lmin="$2"; _acn_lmax="$3"
    _acn_hsl="$(rgb2hsl_hex "$_acn_hex")"
    _acn_tail="${_acn_hsl#* }"
    _acn_s="${_acn_tail%% *}"
    _acn_l=$(LC_ALL=C awk -v l="${_acn_tail#* }" -v mn="$_acn_lmin" -v mx="$_acn_lmax" \
        'BEGIN { v = l + 0; if (v < mn) v = mn; if (v > mx) v = mx; printf "%.2f", v }')
    hsl2rgb_hex "${_acn_hsl%% *}" "$_acn_s" "$_acn_l"
}

apprentice_bg() { apprentice_clamp "$1" "${ENV_BG_S_MIN:-0}" "${ENV_BG_S_MAX:-8}" "${ENV_BG_L_MIN:-12}" "${ENV_BG_L_MAX:-18}"; }
apprentice_fg() { apprentice_clamp "$1" "${ENV_FG_S_MIN:-0}" "${ENV_FG_S_MAX:-8}" "${ENV_FG_L_MIN:-68}" "${ENV_FG_L_MAX:-76}"; }
apprentice_accent() { apprentice_clamp "$1" "${ENV_ACC_S_MIN:-20}" "${ENV_ACC_S_MAX:-35}" "${ENV_ACC_L_MIN:-45}" "${ENV_ACC_L_MAX:-55}"; }
apprentice_muted() { apprentice_clamp "$1" "${ENV_MUT_S_MIN:-0}" "${ENV_MUT_S_MAX:-12}" "${ENV_MUT_L_MIN:-26}" "${ENV_MUT_L_MAX:-40}"; }
apprentice_bright() { apprentice_clamp "$1" "${ENV_BRI_S_MIN:-20}" "${ENV_BRI_S_MAX:-40}" "${ENV_BRI_L_MIN:-55}" "${ENV_BRI_L_MAX:-70}"; }
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
