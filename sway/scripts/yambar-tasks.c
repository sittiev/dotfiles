/* yambar-tasks.c -- TUI de tarefas do vault em C/notcurses.
 *
 * Paridade com yambar-tasks.py: mesma fonte (markdown no disco, sem estado
 * próprio), Espaço conclui/reabre com carimbo, Enter abre no Obsidian,
 * / busca ao vivo sem acento, o alterna a ordem, d detalhes, n nova
 * tarefa, r recarrega, q sai, Esc limpa filtro ou sai.
 *
 * --count não toca no notcurses (chip do yambar, poll a cada 2s).
 * --selftest delega ao tasks-core (sem TTY).
 *
 * Lançado por yambar-tasks-toggle.sh como `foot -a yambar-tasks`
 * (regra floating casa por app_id, sem mudança de config).
 */
#define _GNU_SOURCE /* strdup, realpath, wcwidth */
#define _POSIX_C_SOURCE 200809L
#include <locale.h>
#include <fcntl.h>
#include <notcurses/nckeys.h>
#include <notcurses/notcurses.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <wchar.h>

#include "tasks-core.h"

static const char *const SORT_LABEL[] = {
    "recentes", "antigas", "texto A–Z", "arquivo", "criadas",
};

static const char HELP[] =
    "↑↓ mover  espaço: concluir/reabrir  /: buscar  o: ordem  "
    "d: detalhes  n: nova  Enter: Obsidian  r: recarregar  q: sair";

typedef struct {
    uint32_t bg, fg, accent, muted;
} pal_t;

