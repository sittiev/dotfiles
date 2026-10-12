#!/usr/bin/env python3
"""yambar-tasks.py — TUI de tarefas do vault Obsidian, sincronizada em disco.

Fonte única: os arquivos .md do vault. Nada de estado próprio — cada
recarregamento re-escaneia. Espaço reescreve a linha do checkbox no
arquivo ([ ] <-> [x], preservando indentação/marcador); o Obsidian e a
contagem do chip na barra enxergam a mudança na hora. Enter abre a nota
no Obsidian (obsidian://open). / busca (sem acento, sem caixa-alta,
texto + arquivo, filtro ao vivo); o alterna a ordem (recentes, antigas,
texto A–Z sem acento, arquivo, criadas). q sai; Esc limpa o filtro ou
sai quando sem filtro.

--count: só imprime o número de tarefas abertas (usado pelo chip do
yambar — mesma exclusão de pastas da TUI, uma fonte da verdade).

Paleta: lida de ~/.cache/theme-palette.<mode> (mesmo contrato do
render.sh, que é o dono do tema). Lançado pelo yambar-tasks-toggle.sh
como `foot -a yambar-tasks` — app_id casa com a regra floating do sway.
"""
import curses
import datetime
import glob
import os
import re
import subprocess
import sys
import unicodedata
from urllib.parse import quote

VAULT = os.path.expanduser("~/Documentos/Vault")
# Fora do escopo de "tarefa atual": arquivo morto, backups de agente e
# rascunhos de AI (clippings/prompt docs geram checkbox de exemplo, ruído).
EXCLUDE_DIRS = ("Arquivo", "Memória de Agentes", "Recursos/AI",
                ".obsidian", ".agents", ".trash", "Excalidraw")
CHECK = re.compile(r"^(?P<indent>\s*(?:[-*+]|\d+[.)])\s+)"
                   r"\[(?P<mark>[ xX])\]\s*(?P<text>.+?)\s*$")
# Carimbos no estilo do plugin Obsidian Tasks (texto puro no markdown):
#   ➕ YYYY-MM-DD HH:MM  criada  (a TUI grava ao criar)
#   ✅ YYYY-MM-DD HH:MM  concluída (a TUI grava ao concluir, remove ao reabrir)
# Tarefas anteriores à TUI não têm ➕: detalhes mostram o birth time do
# ARQUIVO (stat %W) como aproximação honesta de "criada em".
DONE_STAMP = re.compile(r"✅\s*(\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2})?)")
CREATED_STAMP = re.compile(r"➕\s*(\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2})?)")


def norm(s):
    """Minúsculas sem acento p/ busca e ordenação (á→a, ç→c)."""
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn").casefold()


# Modos do "ordenar-por" (tecla o): todos preservam abertas primeiro.
SORT_MODES = (
    ("recentes", "recentes"),
    ("antigas", "antigas"),
    ("texto", "texto A–Z"),
    ("arquivo", "arquivo"),
    ("criadas", "criadas"),
)


def created_sort_key(text, mtime):
    """➕ da tarefa; sem carimbo usa o mtime (sem stat extra por item —
    ver task_created_at p/ o birth exibido nos detalhes). ISO = ordem
    lexicográfica vale como cronológica."""
    m = CREATED_STAMP.search(text)
    if m:
        return m.group(1)
    return datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")


def sort_tasks(tasks, mode):
    """tasks: (path, n, indent, done, text, mtime). Devolve nova lista."""
    if mode == "antigas":
        return sorted(tasks, key=lambda t: (t[3], t[5], t[1]))
    if mode == "texto":
        return sorted(tasks, key=lambda t: (t[3], norm(t[4]), t[1]))
    if mode == "arquivo":
        return sorted(tasks,
                      key=lambda t: (t[3], norm(os.path.relpath(t[0], VAULT)),
                                     t[1]))
    if mode == "criadas":
        return sorted(tasks,
                      key=lambda t: (t[3], created_sort_key(t[4], t[5]), t[1]))
    return sorted(tasks, key=lambda t: (t[3], -t[5], t[1]))


