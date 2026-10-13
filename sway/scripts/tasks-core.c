/* tasks-core.c -- backend da TUI de tarefas, C puro (só libc).
 *
 * Contrato herdado do yambar-tasks.py: mesma exclusão de pastas, fence
 * ``` , carimbos "➕ YYYY-MM-DD HH:MM" / "✅ YYYY-MM-DD HH:MM", escrita
 * atômica e ordenação (abertas primeiro).
 */
#define _GNU_SOURCE /* statx, asprintf */
#define _POSIX_C_SOURCE 200809L /* getline, strdup, strnlen */

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "tasks-core.h"

#define DONE_GLYPH "\xE2\x9C\x85"   /* ✅ U+2705 */
#define BIRTH_GLYPH "\xE2\x9E\x95"  /* ➕ U+2795 */

static const char *const EXCLUDE[] = {
    "Arquivo", "Memória de Agentes", "Recursos/AI",
    ".obsidian", ".agents", ".trash", "Excalidraw",
};

const char *tasks_vault_dir(void) {
    static char buf[4096];
    const char *e = getenv("VAULT_DIR");
    if (e && e[0]) {
        snprintf(buf, sizeof buf, "%s", e);
        return buf;
    }
    e = getenv("HOME");
    if (!e || !e[0])
        return "";
    snprintf(buf, sizeof buf, "%s/Documentos/Vault", e);
    return buf;
}

/* -- UTF-8 ------------------------------------------------------------- */

static uint32_t utf8_dec(const char *s, size_t *len) {
    unsigned char c = (unsigned char)s[0];
    if (c < 0x80) {
        *len = 1;
        return c;
    }
    if ((c & 0xE0) == 0xC0 && (s[1] & 0xC0) == 0x80) {
        *len = 2;
        return ((uint32_t)(c & 0x1F) << 6) | (s[1] & 0x3F);
    }
    if ((c & 0xF0) == 0xE0 && (s[1] & 0xC0) == 0x80 &&
        (s[2] & 0xC0) == 0x80) {
        *len = 3;
        return ((uint32_t)(c & 0x0F) << 12) | ((uint32_t)(s[1] & 0x3F) << 6) |
               (s[2] & 0x3F);
    }
    if ((c & 0xF8) == 0xF0 && (s[1] & 0xC0) == 0x80 &&
        (s[2] & 0xC0) == 0x80 && (s[3] & 0xC0) == 0x80) {
        *len = 4;
        return ((uint32_t)(c & 0x07) << 18) | ((uint32_t)(s[1] & 0x3F) << 12) |
               ((uint32_t)(s[2] & 0x3F) << 6) | (s[3] & 0x3F);
    }
    *len = 1; /* byte inválido: passa adiante, nunca trava o scan */
    return (uint32_t)c;
}

