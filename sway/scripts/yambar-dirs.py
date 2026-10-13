#!/usr/bin/env python3
"""yambar-dirs.py — TUI de diretórios fixados, mesma vaga do popup tofi.

Estado: ~/.cache/dirs-pinadas (uma path por linha; "fixar" é literal).
Enter abre no gerenciador padrão (file-manager.sh open). a fixa (pede a
path, valida com -d, normaliza sem trailing /), d remove o selecionado,
r recarrega, q/Esc sai.

Flags não-interativas p/ teste (ex-TOFI_DIR* do popup):
--list, --add PATH, --remove PATH.

Paleta: ~/.cache/theme-palette.<mode> (contrato do render.sh).
Lançado pelo yambar-dirs-toggle.sh como `foot -a yambar-dirs`.
"""
import curses
import os
import sys

STATE = os.path.expanduser("~/.cache/dirs-pinadas")
HOME = os.path.expanduser("~")
DEFAULTS = (os.path.join(HOME, "Documentos/Vault"),
            os.path.join(HOME, "dotfiles"),
            os.path.join(HOME, "Documentos"),
            os.path.join(HOME, "Downloads"))


def palette():
    """{BG,FG,ACCENT,MUTED} em hex sem # — default apprentice se faltar."""
    mode = "dark"
    try:
        mode = open(os.path.expanduser("~/.cache/theme-mode")).read().strip() \
            or "dark"
    except OSError:
        pass
    path = os.path.expanduser(f"~/.cache/theme-palette.{mode}")
    if not os.path.exists(path):
        path = os.path.expanduser("~/.cache/theme-palette")
    colors = {"BG": "131111", "FG": "c7c2c2", "ACCENT": "b08c4f",
              "MUTED": "726969"}
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if "=" in line:
                    key, val = line.split("=", 1)
                    if key.strip() in colors:
                        colors[key.strip()] = val.strip().lstrip("#")
    except OSError:
        pass
    return colors


