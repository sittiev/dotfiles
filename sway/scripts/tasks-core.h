/* tasks-core.h -- backend da TUI de tarefas, C puro (só libc).
 *
 * Paridade com sway/scripts/yambar-tasks.py: escopo do scan, formato dos
 * carimbos, escrita atômica tmp+rename e semântica de ordenação/busca.
 * Nenhuma dependência além da libc (nada de notcurses aqui): o chip
 * (--count, poll a cada 2s) e o --selftest compilam e rodam sem a lib.
 */
#ifndef TASKS_CORE_H
#define TASKS_CORE_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    char *path;      /* nota dona (heap) */
    int line;        /* nº da linha, base 1 */
    char *indent;    /* indentação+marcador originais (heap) */
    int done;        /* 1 = [x], 0 = [ ] */
    char *text;      /* texto sem o checkbox (heap, sem \n) */
    long mtime;      /* st_mtime da nota */
    char created[17]; /* "YYYY-MM-DD HH:MM" do ➕ ou do mtime */
    char *ntext;     /* norm(text) p/ busca/ordem (heap) */
    char *nrel;      /* norm(relpath) p/ busca/ordem (heap) */
} task_t;

typedef enum {
    SORT_RECENT = 0, /* abertas, mtime desc */
    SORT_OLD,        /* abertas, mtime asc */
    SORT_TEXT,       /* abertas, texto A-Z */
    SORT_FILE,       /* abertas, arquivo */
    SORT_CREATED,    /* abertas, carimbo ➕ */
    SORT_N
} sort_mode_t;

/* Diretório do vault: $VAULT_DIR (costura de teste do selftest) ou
 * ~/Documentos/Vault. Retorna buffer estático; "" se o HOME é desconhecido. */
const char *tasks_vault_dir(void);

/*norm: minúsculas sem acento (á->a, ç->c). Cobre Latin-1, Latin Extended-A,
 * grego e cirílico + 1-para-2 do casefold (ß→ss, ﬁ→fi, ﬂ→fl, K→k) e strip
 * de combining marks (0300–036F e faixas Ext/Aux/Sup). Fora disso o
 * codepoint passa intacto (sem libunistring de propósito; CJK não dobra,
 * igual ao NFD do .py). dst tem dstn bytes. */
void tasks_norm(const char *src, char *dst, size_t dstn);

/* scan: todas as tarefas do vault (abertas primeiro, mtime desc).
 * *out recebe malloc; *n o tamanho. 0 ok, -1 sem vault. */
int tasks_scan(task_t **out, size_t *n);
void tasks_free(task_t *t, size_t n);

/* Ordena cópia de índices em tasks segundo mode+filtro (filtro já em norm).
 * view tem ao menos n slots; retorna o nº visível. */
size_t tasks_view(task_t *t, size_t n, sort_mode_t mode, const char *query_norm,
                  size_t *view);

/* rewrite da linha do checkbox (tmp+rename, preserva modo). newtext NULL
 * preserva o original. 1 ok, 0 linha mudou no disco ou erro. */
int tasks_write(const char *path, int nline, int done, const char *newtext);

/* Nova tarefa sob "## todo" em Inbox/Notepad.md (carimbo ➕). 1 ok. */
int tasks_append(const char *text);

/* Nº de tarefas abertas (chip do yambar). -1 sem vault. */
long tasks_count_open(void);

/* birth "YYYY-MM-DD HH:MM" via statx BTIME; "" se indisponível. */
void tasks_birth(const char *path, char out[17]);

/* created: ➕ da tarefa ou birth do arquivo ("?" se nenhum). */
void tasks_created_at(const char *text, const char *path, char out[17]);

/* done_at: ✅ da tarefa ou "". */
void tasks_done_at(const char *text, char out[17]);

/* now "YYYY-MM-DD HH:MM" local. */
void tasks_now(char out[17]);

/* utf8_encode: codepoint -> 1-4 bytes; retorna o tamanho. */
size_t tasks_utf8_encode(uint32_t cp, char out[4]);

/* utf8_decode: 1-4 bytes em *cp; nunca retorna 0 (byte inválido passa). */
size_t tasks_utf8_decode(const char *s, uint32_t *cp);

/* has_created: 1 se o texto tem carimbo ➕ válido. */
int tasks_has_created(const char *text);

/* complete: garante ➕ e adiciona "✅ now" (estilo Tasks plugin). */
void tasks_complete(const char *text, char *dst, size_t dstn);

/* reopen: remove o ✅ (➕ fica), colapsa espaços duplos, apara bordas. */
void tasks_reopen(const char *text, char *dst, size_t dstn);

/* selftest sem TTY: imprime TAP-ish no stdout, retorna nº de falhas. */
int tasks_selftest(void);

#endif