static size_t utf8_enc(uint32_t cp, char out[4]) {
    if (cp < 0x80) {
        out[0] = (char)cp;
        return 1;
    }
    if (cp < 0x800) {
        out[0] = (char)(0xC0 | (cp >> 6));
        out[1] = (char)(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000) {
        out[0] = (char)(0xE0 | (cp >> 12));
        out[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
        out[2] = (char)(0x80 | (cp & 0x3F));
        return 3;
    }
    out[0] = (char)(0xF0 | (cp >> 18));
    out[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
    out[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
    out[3] = (char)(0x80 | (cp & 0x3F));
    return 4;
}

/* NFD-strip-casefold manual p/ Latin-1 + Latin Extended-A, gerado de
 * unicodedata (NFD, tira Mn, casefold): 162/192 viram ASCII, o resto vira
 * o par folded (æ/ð/ø/þ/ß/œ/ı/ĳ). Fora da tabela o codepoint passa
 * intacto (só A-Z dobra e Mn some). */
static const uint16_t FOLD_TAB[] = {
    0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x00E6, 0x0063, 0x0065,
    0x0065, 0x0065, 0x0065, 0x0069, 0x0069, 0x0069, 0x0069, 0x00F0, 0x006E,
    0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x00D7, 0x00F8, 0x0075, 0x0075,
    0x0075, 0x0075, 0x0079, 0x00FE, 0x00DF, 0x0061, 0x0061, 0x0061, 0x0061,
    0x0061, 0x0061, 0x00E6, 0x0063, 0x0065, 0x0065, 0x0065, 0x0065, 0x0069,
    0x0069, 0x0069, 0x0069, 0x00F0, 0x006E, 0x006F, 0x006F, 0x006F, 0x006F,
    0x006F, 0x00F7, 0x00F8, 0x0075, 0x0075, 0x0075, 0x0075, 0x0079, 0x00FE,
    0x0079, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0063, 0x0063,
    0x0063, 0x0063, 0x0063, 0x0063, 0x0063, 0x0063, 0x0064, 0x0064, 0x0111,
    0x0111, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065,
    0x0065, 0x0065, 0x0067, 0x0067, 0x0067, 0x0067, 0x0067, 0x0067, 0x0067,
    0x0067, 0x0068, 0x0068, 0x0127, 0x0127, 0x0069, 0x0069, 0x0069, 0x0069,
    0x0069, 0x0069, 0x0069, 0x0069, 0x0069, 0x0131, 0x0133, 0x0133, 0x006A,
    0x006A, 0x006B, 0x006B, 0x0138, 0x006C, 0x006C, 0x006C, 0x006C, 0x006C,
    0x006C, 0x0140, 0x0140, 0x0142, 0x0142, 0x006E, 0x006E, 0x006E, 0x006E,
    0x006E, 0x006E, 0x0149, 0x014B, 0x014B, 0x006F, 0x006F, 0x006F, 0x006F,
    0x006F, 0x006F, 0x0153, 0x0153, 0x0072, 0x0072, 0x0072, 0x0072, 0x0072,
    0x0072, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073,
    0x0074, 0x0074, 0x0074, 0x0074, 0x0167, 0x0167, 0x0075, 0x0075, 0x0075,
    0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075,
    0x0077, 0x0077, 0x0079, 0x0079, 0x0079, 0x007A, 0x007A, 0x007A, 0x007A,
    0x007A, 0x007A, 0x0073,
};

static uint32_t fold_cp(uint32_t cp) {
    if (cp >= 'A' && cp <= 'Z')
        return cp + 32;
    if (cp >= 0xC0 && cp <= 0x17F)
        return FOLD_TAB[cp - 0xC0];
    return cp;
}

static int is_mark(uint32_t cp) {
    return (cp >= 0x300 && cp <= 0x36F) || /* combining diacríticos */
           cp == 0xFEFF;                   /* BOM no meio do texto */
}

void tasks_norm(const char *src, char *dst, size_t dstn) {
    size_t o = 0;
    while (*src && o + 4 < dstn) {
        size_t l = 0;
        uint32_t cp = utf8_dec(src, &l);
        src += l;
        if (is_mark(cp))
            continue;
        char enc[4];
        size_t el = utf8_enc(fold_cp(cp), enc);
        if (o + el >= dstn)
            break;
        memcpy(dst + o, enc, el);
        o += el;
    }
    dst[o] = 0;
}

/* -- checkbox ---------------------------------------------------------- */

static int is_ws(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\v' ||
           c == '\f';
}

/* parse de "- [ ] texto" / "1. [x] texto". Devolve 1 e preenche indent
 * (bytes iniciais), done e [text,textlen) sem \n e sem espaços nas bordas. */
static int parse_check(const char *line, size_t *indentn, int *done,
                       const char **text, size_t *textlen) {
    const char *p = line;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p == '-' || *p == '+' || *p == '*') {
        p++;
    } else if (isdigit((unsigned char)*p)) {
        do
            p++;
        while (isdigit((unsigned char)*p));
        if (*p != '.' && *p != ')')
            return 0;
        p++;
    } else {
        return 0;
    }
    if (*p != ' ' && *p != '\t')
        return 0;
    while (*p == ' ' || *p == '\t')
        p++;
    if (p[0] != '[')
        return 0;
    char mark = p[1];
    if (mark != ' ' && mark != 'x' && mark != 'X')
        return 0;
    if (p[2] != ']')
        return 0;
    *indentn = (size_t)(p - line); /* ws + bullet + espaços (sem "[m]") */
    *done = (mark == 'x' || mark == 'X') ? 1 : 0;
    p += 3;
    if (*p != ' ' && *p != '\t')
        return 0;
    while (*p == ' ' || *p == '\t')
        p++;
    const char *t = p, *e = t + strlen(t);
    while (e > t && is_ws(e[-1]))
        e--;
    if (e == t)
        return 0;
    *text = t;
    *textlen = (size_t)(e - t);
    return 1;
}

/* -- carimbos ---------------------------------------------------------- */

/* Emissão manual (sem printf): valores pré-validados, zero warning. */
static char *put2(char *p, int v) {
    *p++ = (char)('0' + (v / 10) % 10);
    *p++ = (char)('0' + v % 10);
    return p;
}

static void fmt_date(char b[32], int y, int mo, int d) {
    b[0] = (char)('0' + (y / 1000) % 10);
    b[1] = (char)('0' + (y / 100) % 10);
    b[2] = (char)('0' + (y / 10) % 10);
    b[3] = (char)('0' + y % 10);
    b[4] = '-';
    put2(b + 5, mo);
    b[7] = '-';
    put2(b + 8, d);
    b[10] = 0;
}

static void fmt_stamp(char b[32], int y, int mo, int d, int h, int mi) {
    fmt_date(b, y, mo, d);
    b[10] = ' ';
    put2(b + 11, h);
    b[13] = ':';
    put2(b + 14, mi);
    b[16] = 0;
}

static int parse_stamp_at(const char *s, char out[17]) {
    /* s aponta p/ o primeiro dígito de YYYY-MM-DD[ HH:MM] */
    int y, mo, d, h = 0, mi = 0;
    char b[32];
    if (sscanf(s, "%4d-%2d-%2d %2d:%2d", &y, &mo, &d, &h, &mi) < 3)
        return 0;
    if (y < 1000 || y > 9999 || mo < 1 || mo > 12 || d < 1 || d > 31)
        return 0;
    if (s[10] == ' ' && isdigit((unsigned char)s[11]) &&
        isdigit((unsigned char)s[12]) && s[13] == ':' &&
        isdigit((unsigned char)s[14]) && isdigit((unsigned char)s[15])) {
        if (h > 23 || mi > 59)
            return 0;
        fmt_stamp(b, y, mo, d, h, mi);
    } else {
        fmt_date(b, y, mo, d);
    }
    strcpy(out, b);
    return 1;
}

/* última ocorrência do glifo seguida de data válida; "" se ausente. */
static void find_stamp(const char *text, const char *glyph, char out[17]) {
    out[0] = 0;
    size_t gl = strlen(glyph);
    const char *hit = NULL;
    char tmp[17];
    for (const char *p = text; (p = strstr(p, glyph)); p += gl) {
        const char *s = p + gl;
        while (*s == ' ')
            s++;
        if (parse_stamp_at(s, tmp)) {
            hit = p; /* guarda; continua p/ pegar a última */
            memcpy(out, tmp, 17);
        }
    }
    (void)hit;
}

void tasks_done_at(const char *text, char out[17]) {
    find_stamp(text, DONE_GLYPH, out);
}

static void created_stamp(const char *text, char out[17]) {
    find_stamp(text, BIRTH_GLYPH, out);
}

void tasks_now(char out[17]) {
    char b[32];
    time_t t = time(NULL);
    struct tm tm;
    localtime_r(&t, &tm);
    fmt_stamp(b, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour,
              tm.tm_min);
    strcpy(out, b);
}

void tasks_birth(const char *path, char out[17]) {
    out[0] = 0;
#ifdef __linux__
    struct statx stx;
    if (statx(AT_FDCWD, path, 0, STATX_BTIME, &stx) == 0 &&
        (stx.stx_mask & STATX_BTIME) && stx.stx_btime.tv_sec > 0) {
        char b[32];
        time_t t = stx.stx_btime.tv_sec;
        struct tm tm;
        localtime_r(&t, &tm);
        fmt_stamp(b, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour,
                  tm.tm_min);
        strcpy(out, b);
    }
#else
    (void)path;
#endif
}

void tasks_created_at(const char *text, const char *path, char out[17]) {
    created_stamp(text, out);
    if (!out[0]) {
        tasks_birth(path, out);
        if (!out[0])
            snprintf(out, 17, "?");
    }
}

/* -- scan -------------------------------------------------------------- */

typedef struct {
    task_t *v;
    size_t n, cap;
    const char *vault;
    size_t vaultn;
} acc_t;

static void acc_push(acc_t *a, task_t *t) {
    if (a->n == a->cap) {
        size_t nc = a->cap ? a->cap * 2 : 128;
        task_t *nv = realloc(a->v, nc * sizeof *nv);
        if (!nv)
            return;
        a->v = nv;
        a->cap = nc;
    }
    a->v[a->n++] = *t;
}

static int excluded(const char *rel) {
    for (size_t i = 0; i < sizeof EXCLUDE / sizeof EXCLUDE[0]; i++) {
        size_t l = strlen(EXCLUDE[i]);
        if (strncmp(rel, EXCLUDE[i], l) == 0)
            return 1;
    }
    return 0;
}

static void scan_file(acc_t *a, const char *path, const char *rel) {
    struct stat st;
    if (stat(path, &st) != 0)
        return;
    FILE *f = fopen(path, "r");
    if (!f)
        return;
    char *line = NULL;
    size_t cap = 0;
    ssize_t len;
    int nline = 0, fence = 0;
    while ((len = getline(&line, &cap, f)) >= 0) {
        nline++;
        const char *p = line;
        while (*p == ' ' || *p == '\t')
            p++;
        if (strncmp(p, "```", 3) == 0) {
            fence = !fence;
            continue;
        }
        if (fence)
            continue;
        size_t indentn = 0, textlen = 0;
        int done = 0;
        const char *text = NULL;
        if (!parse_check(line, &indentn, &done, &text, &textlen))
            continue;
        task_t t;
        memset(&t, 0, sizeof t);
        t.path = strdup(path);
        t.line = nline;
        t.indent = strndup(line, indentn);
        t.done = done;
        t.text = strndup(text, textlen);
        t.mtime = (long)st.st_mtime;
        if (!t.path || !t.indent || !t.text) {
            free(t.path);
            free(t.indent);
            free(t.text);
            continue;
        }
        /* created: ➕ ou mtime formatado (ordem lexicográfica = cronológica) */
        created_stamp(t.text, t.created);
        if (!t.created[0]) {
            char b[32];
            struct tm tm;
            time_t mt = st.st_mtime;
            localtime_r(&mt, &tm);
            fmt_stamp(b, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                      tm.tm_hour, tm.tm_min);
            strcpy(t.created, b);
        }
        t.ntext = malloc(textlen * 2 + 1);
        t.nrel = malloc(strlen(rel) * 2 + 1);
        if (!t.ntext || !t.nrel) {
            free(t.path);
            free(t.indent);
            free(t.text);
            free(t.ntext);
            free(t.nrel);
            continue;
        }
        tasks_norm(t.text, t.ntext, textlen * 2 + 1);
        tasks_norm(rel, t.nrel, strlen(rel) * 2 + 1);
        acc_push(a, &t);
    }
    free(line);
    fclose(f);
}

static void scan_dir(acc_t *a, const char *dir) {
    DIR *d = opendir(dir);
    if (!d)
        return;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.')
            continue;
        char *full = NULL, *rel = NULL;
        if (asprintf(&full, "%s/%s", dir, e->d_name) < 0)
            continue;
        rel = full + a->vaultn + 1;
        if (excluded(rel)) {
            free(full);
            continue;
        }
        struct stat st;
        if (lstat(full, &st) != 0) {
            free(full);
            continue;
        }
        if (S_ISLNK(st.st_mode)) {
            free(full); /* sem seguir symlink (glob do .py também não segue) */
            continue;
        }
        if (S_ISDIR(st.st_mode)) {
            scan_dir(a, full);
        } else if (S_ISREG(st.st_mode)) {
            size_t l = strlen(full);
            if (l > 3 && strcmp(full + l - 3, ".md") == 0)
                scan_file(a, full, rel);
        }
        free(full);
    }
    closedir(d);
}

static int cmp_base(const task_t *a, const task_t *b) {
    if (a->done != b->done)
        return a->done - b->done; /* abertas primeiro */
    return 0;
}

static int cmp_recent(const void *pa, const void *pb) {
    const task_t *a = pa, *b = pb;
    int c = cmp_base(a, b);
    if (c)
        return c;
    if (a->mtime != b->mtime)
        return a->mtime < b->mtime ? 1 : -1;
    if (a->path && b->path) {
        c = strcmp(a->path, b->path);
        if (c)
            return c;
    }
    return a->line - b->line;
}

int tasks_scan(task_t **out, size_t *n) {
    const char *vault = tasks_vault_dir();
    *out = NULL;
    *n = 0;
    if (!vault[0])
        return -1;
    struct stat st;
    if (stat(vault, &st) != 0 || !S_ISDIR(st.st_mode))
        return -1;
    acc_t a = {0};
    a.vault = vault;
    a.vaultn = strlen(vault);
    scan_dir(&a, vault);
    qsort(a.v, a.n, sizeof *a.v, cmp_recent);
    *out = a.v;
    *n = a.n;
    return 0;
}

void tasks_free(task_t *t, size_t n) {
    for (size_t i = 0; i < n; i++) {
        free(t[i].path);
        free(t[i].indent);
        free(t[i].text);
        free(t[i].ntext);
        free(t[i].nrel);
    }
    free(t);
}

/* -- view (ordem + filtro) ---------------------------------------------- */

static sort_mode_t g_mode = SORT_RECENT;

static int cmp_tasks(const task_t *a, const task_t *b, sort_mode_t mode) {
    int c = cmp_base(a, b);
    if (c)
        return c;
    switch (mode) {
    case SORT_OLD:
        if (a->mtime != b->mtime)
            return a->mtime < b->mtime ? -1 : 1;
        break;
    case SORT_TEXT:
        c = strcmp(a->ntext, b->ntext);
        if (c)
            return c;
        break;
    case SORT_FILE:
        c = strcmp(a->nrel, b->nrel);
        if (c)
            return c;
        break;
    case SORT_CREATED:
        c = strcmp(a->created, b->created);
        if (c)
            return c;
        break;
    case SORT_RECENT:
    default:
        if (a->mtime != b->mtime)
            return a->mtime < b->mtime ? 1 : -1;
        break;
    }
    c = strcmp(a->path, b->path);
    if (c)
        return c;
    return a->line - b->line;
}

#if defined(__GLIBC__) && !defined(__APPLE__)
static int cmp_idx(const void *pa, const void *pb, void *arg) {
    task_t *t = arg;
    return cmp_tasks(&t[*(const size_t *)pa], &t[*(const size_t *)pb], g_mode);
}
#endif

/* qsort_r (GNU) com fallback: n pequeno, insertion sort direto. */
size_t tasks_view(task_t *t, size_t n, sort_mode_t mode, const char *qn,
                  size_t *view) {
    size_t m = 0;
    for (size_t i = 0; i < n; i++) {
        if (qn && qn[0] &&
            !strstr(t[i].ntext, qn) && !strstr(t[i].nrel, qn))
            continue;
        view[m++] = i;
    }
    g_mode = mode;
#if defined(__GLIBC__) && !defined(__APPLE__)
    qsort_r(view, m, sizeof *view, cmp_idx, t);
#else
    for (size_t i = 1; i < m; i++) {
        size_t k = view[i], j = i;
        while (j > 0 &&
               cmp_tasks(&t[view[j - 1]], &t[k], mode) > 0) {
            view[j] = view[j - 1];
            j--;
        }
        view[j] = k;
    }
#endif
    return m;
}

/* -- escrita ------------------------------------------------------------ */

static int write_lines(const char *path, char **lines, size_t n) {
    char *tmp = NULL;
    if (asprintf(&tmp, "%s.yambar-tasks.tmp", path) < 0)
        return 0;
    struct stat st;
    int have = stat(path, &st) == 0;
    FILE *f = fopen(tmp, "w");
    if (!f) {
        free(tmp);
        return 0;
    }
    for (size_t i = 0; i < n; i++)
        fputs(lines[i], f);
    int ok = fclose(f) == 0;
    if (ok) {
        if (have)
            chmod(tmp, st.st_mode & 07777);
        ok = rename(tmp, path) == 0;
    }
    if (!ok)
        unlink(tmp);
    free(tmp);
    return ok;
}

static char **read_lines(const char *path, size_t *n) {
    FILE *f = fopen(path, "r");
    if (!f)
        return NULL;
    char **v = NULL;
    size_t nn = 0, cap = 0, lcap = 0;
    char *line = NULL;
    ssize_t len;
    while ((len = getline(&line, &lcap, f)) >= 0) {
        if (nn == cap) {
            size_t nc = cap ? cap * 2 : 64;
            char **nv = realloc(v, nc * sizeof *nv);
            if (!nv)
                break;
            v = nv;
            cap = nc;
        }
        v[nn++] = line;
        line = NULL;
        lcap = 0;
    }
    free(line);
    fclose(f);
    *n = nn;
    return v;
}

int tasks_write(const char *path, int nline, int done, const char *newtext) {
    size_t n = 0;
    char **lines = read_lines(path, &n);
    if (!lines || nline < 1 || (size_t)nline > n) {
        for (size_t i = 0; i < n; i++)
            free(lines[i]);
        free(lines);
        return 0;
    }
    size_t indentn = 0, textlen = 0;
    int cur = 0;
    const char *text = NULL;
    if (!parse_check(lines[nline - 1], &indentn, &cur, &text, &textlen)) {
        for (size_t i = 0; i < n; i++)
            free(lines[i]);
        free(lines);
        return 0; /* linha mudou no disco */
    }
    const char *body = newtext ? newtext : strndup(text, textlen);
    char *owned = NULL;
    if (!newtext) {
        owned = strndup(text, textlen);
        body = owned;
    }
    char *nl = NULL;
    int r = asprintf(&nl, "%.*s[%c] %s\n", (int)indentn, lines[nline - 1],
                     done ? 'x' : ' ', body);
    free(owned);
    if (r < 0) {
        for (size_t i = 0; i < n; i++)
            free(lines[i]);
        free(lines);
        return 0;
    }
    free(lines[nline - 1]);
    lines[nline - 1] = nl;
    int ok = write_lines(path, lines, n);
    for (size_t i = 0; i < n; i++)
        free(lines[i]);
    free(lines);
    return ok;
}

int tasks_append(const char *text) {
    char now[17];
    tasks_now(now);
    const char *vault = tasks_vault_dir();
    char *path = NULL;
    if (asprintf(&path, "%s/Inbox/Notepad.md", vault) < 0)
        return 0;
    size_t n = 0;
    char **lines = read_lines(path, &n);
    if (!lines) {
        lines = NULL;
        n = 0;
    }
    size_t at = n;
    int found = 0;
    for (size_t i = 0; i < n; i++) {
        /* compara sem o \n final */
        size_t l = strlen(lines[i]);
        while (l && (lines[i][l - 1] == '\n' || lines[i][l - 1] == '\r'))
            l--;
        if (l == 7 && strncmp(lines[i], "## todo", 7) == 0) {
            found = 1;
            at = i + 1;
            for (size_t j = i + 1; j < n; j++) {
                size_t m = strlen(lines[j]);
                while (m && (lines[j][m - 1] == '\n' ||
                             lines[j][m - 1] == '\r'))
                    m--;
                if (m == 0 || lines[j][0] == '#')
                    break;
                at = j + 1;
            }
            break;
        }
    }
    char *nl = NULL;
    if (asprintf(&nl, "- [ ] %s %s %s\n", text, BIRTH_GLYPH, now) < 0) {
        free(path);
        return 0;
    }
    char **nv = NULL;
    size_t nn = n + (found ? 1 : 2);
    nv = malloc(nn * sizeof *nv);
    if (!nv) {
        free(nl);
        free(path);
        return 0;
    }
    if (!found) {
        memcpy(nv, lines, n * sizeof *nv);
        nv[n] = strdup("## todo\n");
        nv[n + 1] = nl;
    } else {
        memcpy(nv, lines, at * sizeof *nv);
        nv[at] = nl;
        memcpy(nv + at + 1, lines + at, (n - at) * sizeof *nv);
    }
    free(lines);
    /* garante \n final na última linha pré-existente (paridade .py) */
    int ok = write_lines(path, nv, nn);
    for (size_t i = 0; i < nn; i++)
        free(nv[i]);
    free(nv);
    free(path);
    return ok;
}

long tasks_count_open(void) {
    task_t *t = NULL;
    size_t n = 0;
    if (tasks_scan(&t, &n) != 0)
        return -1;
    long c = 0;
    for (size_t i = 0; i < n; i++)
        if (!t[i].done)
            c++;
    tasks_free(t, n);
    return c;
}

/* -- selftest ----------------------------------------------------------- */

size_t tasks_utf8_encode(uint32_t cp, char out[4]) {
    return utf8_enc(cp, out);
}

void tasks_complete(const char *text, char *dst, size_t dstn) {
    char now[17], has[17];
    tasks_now(now);
    created_stamp(text, has);
    if (!has[0])
        snprintf(dst, dstn, "%s %s %s %s %s", text, BIRTH_GLYPH, now,
                 DONE_GLYPH, now);
    else
        snprintf(dst, dstn, "%s %s %s", text, DONE_GLYPH, now);
}

void tasks_reopen(const char *text, char *dst, size_t dstn) {
    /* recorta o span "✅[ ]data[ hora]" da última ocorrência válida */
    size_t gl = strlen(DONE_GLYPH);
    const char *cut = NULL, *cutend = NULL;
    for (const char *p = text; (p = strstr(p, DONE_GLYPH)); p += gl) {
        const char *s = p + gl;
        while (*s == ' ')
            s++;
        int y, mo, d, h, mi;
        if (sscanf(s, "%4d-%2d-%2d %2d:%2d", &y, &mo, &d, &h, &mi) >= 3 &&
            y >= 1000 && y <= 9999 && mo >= 1 && mo <= 12 && d >= 1 &&
            d <= 31) {
            cut = p;
            cutend = s + 10;
            if (s[10] == ' ')
                cutend = s + 16;
        }
    }
    char tmp[4096], out[4096];
    if (cut) {
        size_t a = (size_t)(cut - text);
        snprintf(tmp, sizeof tmp, "%.*s%s", (int)a, text, cutend);
    } else {
        snprintf(tmp, sizeof tmp, "%s", text);
    }
    /* colapsa 2+ espaços e apara as bordas */
    size_t o = 0;
    int space = 1; /* apara a esquerda */
    for (const char *p = tmp; *p && o + 1 < sizeof out; p++) {
        if (*p == ' ' || *p == '\t') {
            if (!space)
                out[o++] = ' ';
            space = 1;
        } else {
            space = 0;
            out[o++] = *p;
        }
    }
    while (o > 0 && out[o - 1] == ' ')
        o--; /* apara a direita */
    out[o] = 0;
    snprintf(dst, dstn, "%s", out);
}

static int fails = 0;
#define OK(cond, msg)                                                     \
    do {                                                                  \
        if (cond) {                                                       \
            printf("ok - %s\n", msg);                                     \
        } else {                                                          \
            printf("FAIL - %s\n", msg);                                   \
            fails++;                                                      \
        }                                                                 \
    } while (0)

int tasks_selftest(void) {
    char b[256];
    tasks_norm("Área de Transferência", b, sizeof b);
    OK(strcmp(b, "area de transferencia") == 0, "norm pt-BR");
    tasks_norm("ÇÃÕ Í 123", b, sizeof b);
    OK(strcmp(b, "cao i 123") == 0, "norm cedilha/til");
    tasks_norm("CRIADAS", b, sizeof b);
    OK(strcmp(b, "criadas") == 0, "norm upper");

    size_t in = 0, tl = 0;
    int dn = -1;
    const char *tx = NULL;
    OK(parse_check("- [ ] comprar café", &in, &dn, &tx, &tl) && dn == 0 &&
           tl == strlen("comprar café") &&
           memcmp(tx, "comprar café", tl) == 0,
       "parse aberto");
    OK(parse_check("  12) [X] feito", &in, &dn, &tx, &tl) && dn == 1,
       "parse numerado feito");
    OK(!parse_check("- [ ]", &in, &dn, &tx, &tl), "parse texto vazio rejeita");
    OK(!parse_check("só texto", &in, &dn, &tx, &tl), "parse sem bullet rejeita");

    char d[17];
    tasks_done_at("ler ✅ 2026-10-01 09:00 resto", d);
    OK(strcmp(d, "2026-10-01 09:00") == 0, "done_at extrai");
    tasks_done_at("sem carimbo", d);
    OK(d[0] == 0, "done_at vazio");

    char comp[512], re[512];
    tasks_complete("ler livro", comp, sizeof comp);
    OK(strstr(comp, "➕") && strstr(comp, "✅"), "complete carimba ➕+✅");
    tasks_reopen(comp, re, sizeof re);
    OK(!strstr(re, "✅") && strncmp(re, "ler livro ➕ ", 13) == 0,
       "reopen tira ✅ e mantém ➕");
    tasks_reopen("  sobra  duplo   ", re, sizeof re);
    OK(strcmp(re, "sobra duplo") == 0, "reopen colapsa espaços");

    /* vault temporário: fence, excluídos, ordenação, write, append */
    char tpl[] = "/tmp/tasks-test-XXXXXX";
    if (!mkdtemp(tpl)) {
        printf("FAIL - mkdtemp\n");
        return ++fails;
    }
    setenv("VAULT_DIR", tpl, 1);
    char p[4096];
    snprintf(p, sizeof p, "%s/Notas", tpl);
    mkdir(p, 0755);
    snprintf(p, sizeof p, "%s/Arquivo", tpl);
    mkdir(p, 0755);
    snprintf(p, sizeof p, "%s/Inbox", tpl);
    mkdir(p, 0755);
    FILE *f;
    snprintf(p, sizeof p, "%s/Notas/a.md", tpl);
    f = fopen(p, "w");
    fputs("- [ ] alfa ➕ 2026-01-02 10:00\n"
          "```\n"
          "- [ ] dentro de fence ignora\n"
          "```\n"
          "- [x] beta ✅ 2026-01-03 11:00\n",
          f);
    fclose(f);
    snprintf(p, sizeof p, "%s/Arquivo/b.md", tpl);
    f = fopen(p, "w");
    fputs("- [ ] excluída não aparece\n", f);
    fclose(f);
    task_t *t = NULL;
    size_t n = 0;
    OK(tasks_scan(&t, &n) == 0 && n == 2, "scan acha 2 (fence+excluído fora)");
    if (n == 2) {
        OK(!t[0].done && strcmp(t[0].text, "alfa ➕ 2026-01-02 10:00") == 0,
           "scan aberta primeiro");
        OK(t[1].done, "scan feita depois");
        OK(strcmp(t[0].created, "2026-01-02 10:00") == 0,
           "created usa carimbo");
        size_t view[2];
        char q[64];
        tasks_norm("ALFA", q, sizeof q);
        size_t m = tasks_view(t, n, SORT_RECENT, q, view);
        OK(m == 1 && t[view[0]].line == 1, "view filtra sem acento/caixa");
        m = tasks_view(t, n, SORT_TEXT, "", view);
        OK(m == 2, "view sem filtro tudo");
        /* toggle */
        snprintf(p, sizeof p, "%s/Notas/a.md", tpl);
        char now[17];
        tasks_now(now);
        char nb[512];
        snprintf(nb, sizeof nb, "%s ✅ %s", "alfa ➕ 2026-01-02 10:00", now);
        OK(tasks_write(p, 1, 1, nb), "write conclui");
        tasks_free(t, n);
        t = NULL;
        OK(tasks_scan(&t, &n) == 0 && n == 2 && t[1].done,
           "rescan vê concluída por último");
        OK(tasks_write(p, 2, 0, NULL) == 0, "write recusa linha fence");
        OK(tasks_write(p, 99, 0, NULL) == 0, "write recusa fora do arquivo");
    }
    OK(tasks_append("nova tarefa"), "append cria Notepad");
    snprintf(p, sizeof p, "%s/Inbox/Notepad.md", tpl);
    f = fopen(p, "r");
    char all[2048] = {0};
    if (f) {
        size_t r = fread(all, 1, sizeof all - 1, f);
        (void)r;
        fclose(f);
    }
    OK(strstr(all, "## todo") && strstr(all, "- [ ] nova tarefa ➕"),
       "append sob ## todo com carimbo");
    tasks_free(t, n);
    /* limpa */
    snprintf(p, sizeof p, "rm -rf %s", tpl);
    (void)system(p);
    unsetenv("VAULT_DIR");

    if (fails == 0)
        printf("selftest: todas passaram\n");
    return fails;
}

#ifdef TASKS_CORE_TEST
int main(void) {
    return tasks_selftest() ? 1 : 0;
}
#endif
