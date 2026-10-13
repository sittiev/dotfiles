/* yambar-dirs.c -- TUI de diretórios fixados em C/notcurses.
 *
 * Paridade com yambar-dirs.py: estado em ~/.cache/dirs-pinadas (uma path
 * por linha), Enter abre no gerenciador padrão, a fixa (pede a path,
 * valida, normaliza sem trailing /), d remove, r recarrega, q/Esc sai.
 *
 * Flags não-interativas p/ teste: --list, --add PATH, --remove PATH.
 * Paleta: ~/.cache/theme-palette.<mode> (contrato do render.sh).
 * Lançado por yambar-dirs-toggle.sh como `foot -a yambar-dirs`.
 */
#define _GNU_SOURCE /* asprintf, getpwnam */
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <locale.h>
#include <fcntl.h>
#include <notcurses/nckeys.h>
#include <notcurses/notcurses.h>
#include <pwd.h>
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

static const char HELP[] =
    "↑↓ mover  Enter: abrir  a: fixar  d: remover  r: recarregar  q: sair";

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

/* -- estado ------------------------------------------------------------ */

static void state_path(char out[4096]) {
    const char *home = getenv("HOME") ? getenv("HOME") : "";
    snprintf(out, 4096, "%s/.cache/dirs-pinadas", home);
}

/* $VAR/${VAR} (paridade expandvars); ~ e ~user (getpwnam). */
static void expand_vars(const char *in, char *out, size_t outn) {
    size_t o = 0;
    for (const char *p = in; *p && o + 1 < outn;) {
        if (*p == '~' && (p == in || p[-1] == '/')) {
            const char *e = p + 1;
            while (*e && *e != '/')
                e++;
            if (e == p + 1) {
                const char *home = getenv("HOME") ? getenv("HOME") : "";
                size_t hl = strlen(home);
                if (o + hl >= outn)
                    break;
                memcpy(out + o, home, hl);
                o += hl;
            } else {
                char user[256];
                size_t ul = (size_t)(e - p - 1);
                if (ul >= sizeof user)
                    ul = sizeof user - 1;
                memcpy(user, p + 1, ul);
                user[ul] = 0;
                struct passwd *pw = getpwnam(user);
                const char *hd = pw ? pw->pw_dir : NULL;
                if (hd) {
                    size_t hl = strlen(hd);
                    if (o + hl >= outn)
                        break;
                    memcpy(out + o, hd, hl);
                    o += hl;
                } else {
                    size_t tl = (size_t)(e - p);
                    if (o + tl >= outn)
                        break;
                    memcpy(out + o, p, tl);
                    o += tl;
                }
            }
            p = e;
            continue;
        }
        if (*p == '$') {
            const char *e = NULL;
            char var[256] = {0};
            if (p[1] == '{') {
                e = strchr(p + 2, '}');
                if (e) {
                    size_t vl = (size_t)(e - p - 2);
                    if (vl >= sizeof var)
                        vl = sizeof var - 1;
                    memcpy(var, p + 2, vl);
                    var[vl] = 0;
                    e++;
                }
            } else {
                e = p + 1;
                while ((*e >= 'A' && *e <= 'Z') || (*e >= 'a' && *e <= 'z') ||
                       (*e >= '0' && *e <= '9') || *e == '_')
                    e++;
                size_t vl = (size_t)(e - p - 1);
                if (vl >= sizeof var)
                    vl = sizeof var - 1;
                memcpy(var, p + 1, vl);
                var[vl] = 0;
            }
            if (var[0] || (p[1] == '{' && e)) {
                const char *v = getenv(var);
                if (!v)
                    v = "";
                size_t vl = strlen(v);
                if (o + vl >= outn)
                    break;
                memcpy(out + o, v, vl);
                o += vl;
                p = e; /* não-NULL aqui: var[0] implica parse ok */
                continue;
            }
        }
        out[o++] = *p++;
    }
    out[o] = 0;
}

/* aparar bordas (paridade l.strip() do .py) */
static void trim(char *s) {
    size_t a = 0;
    while (s[a] == ' ' || s[a] == '\t' || s[a] == '\r' || s[a] == '\n')
        a++;
    if (a) {
        size_t l = strlen(s + a) + 1;
        memmove(s, s + a, l);
    }
    size_t l = strlen(s);
    while (l && (s[l - 1] == ' ' || s[l - 1] == '\t' || s[l - 1] == '\r' ||
                 s[l - 1] == '\n'))
        s[--l] = 0;
}

static char **load_dirs(size_t *n);
static int write_dirs(char **dirs, size_t n);

