// Differential check: run the same program on both 6502 implementations and
// compare architectural state at every opcode fetch. Cycles are expected to
// differ (the cycle core models dummy reads); the comparison is per instruction.
#include "Vdual_6502_top.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static Vdual_6502_top top;
static std::array<uint8_t, 65536> mem_a, mem_b;
static uint32_t hash_a, hash_b;
static unsigned long instructions;

static void fail(const char* why) {
    std::fprintf(stderr,
        "DIFF at instruction %lu: %s\n  A pc=%04x a=%02x x=%02x y=%02x s=%02x p=%02x\n"
        "  B pc=%04x a=%02x x=%02x y=%02x s=%02x p=%02x\n",
        instructions, why, top.pc_a, top.a_a, top.x_a, top.y_a, top.s_a, top.p_a,
        top.pc_b, top.a_b, top.x_b, top.y_b, top.s_b, top.p_b);
    std::exit(1);
}

static void tick_a() {
    top.clk_a = 0; top.eval();
    top.din_a = mem_a[top.addr_a]; top.eval();
    if (top.rst_n_a && top.we_a) {
        // Hash the resulting memory contents, so an RMW dummy write of the old
        // value (which the cycle core models and the functional core does not)
        // does not count as a difference.
        hash_a ^= (uint32_t(top.addr_a) << 8) ^ mem_a[top.addr_a];
        mem_a[top.addr_a] = top.dout_a;
        hash_a ^= (uint32_t(top.addr_a) << 8) ^ mem_a[top.addr_a];
    }
    top.clk_a = 1; top.eval();
}
static void tick_b() {
    top.clk_b = 0; top.eval();
    top.din_b = mem_b[top.addr_b]; top.eval();
#ifdef INJECT_FAULT
    // Negative control: corrupt one read in core B so the comparison must fail.
    if (instructions < 20 && top.addr_b == 0x0020) top.din_b ^= 0x01;
#endif
    if (top.rst_n_b && top.we_b) {
        hash_b ^= (uint32_t(top.addr_b) << 8) ^ mem_b[top.addr_b];
        mem_b[top.addr_b] = top.dout_b;
        hash_b ^= (uint32_t(top.addr_b) << 8) ^ mem_b[top.addr_b];
    }
    top.clk_b = 1; top.eval();
}

// The running XOR hash is cheap but order/duplicate insensitive; compare the
// whole image periodically and at the trap so a hash collision cannot hide a
// divergence.
static void compare_memory() {
    if (std::memcmp(mem_a.data(), mem_b.data(), mem_a.size()) == 0) return;
    unsigned shown = 0;
    for (unsigned addr = 0; addr < 65536 && shown < 6; ++addr) {
        if (mem_a[addr] != mem_b[addr]) {
            std::fprintf(stderr, "  mem[%04x] A=%02x B=%02x\n", addr, mem_a[addr], mem_b[addr]);
            ++shown;
        }
    }
    fail("memory contents");
}

static void compare() {
    if (top.pc_a != top.pc_b) fail("PC");
    if (top.a_a != top.a_b) fail("A");
    if (top.x_a != top.x_b) fail("X");
    if (top.y_a != top.y_b) fail("Y");
    if (top.s_a != top.s_b) fail("SP");
    if ((top.p_a & 0xef) != (top.p_b & 0xef)) fail("P");
    if (hash_a != hash_b) {
        unsigned shown = 0;
        for (unsigned addr = 0; addr < 65536 && shown < 6; ++addr) {
            if (mem_a[addr] != mem_b[addr]) {
                std::fprintf(stderr, "  mem[%04x] A=%02x B=%02x\n", addr, mem_a[addr], mem_b[addr]);
                ++shown;
            }
        }
        fail("memory writes");
    }
}

static void step_a() {
    if (!top.fetch_a && !top.fault_a) fail("A not at fetch");
    tick_a();
    for (unsigned i = 0; i < 16 && !top.fetch_a && !top.fault_a; ++i) tick_a();
    if (!top.fetch_a) fail("A did not reach next fetch");
}
static void step_b() {
    if (!top.fetch_b && !top.fault_b) fail("B not at fetch");
    tick_b();
    for (unsigned i = 0; i < 16 && !top.fetch_b && !top.fault_b; ++i) tick_b();
    if (!top.fetch_b) fail("B did not reach next fetch");
}

