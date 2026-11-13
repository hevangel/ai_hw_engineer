/* Independent 80286 oracle driver around the PCE-286 CPU core.
 *
 * This program only calls the public API of external/pce-286 (GPL-2.0),
 * which is compiled from the submodule at build time and never copied into
 * this repository. It runs one scenario image from RESET and writes a
 * per-instruction architectural trace plus every memory byte it wrote.
 *
 * Scenario file:   MEM <addr> <hex bytes>   STEPS <n>   PORT <port> <byte>
 * Trace file:      S cs ip flags ax cx dx bx sp bp si di es ss ds msw st
 *                  O port value          (port writes, in order)
 *                  W addr value          (final value of each written byte)
 *                  END halt|shutdown|steps|stop
 * PCE-286 is a third-party emulator, not ground truth; see
 * plans/pce_oracle_loop.md for how disagreements are classified. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cpu/e8086/e8086.h>

#define MEM_SIZE 0x1000000UL
static unsigned char *mem, *written;
static unsigned char ports[0x10000];
static FILE *out;

static unsigned char get8(void *e, unsigned long a) { (void)e; return mem[a & (MEM_SIZE - 1)]; }
static void set8(void *e, unsigned long a, unsigned char v) {
    (void)e; a &= MEM_SIZE - 1; mem[a] = v; written[a] = 1;
}
static unsigned short get16(void *e, unsigned long a) {
    return (unsigned short)(get8(e, a) | (get8(e, a + 1) << 8));
}
static void set16(void *e, unsigned long a, unsigned short v) {
    set8(e, a, v & 0xff); set8(e, a + 1, v >> 8);
}
static unsigned char pget8(void *e, unsigned long a) { (void)e; return ports[a & 0xffff]; }
static void pset8(void *e, unsigned long a, unsigned char v) {
    (void)e; fprintf(out, "O %lx %x\n", a & 0xffff, v);
}
static unsigned short pget16(void *e, unsigned long a) {
    return (unsigned short)(pget8(e, a) | (pget8(e, a + 1) << 8));
}
static void pset16(void *e, unsigned long a, unsigned short v) {
    pset8(e, a, v & 0xff); pset8(e, a + 1, v >> 8);
}

int main(int argc, char **argv) {
    char line[65536];
    unsigned long steps = 2000, n;
    const char *reason = "steps";
    FILE *in;
    e8086_t *c;
    if (argc != 3) { fprintf(stderr, "usage: %s scenario trace\n", argv[0]); return 2; }
    mem = calloc(MEM_SIZE + 2, 1); written = calloc(MEM_SIZE + 2, 1);
    in = fopen(argv[1], "r"); out = fopen(argv[2], "w");
    if (!mem || !written || !in || !out) { perror("oracle"); return 2; }
    while (fgets(line, sizeof line, in)) {
        char *p = line; unsigned long a; unsigned v; int used;
        if (!strncmp(p, "MEM ", 4)) {
            p += 4; if (sscanf(p, "%lx%n", &a, &used) != 1) return 2; p += used;
            while (sscanf(p, "%2x%n", &v, &used) == 1) { mem[a++ & (MEM_SIZE - 1)] = (unsigned char)v; p += used; }
        } else if (!strncmp(p, "STEPS ", 6)) steps = strtoul(p + 6, 0, 10);
        else if (!strncmp(p, "PORT ", 5)) { if (sscanf(p + 5, "%lx %x", &a, &v) == 2) ports[a & 0xffff] = (unsigned char)v; }
    }
    fclose(in);
    c = e86_new();
    e86_set_80286(c);
    e86_set_mem(c, 0, get8, set8, get16, set16);
    e86_set_prt(c, 0, pget8, pset8, pget16, pset16);
    e86_reset(c);
    for (n = 0; n < steps; n++) {
        unsigned st;
        /* FLAGS bit 1 always reads 1 on an 80286 (PUSHF and pushed frames);
         * PCE keeps it as loaded, so normalize it at every boundary. */
        c->flg |= 0x0002;
        e86_execute(c);
        /* A repeated string step that has not left its instruction. */
        if ((c->prefix & E86_PREFIX_KEEP) && !c->state) continue;
        st = (c->state & E86_STATE_SHUTDOWN) ? 2 : (c->state & E86_STATE_HALT) ? 1 : c->state ? 3 : 0;
        fprintf(out, "S %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x\n",
            c->sreg[E86_REG_CS], c->ip, c->flg,
            c->dreg[0], c->dreg[1], c->dreg[2], c->dreg[3],
            c->dreg[4], c->dreg[5], c->dreg[6], c->dreg[7],
            c->sreg[E86_REG_ES], c->sreg[E86_REG_SS], c->sreg[E86_REG_DS], c->msw, st);
        if (st == 1) { reason = "halt"; break; }
        if (st == 2) { reason = "shutdown"; break; }
        if (st == 3) { reason = "stop"; break; }
    }
    for (n = 0; n < MEM_SIZE; n++) if (written[n]) fprintf(out, "W %lx %x\n", n, mem[n]);
    fprintf(out, "END %s\n", reason);
    fclose(out);
    return 0;
}