static uint32_t hex6(const char *s) {
    uint32_t v = 0;
    for (int i = 0; i < 6 && s[i]; i++) {
        char c = s[i];
        v <<= 4;
        if (c >= '0' && c <= '9')
            v |= (uint32_t)(c - '0');
        else if (c >= 'a' && c <= 'f')
            v |= (uint32_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F')
            v |= (uint32_t)(c - 'A' + 10);
    }
    return v;
}

/* ~/.cache/theme-palette.<mode> (contrato do render.sh); default apprentice. */
static pal_t load_palette(void) {
    char mode[32] = "dark", path[4096];
    const char *home = getenv("HOME") ? getenv("HOME") : "";
    snprintf(path, sizeof path, "%s/.cache/theme-mode", home);
    FILE *f = fopen(path, "r");
    if (f) {
        if (fgets(mode, sizeof mode, f)) {
            mode[strcspn(mode, " \t\r\n")] = 0;
            if (!mode[0])
                strcpy(mode, "dark");
        }
        fclose(f);
    }
    pal_t p = {0x131111, 0xC7C2C2, 0xB08C4F, 0x726969};
    snprintf(path, sizeof path, "%s/.cache/theme-palette.%s", home, mode);
    f = fopen(path, "r");
    if (!f) {
        snprintf(path, sizeof path, "%s/.cache/theme-palette", home);
        f = fopen(path, "r");
    }
    if (f) {
        char line[256];
        while (fgets(line, sizeof line, f)) {
            char *eq = strchr(line, '=');
            if (!eq)
                continue;
            *eq = 0;
            char *v = eq + 1;
            while (*v == ' ' || *v == '\t')
                v++;
            if (*v == '#')
                v++;
            v[strcspn(v, " \t\r\n")] = 0;
            if (strcmp(line, "BG") == 0)
                p.bg = hex6(v);
            else if (strcmp(line, "FG") == 0)
                p.fg = hex6(v);
            else if (strcmp(line, "ACCENT") == 0)
                p.accent = hex6(v);
            else if (strcmp(line, "MUTED") == 0)
                p.muted = hex6(v);
        }
        fclose(f);
    }
    return p;
}

/* decode único via núcleo; controle/inválido rendem largura 0. */
static size_t next_cp(const char **s, uint32_t *cp, int *cols) {
    size_t l = tasks_utf8_decode(*s, cp);
    int cw = wcwidth((wchar_t)*cp);
    *cols = cw > 0 ? cw : 0;
    *s += l;
    return l;
}

/* Largura em colunas (wcwidth por codepoint; controle = 0). */
static int disp_width(const char *s) {
    int w = 0;
    while (*s) {
        uint32_t cp = 0;
        int cw = 0;
        next_cp(&s, &cp, &cw);
        (void)cp;
        w += cw;
    }
    return w;
}

/* Corta src em maxcols colunas (+ "…" se cortou). */
static void cut_cols(char *dst, size_t dstn, const char *src, int maxcols) {
    size_t o = 0;
    int w = 0;
    int cut = 0;
    while (*src) {
        const char *start = src;
        uint32_t cp = 0;
        int cw = 0;
        next_cp(&src, &cp, &cw);
        (void)cp;
        size_t l = (size_t)(src - start);
        if (w + cw > maxcols) {
            cut = 1;
            break;
        }
        if (o + l + 4 >= dstn) {
            cut = 1;
            break;
        }
        memcpy(dst + o, start, l);
        o += l;
        w += cw;
    }
    if (cut && o + 4 < dstn)
        memcpy(dst + o, "…", 3), o += 3;
    dst[o] = 0;
}

typedef struct {
    struct notcurses *nc;
    struct ncplane *sp;
    pal_t pal;
    task_t *tasks;
    size_t ntasks;
    size_t *view;
    size_t vcap, nview;
    int sort_idx;
    char query[1024];
    char query_n[1024];
    size_t sel, top;
    char flash[256];
} ui_t;

static void pal_rgb(uint32_t v, unsigned *r, unsigned *g, unsigned *b) {
    *r = (v >> 16) & 255;
    *g = (v >> 8) & 255;
    *b = v & 255;
}

static void row_colors(ui_t *u, int sel, int help) {
    unsigned r, g, b;
    if (sel) {
        pal_rgb(u->pal.bg, &r, &g, &b);
        ncplane_set_fg_rgb8(u->sp, r, g, b);
        pal_rgb(u->pal.accent, &r, &g, &b);
        ncplane_set_bg_rgb8(u->sp, r, g, b);
        ncplane_set_styles(u->sp, NCSTYLE_BOLD);
    } else if (help) {
        pal_rgb(u->pal.muted, &r, &g, &b);
        ncplane_set_fg_rgb8(u->sp, r, g, b);
        pal_rgb(u->pal.bg, &r, &g, &b);
        ncplane_set_bg_rgb8(u->sp, r, g, b);
        ncplane_set_styles(u->sp, NCSTYLE_NONE);
    } else {
        pal_rgb(u->pal.fg, &r, &g, &b);
        ncplane_set_fg_rgb8(u->sp, r, g, b);
        pal_rgb(u->pal.bg, &r, &g, &b);
        ncplane_set_bg_rgb8(u->sp, r, g, b);
        ncplane_set_styles(u->sp, NCSTYLE_NONE);
    }
}

/* Pinta a linha y com s (corta em w) e preenche o resto com espaços. */
static void paint_row(ui_t *u, int y, unsigned w, const char *s) {
    char line[4096];
    cut_cols(line, sizeof line, s, (int)w - 1 > 0 ? (int)w - 1 : 0);
    ncplane_putstr_yx(u->sp, y, 0, line);
    int x = ncplane_cursor_x(u->sp);
    while (x < (int)w - 1) {
        ncplane_putchar(u->sp, ' ');
        x++;
    }
}

static void refresh_view(ui_t *u, int reset_sel) {
    if (u->vcap < u->ntasks + 1) {
        size_t nc = u->ntasks + 1;
        size_t *nv = realloc(u->view, nc * sizeof *nv);
        if (!nv)
            return;
        u->view = nv;
        u->vcap = nc;
    }
    u->nview = tasks_view(u->tasks, u->ntasks, (sort_mode_t)u->sort_idx,
                          u->query_n, u->view);
    if (reset_sel)
        u->top = u->sel = 0;
    if (u->nview == 0)
        u->sel = u->top = 0;
    else {
        if (u->sel >= u->nview)
            u->sel = u->nview - 1;
        if (u->top >= u->nview)
            u->top = u->nview - 1;
    }
}

static void load_tasks(ui_t *u) {
    tasks_free(u->tasks, u->ntasks);
    u->tasks = NULL;
    u->ntasks = 0;
    if (tasks_scan(&u->tasks, &u->ntasks) == 0) {
        u->top = u->sel = 0;
        refresh_view(u, 0);
    }
    if (u->ntasks == 0)
        snprintf(u->flash, sizeof u->flash, "nenhuma tarefa no vault");
    else if (u->query_n[0] && u->nview == 0)
        snprintf(u->flash, sizeof u->flash, "sem resultado; Esc limpa o filtro");
}

static void clamp_scroll(ui_t *u, unsigned h) {
    unsigned rows = h > 2 ? h - 2 : 1;
    if (u->sel < u->top)
        u->top = u->sel;
    else if (u->sel >= u->top + rows)
        u->top = u->sel - rows + 1;
    if (u->nview > rows && u->top > u->nview - rows)
        u->top = u->nview - rows;
}

static const char *relpath_of(const char *path) {
    const char *v = tasks_vault_dir();
    size_t n = strlen(v);
    if (strncmp(path, v, n) == 0 && path[n] == '/')
        return path + n + 1;
    return path;
}

static void draw_main(ui_t *u) {
    unsigned h, w;
    ncplane_dim_yx(u->sp, &h, &w);
    ncplane_erase(u->sp);
    if (h < 3 || w < 20) {
        notcurses_render(u->nc);
        return;
    }
    long open = 0;
    for (size_t i = 0; i < u->ntasks; i++)
        if (!u->tasks[i].done)
            open++;
    char head[1024], qshort[80];
    cut_cols(qshort, sizeof qshort, u->query, 40);
    if (u->query[0])
        snprintf(head, sizeof head, " Tarefas · %ld abertas / %zu · %s · /%s %zu/%zu ",
                 open, u->ntasks, SORT_LABEL[u->sort_idx], qshort, u->nview,
                 u->ntasks);
    else
        snprintf(head, sizeof head, " Tarefas · %ld abertas / %zu · %s ", open,
                 u->ntasks, SORT_LABEL[u->sort_idx]);
    row_colors(u, 1, 0);
    paint_row(u, 0, w, head);

    unsigned rows = h - 2;
    for (size_t r = 0; r < rows && u->top + r < u->nview; r++) {
        task_t *t = &u->tasks[u->view[u->top + r]];
        int sel = (u->top + r == u->sel);
        const char *rel = relpath_of(t->path);
        char shown[4096];
        snprintf(shown, sizeof shown, " %s %s", t->done ? "[x]" : "[ ]",
                 t->text);
        int maxrel = (int)w / 3;
        char relcut[1024];
        cut_cols(relcut, sizeof relcut, rel, maxrel > 16 ? maxrel : 16);
        int rcols = disp_width(relcut);
        int shown_cols = disp_width(shown);
        if (shown_cols > (int)w - 1 - rcols - 3)
            shown_cols = (int)w - 1 - rcols - 3;
        char vis[4096];
        cut_cols(vis, sizeof vis, shown,
                 shown_cols > 12 ? shown_cols : (int)w - 1);
        row_colors(u, sel, !sel && t->done);
        paint_row(u, (int)r + 1, w, vis);
        if (rcols + 2 < (int)w - disp_width(vis) &&
            (int)w - disp_width(vis) > 14) {
            row_colors(u, 0, 1);
            ncplane_putstr_yx(u->sp, (int)r + 1, (int)w - 1 - rcols, relcut);
        }
    }
    row_colors(u, 0, 1);
    paint_row(u, (int)h - 1, w, HELP);
    if (u->flash[0]) {
        int fcols = disp_width(u->flash);
        row_colors(u, 1, 0);
        ncplane_putstr_yx(u->sp, (int)h - 1, (int)w - 1 - fcols, u->flash);
        u->flash[0] = 0;
    }
    notcurses_render(u->nc);
}

/* Tecla bloqueante, ignorando release (protocolo Kitty repete o evento). */
static uint32_t get_key(ui_t *u, ncinput *ni) {
    for (;;) {
        ncinput tmp;
        uint32_t id = notcurses_get_blocking(u->nc, ni ? ni : &tmp);
        ncinput *e = ni ? ni : &tmp;
        if (id == (uint32_t)-1)
            continue;
        if (e->evtype == NCTYPE_RELEASE)
            continue;
        return id;
    }
}

/* Input inline no rodapé; devolve malloc (trim) ou NULL (cancelou/vazio). */
static char *read_line(ui_t *u, const char *prompt) {
    unsigned h, w;
    char buf[1024] = {0};
    size_t len = 0;
    for (;;) {
        ncplane_dim_yx(u->sp, &h, &w);
        draw_main(u);
        row_colors(u, 1, 0);
        paint_row(u, (int)h - 1, w, prompt);
        int px = disp_width(prompt);
        ncplane_putstr_yx(u->sp, (int)h - 1, px, buf);
        notcurses_cursor_enable(u->nc, (int)h - 1, px + disp_width(buf));
        notcurses_render(u->nc);
        uint32_t id = get_key(u, NULL);
        if (id == NCKEY_ESC) {
            notcurses_cursor_disable(u->nc);
            return NULL;
        }
        if (id == NCKEY_ENTER || id == 10 || id == 13) {
            notcurses_cursor_disable(u->nc);
            while (len && (buf[len - 1] == ' ' || buf[len - 1] == '\t'))
                buf[--len] = 0;
            size_t s = 0;
            while (buf[s] == ' ' || buf[s] == '\t')
                s++;
            if (!buf[s])
                return NULL;
            return strdup(buf + s);
        }
        if (id == NCKEY_BACKSPACE || id == 127 || id == 8) {
            while (len && (buf[len - 1] & 0xC0) == 0x80)
                len--;
            if (len)
                len--;
            buf[len] = 0;
            continue;
        }
        if (!nckey_synthesized_p(id) && id >= 0x20 && id < 0x110000) {
            char enc[4];
            size_t el = tasks_utf8_encode(id, enc);
            if (len + el < sizeof buf) {
                memcpy(buf + len, enc, el);
                len += el;
                buf[len] = 0;
            }
        }
    }
}

/* apara espaços ASCII nas bordas (paridade query.strip() do .py) */
static void strip_q(char *q) {
    size_t s = 0;
    while (q[s] == ' ' || q[s] == '\t')
        s++;
    if (s) {
        size_t l = strlen(q + s) + 1;
        memmove(q, q + s, l);
    }
    size_t l = strlen(q);
    while (l && (q[l - 1] == ' ' || q[l - 1] == '\t'))
        q[--l] = 0;
}

static void do_search(ui_t *u) {
    char prev[sizeof u->query], prevn[sizeof u->query_n];
    memcpy(prev, u->query, sizeof prev);
    memcpy(prevn, u->query_n, sizeof prevn);
    unsigned h, w;
    char sq[sizeof u->query]; /* query aparada p/ norm (paridade .strip()) */
    for (;;) {
        ncplane_dim_yx(u->sp, &h, &w);
        snprintf(sq, sizeof sq, "%s", u->query);
        strip_q(sq);
        tasks_norm(sq, u->query_n, sizeof u->query_n);
        refresh_view(u, 1);
        draw_main(u);
        row_colors(u, 1, 0);
        paint_row(u, (int)h - 1, w, " buscar: ");
        int px = disp_width(" buscar: ");
        ncplane_putstr_yx(u->sp, (int)h - 1, px, u->query);
        notcurses_cursor_enable(u->nc, (int)h - 1, px + disp_width(u->query));
        notcurses_render(u->nc);
        uint32_t id = get_key(u, NULL);
        if (id == NCKEY_ENTER || id == 10 || id == 13) {
            notcurses_cursor_disable(u->nc);
            snprintf(sq, sizeof sq, "%s", u->query);
            strip_q(sq);
            tasks_norm(sq, u->query_n, sizeof u->query_n);
            refresh_view(u, 1);
            if (!u->query_n[0]) {
                u->query[0] = 0;
                snprintf(u->flash, sizeof u->flash, "filtro limpo");
            } else {
                char qs[80];
                cut_cols(qs, sizeof qs, u->query, 40);
                snprintf(u->flash, sizeof u->flash,
                         "%zu resultado(s) p/ “%s”", u->nview, qs);
            }
            return;
        }
        if (id == NCKEY_ESC) {
            memcpy(u->query, prev, sizeof prev);
            memcpy(u->query_n, prevn, sizeof prevn);
            refresh_view(u, 1);
            notcurses_cursor_disable(u->nc);
            snprintf(u->flash, sizeof u->flash, "busca cancelada");
            return;
        }
        size_t len = strlen(u->query);
        if (id == NCKEY_BACKSPACE || id == 127 || id == 8) {
            while (len && (u->query[len - 1] & 0xC0) == 0x80)
                len--;
            if (len)
                len--;
            u->query[len] = 0;
            continue;
        }
        if (!nckey_synthesized_p(id) && id >= 0x20 && id < 0x110000) {
            char enc[4];
            size_t el = tasks_utf8_encode(id, enc);
            if (len + el < sizeof u->query) {
                memcpy(u->query + len, enc, el);
                u->query[len + el] = 0;
            }
        }
    }
}

static void open_obsidian(ui_t *u, const char *path) {
    char *abs = NULL;
    if (path[0] == '/') { /* abspath sem resolver symlink (paridade .py) */
        abs = strdup(path);
    } else {
        char cwd[4096];
        if (getcwd(cwd, sizeof cwd))
            asprintf(&abs, "%s/%s", cwd, path);
        else
            abs = strdup(path);
    }
    if (!abs) {
        snprintf(u->flash, sizeof u->flash, "sem memória");
        return;
    }
    char uri[12400]; /* 21 + 3x PATH_MAX cabem com folga */
    size_t o = 0;
    o += (size_t)snprintf(uri + o, sizeof uri - o, "obsidian://open?path=");
    for (const char *p = abs; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' ||
            c == '~') {
            uri[o++] = (char)c;
        } else {
            if (o + 4 >= sizeof uri) {
                snprintf(u->flash, sizeof u->flash, "caminho muito longo");
                return;
            }
            o += (size_t)snprintf(uri + o, sizeof uri - o, "%%%02X", c);
        }
    }
    uri[o] = 0;
    pid_t pid = fork();
    if (pid == 0) {
        int dev = open("/dev/null", O_RDWR);
        if (dev >= 0) {
            dup2(dev, 0);
            dup2(dev, 1);
            dup2(dev, 2);
            if (dev > 2)
                close(dev);
        }
        execlp("xdg-open", "xdg-open", uri, (char *)NULL);
        _exit(127);
    }
    if (pid > 0) {
        int st = 0;
        while (waitpid(pid, &st, 0) < 0)
            ;
        snprintf(u->flash, sizeof u->flash, "aberta no Obsidian");
    }
    free(abs);
}