static void reset_both() {
    top.clk_a = 0; top.clk_b = 0; top.rst_n_a = 0; top.rst_n_b = 0;
    top.din_a = 0; top.din_b = 0; top.eval();
    for (int i = 0; i < 8; ++i) { tick_a(); tick_b(); }
    top.rst_n_a = 1; top.rst_n_b = 1;
    for (int i = 0; i < 16 && !top.fetch_a; ++i) tick_a();
    for (int i = 0; i < 16 && !top.fetch_b; ++i) tick_b();
    if (!top.fetch_a || !top.fetch_b) fail("reset did not reach fetch");
    hash_a = hash_b = 0;
}

// Run until both cores fetch the same PC three times in a row (self-loop trap),
// comparing every instruction after the alignment preamble.
static void run(const char* label, unsigned skip, unsigned long limit) {
    uint16_t previous = 0xffff; unsigned repeats = 0;
    for (instructions = 0; instructions < limit; ++instructions) {
        if (instructions % (1u << 20) == 0) compare_memory();
        if (top.fetch_a && top.pc_a == previous) ++repeats; else repeats = 0;
        if (repeats == 3) {
            compare_memory();
            std::printf("PASS differential %s: %lu instructions, trap at %04x\n",
                        label, instructions, previous);
            return;
        }
        previous = top.pc_a;
        step_a();
        step_b();
        if (instructions >= skip) compare();
    }
    fail("timeout");
}

static void load_hex(const char* path) {
    FILE* f = std::fopen(path, "r");
    if (!f) { std::perror(path); std::exit(1); }
    char line[128];
    unsigned offset = 0;
    while (std::fgets(line, sizeof(line), f) && offset < 65536) {
        for (char* p = line; *p && offset < 65536; ) {
            while (*p == ' ') ++p;
            if (!std::isxdigit((unsigned char)p[0]) || !std::isxdigit((unsigned char)p[1])) break;
            char byte[3] = {p[0], p[1], 0};
            mem_a[offset] = (uint8_t)std::strtoul(byte, nullptr, 16);
            ++offset; p += 2;
        }
    }
    std::fclose(f);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Phase 1: a short directed program covering loads, stores, arithmetic,
    // stack, branch and subroutine return.
    const uint16_t start = 0x8000;
    mem_a.fill(0xea);
    const uint8_t program[] = {0xa2,0xff, 0x9a, 0xb8, /* preamble: SP=FF, V=0 */
        0xa9,0x10, 0x85,0x20, 0xa5,0x20, 0x69,0x05, 0x85,0x21, 0xe8, 0xca,
        0x48, 0x68, 0x4c,0x12,0x80};
 // CLD; JMP $8001
    for (unsigned i = 0; i < sizeof(program); ++i) mem_a[start + i] = program[i];
    mem_a[0xfffc] = start & 0xff; mem_a[0xfffd] = start >> 8;
    mem_b = mem_a;
    reset_both();
    run("directed", 3, 2000);

    // Phase 2: the Klaus functional test, same binary, same reset vector.
    mem_a.fill(0); mem_b.fill(0);
    load_hex("references/6502_functional_test.bin.hex");
    mem_b = mem_a;
    // Preamble that normalises the two power-up conventions (SP and V) before
    // the shared program, then enters Klaus at its usual $0400.
    const uint8_t preamble[] = {0xa2,0xff, 0x9a, 0xb8, 0x4c,0x00,0x04};
    for (unsigned i = 0; i < sizeof(preamble); ++i) { mem_a[0x0200 + i] = preamble[i]; mem_b[0x0200 + i] = preamble[i]; }
    mem_a[0xfffc] = 0x00; mem_a[0xfffd] = 0x02;
    mem_b[0xfffc] = 0x00; mem_b[0xfffd] = 0x02;
    reset_both();
    run("Klaus", 5, 40000000);
    return 0;
}