def match_query(text, rel, query_n):
    """Busca em texto + arquivo, sem acento e sem caixa-alta."""
    if not query_n:
        return True
    return query_n in norm(text) or query_n in norm(rel)


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


def scan_tasks():
    """Tarefas do vault: abertas primeiro, depois mtime desc do arquivo."""
    tasks = []
    for path in glob.iglob(f"{VAULT}/**/*.md", recursive=True):
        rel = os.path.relpath(path, VAULT)
        if rel.startswith(EXCLUDE_DIRS):
            continue
        try:
            mtime = os.path.getmtime(path)
            with open(path, encoding="utf-8", errors="replace") as fh:
                in_fence = False
                for n, line in enumerate(fh, 1):
                    if line.lstrip().startswith("```"):
                        in_fence = not in_fence
                        continue
                    if in_fence:
                        continue
                    m = CHECK.match(line)
                    if m:
                        tasks.append((mtime, path, n, m.group("indent"),
                                      m.group("mark") != " ", m.group("text")))
        except OSError:
            continue
    tasks.sort(key=lambda t: (t[4], -t[0], t[1], t[2]))
    return [(path, n, indent, done, text, mtime)
            for mtime, path, n, indent, done, text in tasks]


def count_open():
    return sum(1 for t in scan_tasks() if not t[3])