static void do_toggle(ui_t *u) {
    if (!u->nview)
        return;
    task_t *t = &u->tasks[u->view[u->sel]];
    char newtext[4096];
    if (strlen(t->text) + 64 >= sizeof newtext) {
        snprintf(u->flash, sizeof u->flash, "linha muito longa; edite na nota");
        return;
    }
    if (t->done)
        tasks_reopen(t->text, newtext, sizeof newtext);
    else
        tasks_complete(t->text, newtext, sizeof newtext);
    if (tasks_write(t->path, t->line, !t->done, newtext)) {
        struct stat st;
        char *ntxt = strdup(newtext);
        size_t nn = strlen(newtext) * 2 + 1;
        char *nnorm = realloc(t->ntext, nn);
        if (!ntxt || !nnorm) {
            free(ntxt); /* ntext original intacto se realloc falhou */
            load_tasks(u);
            snprintf(u->flash, sizeof u->flash, "sem memória; recarregado");
            return;
        }
        free(t->text);
        t->text = ntxt;
        t->ntext = nnorm;
        t->done = !t->done;
        tasks_created_at(t->text, t->path, t->created);
        tasks_norm(t->text, t->ntext, nn);
        if (stat(t->path, &st) == 0)
            t->mtime = (long)st.st_mtime;
        refresh_view(u, 0);
        for (size_t i = 0; i < u->nview; i++) {
            task_t *c = &u->tasks[u->view[i]];
            if (c->line == t->line && strcmp(c->path, t->path) == 0) {
                u->sel = i;
                break;
            }
        }
        snprintf(u->flash, sizeof u->flash,
                 t->done ? "concluída ✅" : "reaberta");
    } else {
        load_tasks(u);
        snprintf(u->flash, sizeof u->flash,
                 "arquivo mudou no disco; recarregado");
    }
}

