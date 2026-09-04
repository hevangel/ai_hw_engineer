/*
 * panel_bridge.c - BUSICOM 141-PF front-panel bridge.
 *
 * A DPI-C shared library loaded into the xezim simulation (--dpi-lib).
 * The board latches one-shot printer events in the clock domain and the
 * simulator calls this bridge once per PANEL_TICK_CYCLES machine cycles
 * (~16ms of machine time):
 *
 *   dpi_panel_keys()                     -> 32-bit key mask (bit i =
 *                                           scancode 129+i held)
 *   dpi_panel_ctrl(evflags, hammer24, lamps)
 *     evflags  [2:0] = {red, advance_evt, hammer_evt}; [6:3] = drum pos
 *     hammer24 [23:20] = drum position at hammer time; [19:0] hammer word
 *     lamps    [2:0] = {negative, overflow, memory}
 *     returns  [3:0] precision, [7:4] rounding, [8] paper button
 *
 * The same library embeds a small HTTP server (pthread) that serves the
 * web front panel (host/web) and accepts key/switch events, so the whole
 * virtual platform is one process: simulator + bridge + web UI.
 *
 * Configuration is compile-time (set by scripts/run_system.sh):
 *   BUSICOM_WEB_DIR_PATH  directory with index.html/app.js/style.css
 *   BUSICOM_PORT          HTTP port (default 8080)
 *   BUSICOM_PACE          1 = pace ticks to the authentic ~16.01 ms of
 *                         machine time each (default off)
 *
 * Build: cc -O2 -shared -fPIC -pthread \
 *           -DBUSICOM_WEB_DIR_PATH='"/.../host/web"' \
 *           panel_bridge.c -o panel_bridge.so
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifndef BUSICOM_WEB_DIR_PATH
#define BUSICOM_WEB_DIR_PATH "/workspace/system/busicom_141pf/host/web"
#endif
#ifndef BUSICOM_PORT
#define BUSICOM_PORT 8080
#endif
#ifndef BUSICOM_PACE
#define BUSICOM_PACE 0
#endif

#define PAPER_ROWS 7
#define PAPER_COLS 18
#define NUM_COLS 15 /* numeric drum columns (hammer bits 3..17) */
#define KEY_COUNT 32
#define KEY_BASE 129
#define HOLD_MS 250 /* front-panel key press hold time */
#define ADVANCE_MS 180
#define TICK_MS 16 /* one panel tick = ~16ms of machine time */
#define STATE_JSON_MAX 32768

/* ------------------------------------------------------------------ */
/* Shared front-panel state                                           */
/* ------------------------------------------------------------------ */
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

/* pending key presses. Panel ticks arrive once per drum half-spin
 * (~spin machine cycles, see tb_top.sv). The firmware samples the
 * keyboard matrix from its main loop, whose period is not constant:
 * short while idle (~3k machine cycles) but up to ~30k machine cycles
 * (~40 panel ticks) after operations that print or compute. A key is
 * only registered if some main-loop pass reads its matrix row while it
 * is down, so a press is held for PRESENT_TICKS - one full worst-case
 * main-loop period, guaranteeing at least one sampling pass per press
 * regardless of phase - and followed by RELEASE_TICKS of no key before
 * the next press (several idle-period passes, so the firmware observes
 * one clean released scan and registers one click = one entry). The
 * queue absorbs the spacing: a human can keep typing; keys take effect
 * serially. */
#define QUEUE_CAP 64
#define PRESENT_TICKS 48
#define RELEASE_TICKS 16
/* press presentation states */
#define PS_IDLE 0
#define PS_PRESENT 1
#define PS_RELEASE 2
static struct {
    int code;
    int remaining;
} press_active[1];
static int present_state = PS_IDLE;
static int present_release;
static int press_queue[QUEUE_CAP];
static int press_head, press_count;

static int precision; /* decimal digits selector, 0..8 */
static int rounding;  /* 0 float, 1 round, 8 truncate */
static int64_t advance_btn_until;

static int lamp_memory, lamp_overflow, lamp_negative;
static int red_latch;
static char paper[PAPER_ROWS][PAPER_COLS][5]; /* utf-8 char cells */
static int paper_red[PAPER_ROWS];
static char drum_row[PAPER_COLS][5]; /* drum window rendering */

static int pace; /* machine-time pacing enable */