def write_task(path, nline, done, text=None):
    """Reescreve a linha do checkbox; atômico (tmp+rename) p/ o sync do
    vault nunca ver meio arquivo. False se a linha mudou no disco — a UI
    recarrega em vez de gravar por cima. text=None preserva o original."""
    tmp = f"{path}.yambar-tasks.tmp"
    try:
        with open(path, encoding="utf-8") as src, \
                open(tmp, "w", encoding="utf-8") as dst:
            for n, line in enumerate(src, 1):
                if n == nline:
                    m = CHECK.match(line)
                    if not m:
                        return False
                    if text is None:
                        text = m.group("text")
                    mark = "x" if done else " "
                    line = f"{m.group('indent')}[{mark}] {text}\n"
                dst.write(line)
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
        os.replace(tmp, path)
        return True
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def open_obsidian(path):
    uri = "obsidian://open?path=" + quote(os.path.abspath(path), safe="")
    subprocess.run(["xdg-open", uri], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def init_colors():
    """Pares: 1 normal, 2 header/seleção (accent), 3 help (muted).
    init_color falha em TERMs sem truecolor — cai no default do curses."""
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


def now_stamp():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")


def strip_stamp(text, regex):
    new = regex.sub("", text, count=1)
    return re.sub(r"\s{2,}", " ", new).strip()


def add_created_stamp(text):
    if CREATED_STAMP.search(text):
        return text
    return f"{text} ➕ {now_stamp()}"


def apply_done_stamp(text):
    """Ao concluir: garante ➕ (se faltava, carimba agora) e adiciona ✅."""
    return f"{add_created_stamp(text)} ✅ {now_stamp()}"


def remove_done_stamp(text):
    """Ao reabrir: remove ✅ (➕ fica — criação não se apaga)."""
    return strip_stamp(text, DONE_STAMP)


def file_birth(path):
    """Birth time do arquivo via stat %W; vazio se o fs não o tiver."""
    try:
        out = subprocess.run(["stat", "-c", "%W", path],
                              capture_output=True, text=True, check=False)
        if out.returncode == 0 and out.stdout.strip().isdigit():
            bt = int(out.stdout.strip())
            if bt > 0:
                return datetime.datetime.fromtimestamp(bt).strftime(
                    "%Y-%m-%d %H:%M")
    except (OSError, ValueError):
        pass
    return ""


def task_created_at(text, path):
    """Quando a tarefa foi criada: carimbo ➕; sem carimbo (tarefa anterior
    à TUI) mostra o birth time do arquivo como aproximação."""
    m = CREATED_STAMP.search(text)
    if m:
        return m.group(1)
    return file_birth(path) or "?"


def task_done_at(text):
    m = DONE_STAMP.search(text)
    return m.group(1) if m else ""


def append_task(text):
    """Nova tarefa no Notepad, sob a seção '## todo'. Retorna a path usada."""
    path = os.path.join(VAULT, "Inbox", "Notepad.md")
    line = f"- [ ] {text} ➕ {now_stamp()}\n"
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
    except FileNotFoundError:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        lines = []
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    insert_at = len(lines)
    for i, l in enumerate(lines):
        if l.rstrip("\n") == "## todo":
            # fim da seção: avança enquanto a linha é tarefa/vazia e a
            # próxima não é header; a nova tarefa entra no fim da seção
            insert_at = i + 1
            for j in range(i + 1, len(lines)):
                s = lines[j].rstrip("\n")
                # para no próximo header ou linha vazia: nunca deixa a
                # tarefa órfã depois de blanks nem fora da seção
                if s.startswith("#") or not s:
                    break
                insert_at = j + 1
            break
    else:
        lines.append("## todo\n")
        insert_at = len(lines)
    lines.insert(insert_at, line)
    tmp = f"{path}.yambar-tasks.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.writelines(lines)
        os.chmod(tmp, os.stat(path).st_mode & 0o7777
                 if os.path.exists(path) else 0o666)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return None
    return path


HELP = ("↑↓ mover  espaço: concluir/reabrir  /: buscar  o: ordem  "
        "d: detalhes  n: nova  Enter: Obsidian  r: recarregar  q: sair")


def main(stdscr):
    curses.use_default_colors()
    curses.curs_set(0)
    stdscr.keypad(True)
    p_norm, p_sel, p_help = init_colors()

    tasks = []  # todas, sem filtro: (path, n, indent, done, text, mtime)
    view = []  # ordenadas + filtradas
    sort_idx = 0
    query = ""
    query_n = ""
    top = sel = 0
    flash = ""

    def refresh(reset_sel=False):
        nonlocal view, top, sel
        mode = SORT_MODES[sort_idx][0]
        ordered = sort_tasks(tasks, mode)
        if query_n:
            ordered = [t for t in ordered
                       if match_query(t[4], os.path.relpath(t[0], VAULT),
                                      query_n)]
        view = ordered
        if reset_sel:
            top = sel = 0
        sel = max(0, min(sel, max(len(view) - 1, 0)))
        top = max(0, min(top, max(len(view) - 1, 0)))

    def load():
        nonlocal tasks, top, sel, flash
        tasks = scan_tasks()
        top = sel = 0
        refresh()
        if not tasks:
            flash = "nenhuma tarefa no vault"
        elif query_n and not view:
            flash = "sem resultado; Esc limpa o filtro"

    def clamp_scroll(h):
        nonlocal top
        rows = max(h - 2, 1)
        if sel < top:
            top = sel
        elif sel >= top + rows:
            top = sel - rows + 1
        top = max(0, min(top, max(len(view) - rows, 0)))

    def draw():
        nonlocal flash
        h, w = stdscr.getmaxyx()
        if h < 3 or w < 20:
            return
        open_n = sum(1 for t in tasks if not t[3])
        label = SORT_MODES[sort_idx][1]
        head = f" Tarefas · {open_n} abertas / {len(tasks)} · {label} "
        if query:
            head += f"· /{query} {len(view)}/{len(tasks)} "
        stdscr.addnstr(0, 0, head, w - 1, p_sel)
        rows = h - 2
        for i in range(top, min(top + rows, len(view))):
            path, _, _, done, text, _ = view[i]
            rel = os.path.relpath(path, VAULT)
            mark = "[x]" if done else "[ ]"
            shown = f" {mark} {text}"
            room = min(len(rel), max(w // 3, 16)) + 2
            maxtext = w - 1 - room if w - 1 - room > 12 else w - 1
            if len(shown) > maxtext:
                shown = shown[:maxtext - 1] + "…"
            y = i - top + 1
            attrs = p_norm | curses.A_DIM if done else p_norm
            if i == sel:
                stdscr.addnstr(y, 0, " " * (w - 1), w - 1, p_sel)
                stdscr.addnstr(y, 0, shown, w - 1, p_sel)
            else:
                stdscr.addnstr(y, 0, shown.ljust(w - 1), w - 1, attrs)
            if maxtext < w - 1 and len(rel) + 2 <= w - maxtext:
                stdscr.addnstr(y, w - 1 - len(rel) - 1, rel, len(rel),
                               p_help)
        stdscr.addnstr(h - 1, 0, HELP[:w - 1], w - 1, p_help)
        if flash:
            stdscr.addnstr(h - 1, w - 1 - len(flash) - 1, flash, len(flash),
                           p_sel)
            flash = ""
        stdscr.refresh()

    def toggle():
        nonlocal flash, sel
        path, nline, _, done, text, _ = view[sel]
        new_text = remove_done_stamp(text) if done else apply_done_stamp(text)
        if write_task(path, nline, not done, new_text):
            for i, t in enumerate(tasks):
                if t[0] == path and t[1] == nline:
                    tasks[i] = (path, nline, t[2], not done, new_text, t[5])
                    break
            refresh()
            # segue o item: re-localiza (path, nline) na nova ordem
            for i, t in enumerate(view):
                if t[0] == path and t[1] == nline:
                    sel = i
                    break
            flash = "concluída ✅" if not done else "reaberta"
        else:
            load()
            flash = "arquivo mudou no disco; recarregado"

    def read_line(prompt):
        """Input inline na última linha: get_wch devolve o caractere
        completo (acentos funcionam); Esc cancela, Enter devolve o texto
        (vazio = cancela)."""
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

    def search():
        """Busca com filtro ao vivo (sem acento, sem caixa-alta): cada
        tecla refiltra a lista; Enter confirma, Esc cancela e restaura o
        filtro anterior (vazio + Enter limpa)."""
        nonlocal query, query_n, flash
        prev_q, prev_qn = query, query_n
        h, w = stdscr.getmaxyx()
        prompt = " buscar: "
        curses.curs_set(1)
        sub = stdscr.subwin(1, w - len(prompt) - 1, h - 1, len(prompt))
        sub.keypad(True)
        buf = list(prev_q)
        while True:
            query = "".join(buf)
            query_n = norm(query.strip())
            refresh(reset_sel=True)
            draw()
            stdscr.addnstr(h - 1, 0, " " * (w - 1), w - 1, p_sel)
            stdscr.addnstr(h - 1, 0, prompt[:w - 1], w - 1, p_sel)
            shown = "".join(buf)[-(w - len(prompt) - 2):]
            sub.erase()
            try:
                sub.addnstr(0, 0, shown, w - len(prompt) - 1, p_norm)
            except curses.error:
                pass
            sub.refresh()
            try:
                ch = sub.get_wch()
            except curses.error:
                continue
            if isinstance(ch, int):
                if ch in (curses.KEY_ENTER, 10, 13):
                    break
                if ch == 27 or ch == curses.KEY_CANCEL:
                    query, query_n = prev_q, prev_qn
                    refresh(reset_sel=True)
                    curses.curs_set(0)
                    flash = "busca cancelada"
                    return
                if ch in (curses.KEY_BACKSPACE, 127, 8):
                    if buf:
                        buf.pop()
            else:
                if ch in ("\n", "\r"):
                    break
                if ch == "\x1b":
                    query, query_n = prev_q, prev_qn
                    refresh(reset_sel=True)
                    curses.curs_set(0)
                    flash = "busca cancelada"
                    return
                if ch in ("\x7f", "\b"):
                    if buf:
                        buf.pop()
                elif ch.isprintable():
                    buf.append(ch)
        curses.curs_set(0)
        query = "".join(buf)
        query_n = norm(query.strip())
        refresh(reset_sel=True)
        if not query_n:
            query = ""
            flash = "filtro limpo"
        else:
            flash = f"{len(view)} resultado(s) p/ “{query}”"

    def wrap(text, width):
        """Quebra por palavras; palavra maior que a largura é cortada."""
        out = []
        for word in text.split():
            while len(word) > width:
                out.append(word[:width])
                word = word[width:]
            out.append(word)
        lines, cur = [], ""
        for word in out:
            if not cur:
                cur = word
            elif len(cur) + 1 + len(word) <= width:
                cur += " " + word
            else:
                lines.append(cur)
                cur = word
        lines.append(cur or "")
        return lines

    def draw_details():
        """Painel de detalhes da tarefa selecionada (qualquer tecla sai).
        Texto completo da tarefa com wrapping — nunca truncado."""
        path, nline, _, done, text, _ = view[sel]
        created = task_created_at(text, path)
        done_at = task_done_at(text)
        h, w = stdscr.getmaxyx()
        # largura interna do painel: texto em wrap de (pw-6) colunas
        inner = max(20, w - 10)
        text_lines = wrap(" " + text, inner - 4)
        info = [f"  criada: {created}"
                f"{' (birth do arquivo)' if not CREATED_STAMP.search(text) else ''}",
                f"  concluída: {done_at if done_at else '—'}",
                f"  arquivo: {os.path.relpath(path, VAULT)}:{nline}"]
        # path do arquivo também pode passar da largura → wrap
        max_line = max([len(l) for l in text_lines] + [len(l) for l in info] + [10])
        pw = min(max_line + 6, w - 2)
        ph = len(text_lines) + len(info) + 4  # título? não: 1 borda + wrap + sep + info + borda
        ph = min(ph + 1, h - 1)
        py = max(0, (h - ph) // 2)
        px = max(0, (w - pw) // 2)
        win = curses.newwin(ph, pw, py, px)
        win.erase()
        win.bkgd(" ", p_sel)
        y = 1
        for l in text_lines:
            win.addnstr(y, 2, l, pw - 3, p_sel | curses.A_BOLD)
            y += 1
        y += 0
        for l in info:
            win.addnstr(y, 2, l, pw - 3, p_norm)
            y += 1
        win.addnstr(y, 2, "  qualquer tecla volta", pw - 3, p_norm)
        win.border()
        win.refresh()
        stdscr.timeout(-1)
        stdscr.getch()
        stdscr.refresh()


    load()
    while True:
        draw()
        key = stdscr.getch()
        if key == ord("q"):
            return
        if key == 27:
            # Esc com filtro ativo limpa o filtro; sem filtro sai
            if query_n:
                query = ""
                query_n = ""
                refresh(reset_sel=True)
                flash = "filtro limpo"
                continue
            return
        if key in (curses.KEY_UP, ord("k")) and view:
            sel = max(0, sel - 1)
        elif key in (curses.KEY_DOWN, ord("j")) and view:
            sel = min(len(view) - 1, sel + 1)
        elif key == ord(" "):
            if view:
                toggle()
        elif key in (curses.KEY_ENTER, 10, 13) and view:
            open_obsidian(view[sel][0])
            flash = "aberta no Obsidian"
        elif key == ord("r"):
            load()
            flash = "recarregado"
        elif key == ord("o"):
            sort_idx = (sort_idx + 1) % len(SORT_MODES)
            refresh()
            flash = f"ordem: {SORT_MODES[sort_idx][1]}"
        elif key == ord("/"):
            search()
        elif key == ord("d") and view:
            draw_details()
        elif key == ord("n"):
            title = read_line(" nova tarefa: ")
            if title:
                if append_task(title):
                    load()
                    flash = "criada"
                else:
                    flash = "falha ao gravar"
        clamp_scroll(stdscr.getmaxyx()[0])


if __name__ == "__main__":
    if "--count" in sys.argv:
        if not os.path.isdir(VAULT):
            print(0)
        else:
            print(count_open())
        sys.exit(0)
    if not os.path.isdir(VAULT):
        sys.stderr.write(f"vault ausente: {VAULT}\n")
        sys.exit(1)
    curses.wrapper(main)