static void ensure_defaults(void) {
    char sp[4096];
    state_path(sp);
    struct stat st;
    if (stat(sp, &st) == 0)
        return;
    const char *home = getenv("HOME") ? getenv("HOME") : "";
    char d0[4096], d1[4096], d2[4096], d3[4096];
    snprintf(d0, sizeof d0, "%s/Documentos/Vault", home);
    snprintf(d1, sizeof d1, "%s/dotfiles", home);
    snprintf(d2, sizeof d2, "%s/Documentos", home);
    snprintf(d3, sizeof d3, "%s/Downloads", home);
    char *defs[] = {d0, d1, d2, d3};
    write_dirs(defs, 4);
}

static char **load_dirs(size_t *n) {
    ensure_defaults();
    char sp[4096];
    state_path(sp);
    FILE *f = fopen(sp, "r");
    char **v = NULL;
    size_t nn = 0, cap = 0;
    if (!f) {
        *n = 0;
        return NULL;
    }
    char *line = NULL;
    size_t lcap = 0;
    while (getline(&line, &lcap, f) >= 0) {
        trim(line);
        if (!line[0])
            continue;
        if (nn == cap) {
            size_t nc = cap ? cap * 2 : 16;
            char **nv = realloc(v, nc * sizeof *nv);
            if (!nv)
                break;
            v = nv;
            cap = nc;
        }
        v[nn] = strdup(line);
        if (!v[nn])
            break;
        nn++;
    }
    free(line);
    fclose(f);
    *n = nn;
    return v;
}

static void free_dirs(char **v, size_t n) {
    for (size_t i = 0; i < n; i++)
        free(v[i]);
    free(v);
}

static int write_dirs(char **dirs, size_t n) {
    char sp[4096], tmp[8192];
    state_path(sp);
    snprintf(tmp, sizeof tmp, "%s.yambar-dirs.tmp", sp);
    char *slash = strrchr(tmp, '/');
    if (slash) {
        char save = *slash;
        *slash = 0;
        mkdir(tmp, 0755);
        *slash = save;
    }
    struct stat st;
    int have = stat(sp, &st) == 0;
    FILE *f = fopen(tmp, "w");
    if (!f)
        return 0;
    for (size_t i = 0; i < n; i++)
        fprintf(f, "%s\n", dirs[i]);
    int ok = fclose(f) == 0;
    if (ok) {
        if (have)
            chmod(tmp, st.st_mode & 07777);
        ok = rename(tmp, sp) == 0;
    }
    if (!ok)
        unlink(tmp);
    return ok;
}

/* Expande, resolve e tira trailing /; "" se não é diretório. */
static void normalize(const char *path, char out[4096]) {
    out[0] = 0;
    char exp[4096], t[4096];
    snprintf(exp, sizeof exp, "%s", path);
    trim(exp);
    expand_vars(exp, t, sizeof t);
    struct stat st;
    if (stat(t, &st) != 0 || !S_ISDIR(st.st_mode))
        return;
    char *rp = realpath(t, NULL);
    if (!rp)
        return;
    snprintf(out, 4096, "%s", rp);
    free(rp);
}

static int add_dir(const char *path) {
    char real[4096];
    normalize(path, real);
    if (!real[0])
        return 0;
    size_t n = 0;
    char **dirs = load_dirs(&n);
    for (size_t i = 0; i < n; i++) {
        if (strcmp(dirs[i], real) == 0) {
            free_dirs(dirs, n);
            return 1;
        }
    }
    char **nv = realloc(dirs, (n + 1) * sizeof *nv);
    if (!nv) {
        free_dirs(dirs, n);
        return 0;
    }
    nv[n] = strdup(real);
    if (!nv[n]) {
        free(nv);
        return 0;
    }
    int ok = write_dirs(nv, n + 1);
    /* write_dirs não assume: libera aqui */
    for (size_t i = 0; i < n + 1; i++)
        free(nv[i]);
    free(nv);
    return ok;
}

static int remove_dir(const char *path) {
    size_t n = 0;
    char **dirs = load_dirs(&n);
    char **keep = malloc(n * sizeof *keep);
    if (n && !keep) {
        free_dirs(dirs, n);
        return 0;
    }
    size_t m = 0;
    for (size_t i = 0; i < n; i++) {
        if (strcmp(dirs[i], path) == 0) {
            free(dirs[i]);
            continue;
        }
        keep[m++] = dirs[i];
    }
    free(dirs);
    int ok = write_dirs(keep, m);
    for (size_t i = 0; i < m; i++)
        free(keep[i]);
    free(keep);
    return ok;
}

static void short_home(const char *path, char out[4096]) {
    const char *home = getenv("HOME") ? getenv("HOME") : "";
    size_t hl = strlen(home);
    if (hl && strncmp(path, home, hl) == 0)
        snprintf(out, 4096, "~%s", path + hl);
    else
        snprintf(out, 4096, "%s", path);
}

/* -- UI ------------------------------------------------------------------ */