/* Quebra por palavras em largura maxw (palavra longa é cortada). */
static size_t wrap_text(const char *text, int maxw, char lines[][1024],
                        size_t maxlines) {
    size_t n = 0;
    char cur[1024] = {0};
    int curw = 0;
    const char *p = text;
    while (*p && n < maxlines) {
        while (*p == ' ' || *p == '\t')
            p++;
        if (!*p)
            break;
        const char *e = p;
        while (*e && *e != ' ' && *e != '\t')
            e++;
        /* palavra [p,e): cabe? senão quebra por coluna */
        const char *q = p;
        while (q < e && n < maxlines) {
            int ww = 0;
            const char *r = q;
            char piece[1024];
            size_t o = 0;
            while (r < e && o + 8 < sizeof piece) {
                const char *start = r;
                uint32_t cp = 0;
                int cw = 0;
                next_cp(&r, &cp, &cw);
                (void)cp;
                size_t l = (size_t)(r - start);
                if (curw + (cur[0] ? 1 : 0) + ww + cw > maxw) {
                    if (cur[0]) {
                        snprintf(lines[n++], 1024, "%s", cur);
                        if (n >= maxlines)
                            break;
                    }
                    cur[0] = 0;
                    curw = 0;
                    ww = 0;
                    o = 0;
                    piece[0] = 0;
                }
                memcpy(piece + o, start, l);
                o += l;
                piece[o] = 0;
                ww += cw;
            }
            if (n >= maxlines)
                break;
            if (cur[0]) {
                size_t cl = strlen(cur);
                if (cl + 1 + strlen(piece) < sizeof cur)
                    snprintf(cur + cl, sizeof cur - cl, " %s", piece);
                curw += 1 + ww;
            } else {
                snprintf(cur, sizeof cur, "%s", piece);
                curw = ww;
            }
            q = e;
        }
    }
    if (cur[0] && n < maxlines)
        snprintf(lines[n++], 1024, "%s", cur);
    return n;
}

