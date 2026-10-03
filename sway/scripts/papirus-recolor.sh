#!/usr/bin/dash
# papirus-recolor.sh — gera uma cópia do Papirus com actions/symbolic
# monocromáticos puxando da paleta pywal (mesma ideia do icon-recolor.sh/YAMIS).
#
# O Papirus declara no <style> de cada SVG:
#     .ColorScheme-Text {color:#444444} .ColorScheme-Highlight {color:#4285f4}
#     .ColorScheme-NeutralText {color:#ff9800} .ColorScheme-PositiveText {color:#4caf50}
#     .ColorScheme-NegativeText {color:#f44336}
# e os elementos usam class="ColorScheme-*" + style="fill:currentColor".
# O GTK/librsvg renderiza o hex literal, então trocar esses papéis pelos
# tokens da paleta deixa o chrome (actions/symbolic) acompanhando o
# wallpaper e o modo light/dark. Apps/places/mimetypes ficam coloridos
# (só actions/symbolic entram no mono, a pedido).
#
# Mapeamento (mono + semântica de erro preservada):
#   Text #444444      → FG     (textura principal)
#   Highlight #4285f4 → ACCENT (destaque, mesma ideia do KDE Highlight do YAMIS)
#   Neutral #ff9800   → MUTED  (tom secundário)
#   Positive #4caf50  → MUTED  (verde quebraria o mono)
#   Negative #f44336  → FAIL   (erro segue o FAIL da paleta)
#
# O tema base nunca é modificado: clona-se a árvore com hardlinks
# (cp -al) e reescreve via tmp+rename, o que quebra o hardlink — o inode
# original fica intocado. Consumo extra: só os arquivos reescritos.
#
#   papirus-recolor.sh → imprime o nome do tema gerado (stdout); exit 1 se
#                        tema base ou paleta estiverem ausentes
set -u

NAME="papirus-wal"
DST="$HOME/.local/share/icons/$NAME"
PAL="$HOME/.cache/theme-palette"

# Base: sistema primeiro (extra/papirus-icon-theme, atualizado), local como
# fallback (instalação manual antiga sem .git).
SRC=""
for _c in "/usr/share/icons/Papirus" "$HOME/.local/share/icons/Papirus"; do
    if [ -f "$_c/index.theme" ]; then
        SRC="$_c"
        break
    fi
done
unset _c
[ -n "$SRC" ] || exit 1
[ -f "$PAL" ] || exit 1
# shellcheck disable=SC1090
. "$PAL"
[ -n "${FG:-}" ] && [ -n "${ACCENT:-}" ] && [ -n "${MUTED:-}" ] && [ -n "${FAIL:-}" ] || exit 1

rm -rf "$DST"
if ! cp -al "$SRC" "$DST" 2>/dev/null; then
    # filesystem sem suporte a hardlink: cópia real (uma vez)
    cp -a "$SRC" "$DST" || exit 1
fi
# cache herdado do base (mesmo inode): remover antes de gerar o nosso
rm -f "$DST/icon-theme.cache"

python3 - "$DST" "$FG" "$ACCENT" "$MUTED" "$FAIL" <<'PY' || exit 1
import os, re, sys

dst, fg, acc, mut, fail = sys.argv[1:6]
mapping = {"#444444": "#" + fg, "#4285f4": "#" + acc, "#ff9800": "#" + mut,
           "#4caf50": "#" + mut, "#f44336": "#" + fail}
pat = re.compile("|".join(re.escape(k) for k in mapping), re.I)
repl = lambda m: mapping[m.group(0).lower()]

rewritten = 0
for root, dirs, files in os.walk(dst):
    dirs[:] = [d for d in dirs if not d.startswith(".")]
    # só o chrome entra no mono; apps/places/mimetypes seguem coloridos
    # (root é o diretório: ".../16x16/actions" termina sem barra)
    if "/actions" not in root and "/symbolic" not in root:
        continue
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

# index.theme: copia real (quebra o hardlink) + nome e fallback para a base
idx = os.path.join(dst, "index.theme")
try:
    with open(idx, encoding="utf-8", errors="surrogateescape") as f:
        data = f.read()
    data = re.sub(r"(?m)^Name=.*$", "Name=Papirus wal", data, count=1)
    if re.search(r"(?m)^Inherits=.*$", data):
        data = re.sub(r"(?m)^Inherits=.*$",
                      "Inherits=Papirus,breeze,hicolor", data, count=1)
    else:
        data += "\nInherits=Papirus,breeze,hicolor\n"
    tmp = idx + ".tmp"
    with open(tmp, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(data)
    os.replace(tmp, idx)
except OSError:
    sys.exit(1)

sys.stderr.write("papirus-recolor: %d svg recoloridos (FG=%s ACCENT=%s MUTED=%s FAIL=%s)\n"
                 % (rewritten, fg, acc, mut, fail))
PY

gtk-update-icon-cache -f -q "$DST" >/dev/null 2>&1 || true
printf '%s\n' "$NAME"