/* ------------------------------------------------------------------ */
static int64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* bounded printf-append: never lets *p pass buf+size */
static void appendf(char **p, size_t *left, const char *fmt, ...)
{
    if (*left <= 1)
        return;
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(*p, *left, fmt, ap);
    va_end(ap);
    if (n < 0)
        return;
    size_t written = (size_t)n < *left - 1 ? (size_t)n : *left - 1;
    *p += written;
    *left -= written;
}

static void set_cell(int row, int col, const char *s)
{
    snprintf(paper[row][col], sizeof(paper[row][col]), "%s", s);
}

static void clear_paper_row(int row)
{
    for (int c = 0; c < PAPER_COLS; c++)
        set_cell(row, c, " ");
    paper_red[row] = 0;
}

static void set_drum_char(int col, const char *s)
{
    snprintf(drum_row[col], sizeof(drum_row[col]), "%s", s);
}

static const char *digit_char(int pos)
{
    static const char *digits[13] = { "0", "1", "2", "3", "4", "5", "6",
                                      "7", "8", "9", ".", ".", "-" };
    return digits[pos];
}

static const char *sym_a_char(int pos)
{
    static const char *sym_a[13] = { "\u25c7", "+", "\u2212", "\u00d7",
                                     "\u00f7", "M+", "M-", "^", "=",
                                     "\u221a", "%", "C", "R" };
    return sym_a[pos];
}

static const char *sym_b_char(int pos)
{
    static const char *sym_b[13] = { "#", "*", "\u2160", "\u2161", "\u2162",
                                     "M+", "M-", "T", "K", "E", "Ex", "C",
                                     "M" };
    return sym_b[pos];
}

static void render_drum_row_at(int pos)
{
    for (int c = 0; c < NUM_COLS; c++)
        set_drum_char(c, digit_char(pos));
    set_drum_char(NUM_COLS, " ");
    set_drum_char(NUM_COLS + 1, sym_a_char(pos));
    set_drum_char(NUM_COLS + 2, sym_b_char(pos));
}

static void hit_hammer_at(int pos, int bits20)
{
    int row = PAPER_ROWS - 1;
    for (int i = 0; i < NUM_COLS; i++)
        if ((bits20 >> (3 + i)) & 1)
            set_cell(row, i, digit_char(pos));
    if (bits20 & 1)
        set_cell(row, NUM_COLS + 1, sym_a_char(pos));
    if ((bits20 >> 1) & 1)
        set_cell(row, NUM_COLS + 2, sym_b_char(pos));
    paper_red[row] = paper_red[row] || red_latch;
}

static void advance_paper(void)
{
    for (int r = 0; r < PAPER_ROWS - 1; r++) {
        for (int c = 0; c < PAPER_COLS; c++)
            set_cell(r, c, paper[r + 1][c]);
        paper_red[r] = paper_red[r + 1];
    }
    clear_paper_row(PAPER_ROWS - 1);
    red_latch = 0;
}

/* ------------------------------------------------------------------ */
/* DPI entry points: called once per panel tick (~16ms machine time)  */
/* ------------------------------------------------------------------ */
static int64_t tick_deadline;