static void do_details(ui_t *u) {
    if (!u->nview)
        return;
    task_t *t = &u->tasks[u->view[u->sel]];
    char created[17], doneat[17];
    tasks_created_at(t->text, t->path, created);
    tasks_done_at(t->text, doneat);
    unsigned h, w;
    ncplane_dim_yx(u->sp, &h, &w);
    int inner = (int)w - 10;
    if (inner < 20)
        inner = 20;
    if (inner > 100)
        inner = 100;
    static char tlines[64][1024];
    char full[4096];
    snprintf(full, sizeof full, " %s", t->text);
    size_t nt = wrap_text(full, inner - 4, tlines, 64);
    char info[4][1024];
    snprintf(info[0], sizeof info[0], "  criada: %s%s", created,
             tasks_has_created(t->text) ? "" : " (birth do arquivo)");
    snprintf(info[1], sizeof info[1], "  concluída: %s",
             doneat[0] ? doneat : "—");
    snprintf(info[2], sizeof info[2], "  arquivo: %s:%d", relpath_of(t->path),
             t->line);
    snprintf(info[3], sizeof info[3], "  qualquer tecla volta");
    int maxl = 10;
    for (size_t i = 0; i < nt; i++) {
        int c = disp_width(tlines[i]);
        if (c > maxl)
            maxl = c;
    }
    for (int i = 0; i < 4; i++) {
        int c = disp_width(info[i]);
        if (c > maxl)
            maxl = c;
    }
    int pw = maxl + 6;
    if (pw > (int)w - 2)
        pw = (int)w - 2;
    int ph = (int)nt + 4 + 2;
    if (ph > (int)h - 1)
        ph = (int)h - 1;
    int py = ((int)h - ph) / 2;
    int px = ((int)w - pw) / 2;
    if (py < 0)
        py = 0;
    if (px < 0)
        px = 0;
    row_colors(u, 1, 0);
    for (int y = 0; y < ph; y++) {
        ncplane_cursor_move_yx(u->sp, py + y, px);
        for (int x = 0; x < pw; x++)
            ncplane_putchar(u->sp, ' ');
    }
    /* borda */
    ncplane_putstr_yx(u->sp, py, px, "┌");
    for (int x = 1; x < pw - 1; x++)
        ncplane_putstr_yx(u->sp, py, px + x, "─");
    ncplane_putstr_yx(u->sp, py, px + pw - 1, "┐");
    ncplane_putstr_yx(u->sp, py + ph - 1, px, "└");
    for (int x = 1; x < pw - 1; x++)
        ncplane_putstr_yx(u->sp, py + ph - 1, px + x, "─");
    ncplane_putstr_yx(u->sp, py + ph - 1, px + pw - 1, "┘");
    for (int y = 1; y < ph - 1; y++) {
        ncplane_putstr_yx(u->sp, py + y, px, "│");
        ncplane_putstr_yx(u->sp, py + y, px + pw - 1, "│");
    }
    ncplane_set_styles(u->sp, NCSTYLE_BOLD);
    for (size_t i = 0; i < nt && (int)i + 1 < ph - 1; i++)
        ncplane_putstr_yx(u->sp, py + 1 + (int)i, px + 2, tlines[i]);
    row_colors(u, 1, 0);
    for (int i = 0; i < 4 && (int)nt + 1 + i < ph - 1; i++)
        ncplane_putstr_yx(u->sp, py + 1 + (int)nt + i, px + 2, info[i]);
    notcurses_render(u->nc);
    get_key(u, NULL);
}