def init_colors():
    """Pares: 1 normal, 2 header/seleção (accent), 3 help (muted)."""
    c = palette()
    cols = {}
    for i, key in enumerate(("FG", "ACCENT", "MUTED", "BG"), start=1):
        r, g, b = (int(c[key][j:j + 2], 16) * 1000 // 255 for j in (0, 2, 4))
        try:
            curses.init_color(i, r, g, b)
            cols[key] = i
        except curses.error:
            cols[key] = -1
    try:
        curses.init_pair(1, cols["FG"], cols["BG"])
        curses.init_pair(2, cols["BG"], cols["ACCENT"])
        curses.init_pair(3, cols["MUTED"], cols["BG"])
    except curses.error:
        pass
    return (curses.color_pair(1), curses.color_pair(2) | curses.A_BOLD,
            curses.color_pair(3))


def ensure_defaults():
    if not os.path.exists(STATE):
        write_dirs(list(DEFAULTS))


def load_dirs():
    ensure_defaults()
    try:
        with open(STATE, encoding="utf-8") as fh:
            return [l.strip() for l in fh if l.strip()]
    except OSError:
        return []


def write_dirs(dirs):
    tmp = f"{STATE}.yambar-dirs.tmp"
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            for d in dirs:
                fh.write(f"{d}\n")
        if os.path.exists(STATE):
            os.chmod(tmp, os.stat(STATE).st_mode & 0o7777)
        os.replace(tmp, STATE)
        return True
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def normalize(path):
    """Expande ~, resolve e tira trailing /; vazio se não é diretório."""
    path = os.path.expanduser(os.path.expandvars(path.strip()))
    if os.path.isdir(path):
        return os.path.realpath(path)
    return ""


def add_dir(path):
    real = normalize(path)
    if not real:
        return False
    dirs = load_dirs()
    if real not in dirs:
        dirs.append(real)
        return write_dirs(dirs)
    return True


def remove_dir(path):
    dirs = [d for d in load_dirs() if d != path]
    return write_dirs(dirs)


def short(path):
    return path.replace(HOME, "~", 1) if path.startswith(HOME) else path


HELP = ("↑↓ mover  Enter: abrir  a: fixar  d: remover  "
        "r: recarregar  q: sair")


def main(stdscr):
    import subprocess
    curses.use_default_colors()
    curses.curs_set(0)
    stdscr.keypad(True)
    p_norm, p_sel, p_help = init_colors()

    dirs = []
    top = sel = 0
    flash = ""

    def load():
        nonlocal dirs, top, sel
        dirs = load_dirs()
        top = sel = 0

    def clamp_scroll(h):
        nonlocal top
        rows = max(h - 2, 1)
        if sel < top:
            top = sel
        elif sel >= top + rows:
            top = sel - rows + 1
        top = max(0, min(top, max(len(dirs) - rows, 0)))

    def draw():
        nonlocal flash
        h, w = stdscr.getmaxyx()
        if h < 3 or w < 20:
            return
        stdscr.addnstr(0, 0, f" Diretórios · {len(dirs)} fixados ",
                       w - 1, p_sel)
        rows = h - 2
        for i in range(top, min(top + rows, len(dirs))):
            shown = f" {short(dirs[i])}"
            if len(shown) > w - 1:
                shown = shown[:w - 2] + "…"
            y = i - top + 1
            missing = not os.path.isdir(dirs[i])
            attrs = p_help if missing else p_norm
            if i == sel:
                stdscr.addnstr(y, 0, " " * (w - 1), w - 1, p_sel)
                stdscr.addnstr(y, 0, shown, w - 1, p_sel)
            else:
                stdscr.addnstr(y, 0, shown.ljust(w - 1), w - 1, attrs)
        stdscr.addnstr(h - 1, 0, HELP[:w - 1], w - 1, p_help)
        if flash:
            stdscr.addnstr(h - 1, w - 1 - len(flash) - 1, flash, len(flash),
                           p_sel)
            flash = ""
        stdscr.refresh()

    def read_line(prompt):
        """Input inline na última linha; get_wch aceita acentos."""
        nonlocal flash
        h, w = stdscr.getmaxyx()
        curses.curs_set(1)
        stdscr.addnstr(h - 1, 0, " " * (w - 1), w - 1, p_sel)
        stdscr.addnstr(h - 1, 0, prompt[:w - 1], w - 1, p_sel)
        stdscr.refresh()
        sub = stdscr.subwin(1, w - len(prompt) - 1, h - 1, len(prompt))
        sub.keypad(True)
        sub.erase()
        sub.refresh()
        buf = []
        while True:
            try:
                ch = sub.get_wch()
            except curses.error:
                continue
            if isinstance(ch, int):
                if ch in (curses.KEY_ENTER, 10, 13):
                    curses.curs_set(0)
                    return "".join(buf).strip()
                if ch == 27 or ch == curses.KEY_CANCEL:
                    curses.curs_set(0)
                    return ""
                if ch in (curses.KEY_BACKSPACE, 127, 8):
                    if buf:
                        buf.pop()
            else:
                if ch in ("\n", "\r"):
                    curses.curs_set(0)
                    return "".join(buf).strip()
                if ch == "\x1b":
                    curses.curs_set(0)
                    return ""
                if ch in ("\x7f", "\b"):
                    if buf:
                        buf.pop()
                elif ch.isprintable():
                    buf.append(ch)
            sub.erase()
            shown = "".join(buf)[-(w - len(prompt) - 2):]
            sub.addnstr(0, 0, shown, w - len(prompt) - 1, p_norm)
            sub.refresh()

    def open_dir(path):
        nonlocal flash
        if not os.path.isdir(path):
            flash = f"ausente: {short(path)}"
            return
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "file-manager.sh")
        subprocess.run([script, "open", path], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        flash = "aberto no gerenciador"

    load()
    while True:
        draw()
        key = stdscr.getch()
        if key in (ord("q"), 27):
            return
        if key in (curses.KEY_UP, ord("k")) and dirs:
            sel = max(0, sel - 1)
        elif key in (curses.KEY_DOWN, ord("j")) and dirs:
            sel = min(len(dirs) - 1, sel + 1)
        elif key in (curses.KEY_ENTER, 10, 13) and dirs:
            open_dir(dirs[sel])
        elif key == ord("r"):
            load()
            flash = "recarregado"
        elif key in (ord("a"), ord("+")):
            new = read_line(" fixar diretório: ")
            if new:
                real = normalize(new)
                if not real:
                    flash = f"não é um diretório: {new}"
                elif add_dir(real):
                    load()
                    flash = "fixado"
                else:
                    flash = "falha ao gravar"
        elif key in (ord("d"), ord("-")) and dirs:
            gone = dirs[sel]
            if remove_dir(gone):
                load()
                flash = "removido"
            else:
                flash = "falha ao gravar"
        clamp_scroll(stdscr.getmaxyx()[0])


if __name__ == "__main__":
    if "--list" in sys.argv:
        for d in load_dirs():
            print(d)
        sys.exit(0)
    if "--add" in sys.argv:
        i = sys.argv.index("--add")
        path = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        if add_dir(path):
            sys.exit(0)
        sys.stderr.write(f"não é um diretório: {path}\n")
        sys.exit(1)
    if "--remove" in sys.argv:
        i = sys.argv.index("--remove")
        path = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        real = os.path.realpath(os.path.expanduser(path)) if path else ""
        sys.exit(0 if remove_dir(real) else 1)
    curses.wrapper(main)