static void pace_tick(void)
{
    int64_t now;
    struct timespec ts;

    if (!pace)
        return;
    now = now_ns();
    if (!tick_deadline || now - tick_deadline > 200000000LL)
        tick_deadline = now; /* resync after stalls */
    tick_deadline += (int64_t)TICK_MS * 1000000LL;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    int64_t cur = (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
    if (tick_deadline > cur) {
        ts.tv_sec = tick_deadline / 1000000000LL;
        ts.tv_nsec = tick_deadline % 1000000000LL;
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
    }
}

int dpi_panel_keys(void)
{
    int mask = 0;

    pthread_mutex_lock(&g_lock);
    /* release countdown, then present the next queued press */
    if (present_state == 2) { /* release countdown */
        if (--present_release <= 0) {
            present_state = PS_IDLE;
        }
    }
    if (present_state == 0 && press_count > 0) {
        press_active[0].code = press_queue[press_head];
        press_active[0].remaining = PRESENT_TICKS;
        press_head = (press_head + 1) % QUEUE_CAP;
        press_count--;
        present_state = 1;
    }
    if (present_state == 1) {
        mask = 1 << (press_active[0].code - KEY_BASE);
        if (--press_active[0].remaining <= 0) {
            present_state = 2; /* hold elapsed: release */
            present_release = RELEASE_TICKS;
        }
    }
    pthread_mutex_unlock(&g_lock);
    return mask;
}

int dpi_panel_ctrl(int evflags, int hammer24, int lamps)
{
    /* evflags: [0]=hammer_evt, [1]=advance_evt, [2]=red, [6:3]=drum pos,
     * [7]=key_seen (the firmware sampled the presented key) */
    int drum_pos = (evflags >> 3) & 0xF;
    int paper_btn;
    int64_t now;

    /* machine-time pacing rides the drum tick (one tick = ~16ms of
     * machine time); the faster key tick must not pace, or machine time
     * would run 8x slower than the drum rate assumes */
    pace_tick();

    pthread_mutex_lock(&g_lock);
    now = now_ns();

    render_drum_row_at(drum_pos);

    if (evflags & 0x1) /* hammer event: {drum pos, hammer word} latched */
        hit_hammer_at((hammer24 >> 20) & 0xF, hammer24 & 0xFFFFF);
    if (evflags & 0x2) /* paper advance event */
        advance_paper();
    if (evflags & 0x4) /* red ribbon level */
        red_latch = 1;

    lamp_memory = lamps & 0x1;
    lamp_overflow = (lamps >> 1) & 0x1;
    lamp_negative = (lamps >> 2) & 0x1;

    paper_btn = now < advance_btn_until;
    pthread_mutex_unlock(&g_lock);
    return (paper_btn << 8) | ((rounding & 0xF) << 4) | (precision & 0xF);
}

/* ------------------------------------------------------------------ */
/* Minimal HTTP server                                                */
/* ------------------------------------------------------------------ */
static int http_write(int fd, const char *buf, size_t len)
{
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n <= 0)
            return -1;
        off += (size_t)n;
    }
    return 0;
}

/* bounded unsigned-to-decimal, returns chars written */
static size_t u64_dec(char *dst, size_t v)
{
    char tmp[24];
    size_t n = 0;
    do {
        tmp[n++] = (char)('0' + (v % 10));
        v /= 10;
    } while (v && n < sizeof(tmp));
    for (size_t i = 0; i < n; i++)
        dst[i] = tmp[n - 1 - i];
    return n;
}

enum ctype { CT_HTML, CT_CSS, CT_JS, CT_JSON, CT_TEXT };

static const char *ctype_str(enum ctype t)
{
    switch (t) {
    case CT_HTML:
        return "text/html; charset=utf-8\r\n";
    case CT_CSS:
        return "text/css; charset=utf-8\r\n";
    case CT_JS:
        return "application/javascript; charset=utf-8\r\n";
    case CT_JSON:
        return "application/json\r\n";
    default:
        return "text/plain; charset=utf-8\r\n";
    }
}

/* compose the response header from literal segments and one decimal
 * number; no printf-family involvement */
static void respond(int fd, enum ctype ct, const char *body, size_t len)
{
    static const char p1[] =
        "HTTP/1.1 200 OK\r\nContent-Type: ";
    static const char p2[] = "Content-Length: ";
    /* leading CRLF terminates the Content-Length line */
    static const char p3[] = "\r\nConnection: close\r\n\r\n";
    const char *ctext = ctype_str(ct);
    size_t ct_len = strlen(ctext);
    char hdr[256];
    size_t off = 0;

    if (sizeof(p1) + ct_len + sizeof(p2) + 24 + sizeof(p3) > sizeof(hdr))
        return;
    memcpy(hdr + off, p1, sizeof(p1) - 1);
    off += sizeof(p1) - 1;
    memcpy(hdr + off, ctext, ct_len);
    off += ct_len; /* ctext already ends with CRLF */
    memcpy(hdr + off, p2, sizeof(p2) - 1);
    off += sizeof(p2) - 1;
    off += u64_dec(hdr + off, len);
    memcpy(hdr + off, p3, sizeof(p3) - 1);
    off += sizeof(p3) - 1;

    if (http_write(fd, hdr, off) == 0)
        http_write(fd, body, len);
}

static void respond_text(int fd, const char *msg)
{
    respond(fd, CT_TEXT, msg, strlen(msg));
}

/* Web files are served by literal name from a directory handle opened
 * once - no request-controlled path strings are ever built. */