static void run_ui(void) {
    ui_t u;
    memset(&u, 0, sizeof u);
    u.pal = load_palette();
    struct notcurses_options opts = {0};
    opts.flags = NCOPTION_SUPPRESS_BANNERS;
    u.nc = notcurses_init(&opts, NULL);
    if (!u.nc) {
        fprintf(stderr, "notcurses indisponível (TERM/LANG?)\n");
        exit(1);
    }
    u.sp = notcurses_stdplane(u.nc);
    notcurses_cursor_disable(u.nc);
    load_tasks(&u);
    for (;;) {
        unsigned h;
        ncplane_dim_yx(u.sp, &h, NULL);
        draw_main(&u);
        uint32_t id = get_key(&u, NULL);
        if (id == 'q')
            break;
        if (id == NCKEY_ESC) {
            if (u.query_n[0]) {
                u.query[0] = u.query_n[0] = 0;
                refresh_view(&u, 1);
                snprintf(u.flash, sizeof u.flash, "filtro limpo");
                continue;
            }
            break;
        }
        if ((id == NCKEY_UP || id == 'k') && u.nview) {
            if (u.sel > 0)
                u.sel--;
        } else if ((id == NCKEY_DOWN || id == 'j') && u.nview) {
            if (u.sel + 1 < u.nview)
                u.sel++;
        } else if (id == ' ') {
            do_toggle(&u);
        } else if ((id == NCKEY_ENTER || id == 10 || id == 13) && u.nview) {
            open_obsidian(&u, u.tasks[u.view[u.sel]].path);
        } else if (id == 'r') {
            load_tasks(&u);
            snprintf(u.flash, sizeof u.flash, "recarregado");
        } else if (id == 'o') {
            u.sort_idx = (u.sort_idx + 1) % 5;
            refresh_view(&u, 0);
            snprintf(u.flash, sizeof u.flash, "ordem: %s",
                     SORT_LABEL[u.sort_idx]);
        } else if (id == '/') {
            do_search(&u);
        } else if (id == 'd') {
            do_details(&u);
        } else if (id == 'n') {
            char *title = read_line(&u, " nova tarefa: ");
            if (title) {
                if (tasks_append(title)) {
                    load_tasks(&u);
                    snprintf(u.flash, sizeof u.flash, "criada");
                } else {
                    snprintf(u.flash, sizeof u.flash, "falha ao gravar");
                }
                free(title);
            }
        }
        ncplane_dim_yx(u.sp, &h, NULL);
        clamp_scroll(&u, h);
    }
    free(u.view);
    tasks_free(u.tasks, u.ntasks);
    notcurses_stop(u.nc);
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--count") == 0) {
        long n = tasks_count_open();
        printf("%ld\n", n < 0 ? 0 : n);
        return 0;
    }
    if (argc > 1 && strcmp(argv[1], "--selftest") == 0)
        return tasks_selftest() ? 1 : 0;
    const char *vault = tasks_vault_dir();
    struct stat st;
    if (!vault[0] || stat(vault, &st) != 0 || !S_ISDIR(st.st_mode)) {
        fprintf(stderr, "vault ausente: %s\n", vault);
        return 1;
    }
    setlocale(LC_ALL, "");
    run_ui();
    return 0;
}
