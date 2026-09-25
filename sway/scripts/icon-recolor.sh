#!/usr/bin/dash
# icon-recolor.sh — gera uma cópia do YAMIS recolorida pela paleta pywal.
#
# O yet-another-monochrome-icon-set segue a convenção KDE FollowsColorScheme:
# cada SVG declara dentro de um bloco <style>
#     .ColorScheme-Text {color:#d8dee9}   .ColorScheme-Highlight {color:#3b4252}
# e os elementos usam class="ColorScheme-Text" + style="fill:currentColor".
# O GTK/librsvg renderiza o hex literal, então trocar essas cores pelos tokens
# da paleta deixa os ícones acompanhando o wallpaper e o modo light/dark.
#
# O tema base nunca é modificado: clona-se a árvore com hardlinks
# (cp -al) e reescreve via tmp+rename, o que quebra o hardlink — o inode
# original fica intocado. Consumo extra: só os arquivos reescritos.
#
#   icon-recolor.sh   → imprime o nome do tema gerado (stdout); exit 1 se
#                       tema base ou paleta estiverem ausentes
set -u

SRC="$HOME/.local/share/icons/yet-another-monochrome-icon-set"
NAME="yamis-wal"
DST="$HOME/.local/share/icons/$NAME"
PAL="$HOME/.cache/theme-palette"

[ -f "$SRC/index.theme" ] || exit 1
[ -f "$PAL" ] || exit 1
# shellcheck disable=SC1090
. "$PAL"
[ -n "${FG:-}" ] && [ -n "${ACCENT:-}" ] && [ -n "${MUTED:-}" ] || exit 1

rm -rf "$DST"
if ! cp -al "$SRC" "$DST" 2>/dev/null; then
    # filesystem sem suporte a hardlink: cópia real (20M, uma vez)
    cp -a "$SRC" "$DST" || exit 1
fi
# cache herdado do base (mesmo inode): remover antes de gerar o nosso
rm -f "$DST/icon-theme.cache"

python3 - "$DST" "$FG" "$ACCENT" "$MUTED" <<'PY' || exit 1
import os, re, sys

dst, fg, acc, mut = sys.argv[1:5]
# textura principal, destaque (KDE Highlight) e tom secundário
mapping = {"#d8dee9": "#" + fg, "#3b4252": "#" + acc, "#999999": "#" + mut}
pat = re.compile("|".join(re.escape(k) for k in mapping), re.I)
repl = lambda m: mapping[m.group(0).lower()]

rewritten = 0
for root, dirs, files in os.walk(dst):
    dirs[:] = [d for d in dirs if not d.startswith(".")]
    for fn in files:
        if not fn.endswith(".svg"):
            continue
        path = os.path.join(root, fn)
        try:
            with open(path, encoding="utf-8", errors="surrogateescape") as f:
                data = f.read()
        except OSError:
            continue
        new, hits = pat.subn(repl, data)
        if not hits:
            continue
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8", errors="surrogateescape") as f:
            f.write(new)
        os.replace(tmp, path)  # rename quebra o hardlink: base intacta
        rewritten += 1

# index.theme: copia real (quebra o hardlink) + nome do tema gerado
idx = os.path.join(dst, "index.theme")
try:
    with open(idx, encoding="utf-8", errors="surrogateescape") as f:
        data = f.read()
    data = re.sub(r"(?m)^Name=.*$", "Name=YAMIS wal", data, count=1)
    tmp = idx + ".tmp"
    with open(tmp, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(data)
    os.replace(tmp, idx)
except OSError:
    sys.exit(1)

sys.stderr.write("icon-recolor: %d svg recoloridos (FG=%s ACCENT=%s MUTED=%s)\n"
                 % (rewritten, fg, acc, mut))
PY

gtk-update-icon-cache -f -q "$DST" >/dev/null 2>&1 || true
printf '%s\n' "$NAME"