static void respond_file(int fd, const char *name, enum ctype ct)
{
    static DIR *dir;
    if (!dir) {
        dir = opendir(BUSICOM_WEB_DIR_PATH);
        if (!dir) {
            respond_text(fd, "web dir missing");
            return;
        }
    }
    int f = openat(dirfd(dir), name, O_RDONLY);
    if (f < 0) {
        respond_text(fd, "not found");
        return;
    }
    struct stat st;
    if (fstat(f, &st) != 0 || st.st_size > 4 * 1024 * 1024 ||
        !S_ISREG(st.st_mode)) {
        close(f);
        respond_text(fd, "not found");
        return;
    }
    char *body = malloc((size_t)st.st_size);
    if (!body) {
        close(f);
        respond_text(fd, "oom");
        return;
    }
    size_t off = 0;
    while (off < (size_t)st.st_size) {
        ssize_t n = read(f, body + off, (size_t)st.st_size - off);
        if (n <= 0)
            break;
        off += (size_t)n;
    }
    close(f);
    respond(fd, ct, body, off);
    free(body);
}

/* state.json: paper rows are ["c0",..,"c17",red] arrays */
static void respond_state(int fd)
{
    char *body = malloc(STATE_JSON_MAX);
    if (!body) {
        respond_text(fd, "oom");
        return;
    }
    char *p = body;
    size_t left = STATE_JSON_MAX;

    pthread_mutex_lock(&g_lock);
    appendf(&p, &left,
            "{\"lamps\":{\"memory\":%d,\"overflow\":%d,\"negative\":%d},"
            "\"precision\":%d,\"rounding\":%d,\"drumRow\":[",
            lamp_memory, lamp_overflow, lamp_negative, precision, rounding);
    for (int c = 0; c < PAPER_COLS; c++)
        appendf(&p, &left, "%s\"%s\"", c ? "," : "", drum_row[c]);
    appendf(&p, &left, "],\"paper\":[");
    for (int r = 0; r < PAPER_ROWS; r++) {
        appendf(&p, &left, "%s[", r ? "," : "");
        for (int c = 0; c < PAPER_COLS; c++)
            appendf(&p, &left, "%s\"%s\"", c ? "," : "", paper[r][c]);
        appendf(&p, &left, ",%d]", paper_red[r]);
    }
    appendf(&p, &left, "]}");
    pthread_mutex_unlock(&g_lock);

    respond(fd, CT_JSON, body, (size_t)(p - body));
    free(body);
}

/* numeric JSON field lookup: finds "key":<number> */
static int json_int(const char *body, const char *key, int *out)
{
    char pat[64];
    snprintf(pat, sizeof(pat), "\"%s\"", key);
    const char *p = strstr(body, pat);
    if (!p)
        return 0;
    p = strchr(p + strlen(pat), ':');
    if (!p)
        return 0;
    p++;
    while (*p == ' ')
        p++;
    char *end = NULL;
    long v = strtol(p, &end, 10);
    if (end == p)
        return 0;
    *out = (int)v;
    return 1;
}