typedef struct {
    struct notcurses *nc;
    struct ncplane *sp;
    pal_t pal;
    char **dirs;
    size_t ndirs;
    size_t sel, top;
    char flash[256];
    char selfdir[4096]; /* dir do binário (file-manager.sh mora ao lado) */
} dui_t;

static void pal_rgb(uint32_t v, unsigned *r, unsigned *g, unsigned *b) {
    *r = (v >> 16) & 255;
    *g = (v >> 8) & 255;
    *b = v & 255;
}

static void row_colors(dui_t *u, int sel, int help) {
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

static void cut_cols(char *dst, size_t dstn, const char *src, int maxcols) {
    size_t o = 0;
    int w = 0, cut = 0;
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

static void paint_row(dui_t *u, int y, unsigned w, const char *s) {
    char line[4096];
    cut_cols(line, sizeof line, s, (int)w - 1 > 0 ? (int)w - 1 : 0);
    ncplane_putstr_yx(u->sp, y, 0, line);
    int x = ncplane_cursor_x(u->sp);
    while (x < (int)w - 1) {
        ncplane_putchar(u->sp, ' ');
        x++;
    }
}

static void load(dui_t *u) {
    free_dirs(u->dirs, u->ndirs);
    u->dirs = load_dirs(&u->ndirs);
    u->top = u->sel = 0;
}

static void clamp_scroll(dui_t *u, unsigned h) {
    unsigned rows = h > 2 ? h - 2 : 1;
    if (u->ndirs == 0) {
        u->top = u->sel = 0;
        return;
    }
    if (u->sel >= u->ndirs)
        u->sel = u->ndirs - 1;
    if (u->sel < u->top)
        u->top = u->sel;
    else if (u->sel >= u->top + rows)
        u->top = u->sel - rows + 1;
    if (u->ndirs > rows && u->top > u->ndirs - rows)
        u->top = u->ndirs - rows;
}

static void draw(dui_t *u) {
    unsigned h, w;
    ncplane_dim_yx(u->sp, &h, &w);
    ncplane_erase(u->sp);
    if (h < 3 || w < 20) {
        notcurses_render(u->nc);
        return;
    }
    char head[256];
    snprintf(head, sizeof head, " Diretórios · %zu fixados ", u->ndirs);
    row_colors(u, 1, 0);
    paint_row(u, 0, w, head);
    unsigned rows = h - 2;
    for (size_t r = 0; r < rows && u->top + r < u->ndirs; r++) {
        char sh[4096], shown[8192];
        short_home(u->dirs[u->top + r], sh);
        snprintf(shown, sizeof shown, " %s", sh);
        struct stat st;
        int missing = stat(u->dirs[u->top + r], &st) != 0 ||
                      !S_ISDIR(st.st_mode);
        row_colors(u, (int)(u->top + r == u->sel), missing);
        paint_row(u, (int)r + 1, w, shown);
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

static uint32_t get_key(dui_t *u) {
    for (;;) {
        ncinput ni;
        uint32_t id = notcurses_get_blocking(u->nc, &ni);
        if (id == (uint32_t)-1)
            continue;
        if (ni.evtype == NCTYPE_RELEASE)
            continue;
        return id;
    }
}

static char *read_line(dui_t *u, const char *prompt) {
    unsigned h, w;
    char buf[1024] = {0};
    size_t len = 0;
    for (;;) {
        ncplane_dim_yx(u->sp, &h, &w);
        draw(u);
        row_colors(u, 1, 0);
        paint_row(u, (int)h - 1, w, prompt);
        int px = disp_width(prompt);
        ncplane_putstr_yx(u->sp, (int)h - 1, px, buf);
        notcurses_cursor_enable(u->nc, (int)h - 1, px + disp_width(buf));
        notcurses_render(u->nc);
        uint32_t id = get_key(u);
        if (id == NCKEY_ESC) {
            notcurses_cursor_disable(u->nc);
            return NULL;
        }
        if (id == NCKEY_ENTER || id == 10 || id == 13) {
            notcurses_cursor_disable(u->nc);
            char t[sizeof buf];
            snprintf(t, sizeof t, "%s", buf);
            trim(t);
            if (!t[0])
                return NULL;
            return strdup(t);
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

static void open_dir(dui_t *u, const char *path) {
    struct stat st;
    if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
        char sh[4096], shc[128];
        short_home(path, sh);
        cut_cols(shc, sizeof shc, sh, 40);
        snprintf(u->flash, sizeof u->flash, "ausente: %s", shc);
        return;
    }
    char fm[8192];
    snprintf(fm, sizeof fm, "%s/file-manager.sh", u->selfdir);
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
        execl(fm, fm, "open", path, (char *)NULL);
        _exit(127);
    }
    if (pid > 0) {
        int stw = 0;
        while (waitpid(pid, &stw, 0) < 0)
            ;
        snprintf(u->flash, sizeof u->flash, "aberto no gerenciador");
    }
}

static void run_ui(dui_t *u) {
    load(u);
    for (;;) {
        unsigned h;
        ncplane_dim_yx(u->sp, &h, NULL);
        draw(u);
        uint32_t id = get_key(u);
        if (id == 'q' || id == NCKEY_ESC)
            break;
        if ((id == NCKEY_UP || id == 'k') && u->ndirs) {
            if (u->sel > 0)
                u->sel--;
        } else if ((id == NCKEY_DOWN || id == 'j') && u->ndirs) {
            if (u->sel + 1 < u->ndirs)
                u->sel++;
        } else if ((id == NCKEY_ENTER || id == 10 || id == 13) && u->ndirs) {
            open_dir(u, u->dirs[u->sel]);
        } else if (id == 'r') {
            load(u);
            snprintf(u->flash, sizeof u->flash, "recarregado");
        } else if (id == 'a' || id == '+') {
            char *np = read_line(u, " fixar diretório: ");
            if (np) {
                char real[4096];
                normalize(np, real);
                if (!real[0]) {
                    char npc[128];
                    cut_cols(npc, sizeof npc, np, 40);
                    snprintf(u->flash, sizeof u->flash,
                             "não é um diretório: %s", npc);
                } else if (add_dir(real)) {
                    load(u);
                    snprintf(u->flash, sizeof u->flash, "fixado");
                } else {
                    snprintf(u->flash, sizeof u->flash, "falha ao gravar");
                }
                free(np);
            }
        } else if ((id == 'd' || id == '-') && u->ndirs) {
            if (remove_dir(u->dirs[u->sel])) {
                load(u);
                snprintf(u->flash, sizeof u->flash, "removido");
            } else {
                snprintf(u->flash, sizeof u->flash, "falha ao gravar");
            }
        }
        ncplane_dim_yx(u->sp, &h, NULL);
        clamp_scroll(u, h);
    }
}

int main(int argc, char **argv) {
    /* flags primeiro: sem TTY, sem nc init */
    if (argc > 1 && strcmp(argv[1], "--list") == 0) {
        size_t n = 0;
        char **d = load_dirs(&n);
        for (size_t i = 0; i < n; i++)
            printf("%s\n", d[i]);
        free_dirs(d, n);
        return 0;
    }
    if (argc > 1 && strcmp(argv[1], "--add") == 0) {
        const char *p = argc > 2 ? argv[2] : "";
        if (add_dir(p))
            return 0;
        fprintf(stderr, "não é um diretório: %s\n", p);
        return 1;
    }
    if (argc > 1 && strcmp(argv[1], "--remove") == 0) {
        /* paridade .py: realpath sem checar isdir */
        const char *p = argc > 2 ? argv[2] : "";
        char exp[4096], real[4096] = {0};
        snprintf(exp, sizeof exp, "%s", p);
        trim(exp);
        expand_vars(exp, real, sizeof real);
        if (real[0]) {
            char *rp = realpath(real, NULL);
            if (rp) {
                snprintf(real, sizeof real, "%s", rp);
                free(rp);
            } else if (real[0] != '/') {
                /* realpath libc falha p/ inexistente (py não falha):
                 * abspath manual p/ mesma semântica */
                char cwd[4096];
                if (getcwd(cwd, sizeof cwd)) {
                    size_t need = strlen(cwd) + 1 + strlen(real) + 1;
                    if (need > sizeof real) {
                        fprintf(stderr, "caminho muito longo\n");
                        return 1;
                    }
                    char tmp[8192];
                    snprintf(tmp, sizeof tmp, "%s/%s", cwd, real);
                    memcpy(real, tmp, need);
                }
            }
        }
        return remove_dir(real) ? 0 : 1;
    }

    dui_t u;
    memset(&u, 0, sizeof u);
    u.pal = load_palette();
    /* file-manager.sh mora ao lado do binário */
    ssize_t lr = readlink("/proc/self/exe", u.selfdir, sizeof u.selfdir - 1);
    if (lr > 0) {
        u.selfdir[lr] = 0;
        char *sl = strrchr(u.selfdir, '/');
        if (sl)
            *sl = 0;
    } else {
        snprintf(u.selfdir, sizeof u.selfdir, ".");
    }
    setlocale(LC_ALL, "");
    struct notcurses_options opts = {0};
    opts.flags = NCOPTION_SUPPRESS_BANNERS;
    u.nc = notcurses_init(&opts, NULL);
    if (!u.nc) {
        fprintf(stderr, "notcurses indisponível (TERM/LANG?)\n");
        return 1;
    }
    u.sp = notcurses_stdplane(u.nc);
    notcurses_cursor_disable(u.nc);
    run_ui(&u);
    free_dirs(u.dirs, u.ndirs);
    notcurses_stop(u.nc);
    return 0;
}