static void handle_client(int fd)
{
    char req[8192];
    size_t got = 0;
    ssize_t n;

    while (got < sizeof(req) - 1) {
        n = read(fd, req + got, sizeof(req) - 1 - got);
        if (n <= 0)
            return;
        got += (size_t)n;
        req[got] = '\0';
        if (strstr(req, "\r\n\r\n"))
            break;
    }

    /* headers and body can arrive in separate segments: drain up to
     * Content-Length more bytes so POST bodies are never truncated */
    const char *hdr_end = strstr(req, "\r\n\r\n");
    size_t want_body = 0;
    for (const char *p = req; hdr_end && p + 15 < hdr_end; p++) {
        if (strncasecmp(p, "content-length:", 15) == 0) {
            const char *d = p + 15;
            while (d < hdr_end && *d == ' ')
                d++;
            while (d < hdr_end && *d >= '0' && *d <= '9')
                want_body = want_body * 10 + (size_t)(*d++ - '0');
            break;
        }
    }
    if (want_body > 4096)
        want_body = 4096;
    while (hdr_end && got - (size_t)(hdr_end - req + 4) < want_body &&
           got < sizeof(req) - 1) {
        n = read(fd, req + got, sizeof(req) - 1 - got);
        if (n <= 0)
            break;
        got += (size_t)n;
        req[got] = '\0';
    }

    /* request line: METHOD SP TARGET SP VERSION CRLF (bounded copies) */
    char method[8] = "";
    char path[128] = "";
    const char *sp = strchr(req, ' ');
    if (!sp || (size_t)(sp - req) >= sizeof(method))
        return;
    memcpy(method, req, (size_t)(sp - req));
    method[sp - req] = '\0';
    const char *target = sp + 1;
    const char *sp2 = strchr(target, ' ');
    if (!sp2 || (size_t)(sp2 - target) >= sizeof(path))
        return;
    memcpy(path, target, (size_t)(sp2 - target));

    const char *body = strstr(req, "\r\n\r\n");
    body = body ? body + 4 : "";

    const char *q = strchr(path, '?');
    size_t plen = q ? (size_t)(q - path) : strlen(path);

    if (strcmp(method, "GET") == 0) {
        if (plen == 1 && path[0] == '/') {
            respond_file(fd, "index.html", CT_HTML);
        } else if (plen >= 5 && strncmp(path, "/state.json", plen) == 0) {
            respond_state(fd);
        } else if (plen >= 5 && strncmp(path, "/app.js", plen) == 0) {
            respond_file(fd, "app.js", CT_JS);
        } else if (plen >= 5 && strncmp(path, "/style.css", plen) == 0) {
            respond_file(fd, "style.css", CT_CSS);
        } else {
            respond_text(fd, "not found");
        }
        return;
    }

    if (strcmp(method, "POST") == 0) {
        if (plen >= 4 && strncmp(path, "/press", plen) == 0) {
            int code = 0;
            json_int(body, "code", &code);
            pthread_mutex_lock(&g_lock);
            if (code >= KEY_BASE && code < KEY_BASE + KEY_COUNT &&
                press_count < QUEUE_CAP) {
                press_queue[(press_head + press_count) % QUEUE_CAP] = code;
                press_count++;
                fprintf(stderr, "[press] code=%d count=%d\n", code,
                        press_count);
            }
            pthread_mutex_unlock(&g_lock);
            respond(fd, CT_JSON, "{\"ok\":true}", 11);
        } else if (plen >= 4 && strncmp(path, "/advance", plen) == 0) {
            pthread_mutex_lock(&g_lock);
            advance_btn_until = now_ns() + ADVANCE_MS * 1000000LL;
            pthread_mutex_unlock(&g_lock);
            respond(fd, CT_JSON, "{\"ok\":true}", 11);
        } else if (plen >= 4 && strncmp(path, "/switches", plen) == 0) {
            int v;
            pthread_mutex_lock(&g_lock);
            if (json_int(body, "precision", &v))
                precision = v < 0 ? 0 : (v > 8 ? 8 : v);
            if (json_int(body, "rounding", &v))
                rounding = (v == 0 || v == 1 || v == 8) ? v : rounding;
            pthread_mutex_unlock(&g_lock);
            respond(fd, CT_JSON, "{\"ok\":true}", 11);
        } else {
            respond_text(fd, "not found");
        }
        return;
    }
    respond_text(fd, "bad request");
}

static void *http_thread(void *arg)
{
    (void)arg;
    int port = BUSICOM_PORT;

    int srv = socket(AF_INET, SOCK_STREAM, 0);
    if (srv < 0) {
        perror("socket");
        return NULL;
    }
    int one = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    struct sockaddr_in addr = { 0 };
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons((uint16_t)port);
    if (bind(srv, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind (web panel port busy?)");
        return NULL;
    }
    listen(srv, 8);
    fprintf(stderr, "[panel-bridge] web front panel on http://0.0.0.0:%d/\n",
            port);
    for (;;) {
        int fd = accept(srv, NULL, NULL);
        if (fd < 0)
            continue;
        handle_client(fd);
        close(fd);
    }
    return NULL;
}

__attribute__((constructor)) static void panel_bridge_init(void)
{
    pace = (BUSICOM_PACE == 1);
    for (int r = 0; r < PAPER_ROWS; r++)
        clear_paper_row(r);
    render_drum_row_at(0);
    pthread_t t;
    if (pthread_create(&t, NULL, http_thread, NULL) != 0)
        fprintf(stderr, "[panel-bridge] failed to start HTTP server\n");
    else
        pthread_detach(t);
}
