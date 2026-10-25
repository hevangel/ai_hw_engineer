// Independent Space Invaders board model driven by the external superzazu
// i8080 emulator (design/amd_am9080/references/superzazu). This model is
// written from the sourced hardware documentation (spec/spec.md) and never
// reads the repository RTL; the regression compares it against the RTL
// board to catch shared model errors. Hashing of the dumped image happens
// in the Python test driver (hashlib), not here.
//
// Modes:
//   oracle_board checkpoint <rom.hex> <instructions>
//       Run from reset with interrupts never taken (the boot code runs DI),
//       stop exactly at the given instruction boundary, and print a JSON
//       checkpoint: CPU state, shift register, and the decoded 0000h-3FFFh
//       memory image as hex. Cycle timing is irrelevant here, so the
//       comparison against the RTL is exact.
//   oracle_board play <rom.hex>
//       Behavioral run with interrupts at the documented cadence (two RSTs
//       per 60 Hz frame, real T-cycles): coin, one-player start, autofire;
//       report credit and score as BCD to compare against the RTL run.
#include "i8080.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RAM_BASE 0x2000
#define VRAM_BASE 0x2400
#define CREDIT_ADDR 0x20EB
#define SCORE_LO_ADDR 0x20F8
#define SCORE_HI_ADDR 0x20F9
#define IMAGE_SIZE 16384

static uint8_t rom[8192], ram[1024], vram[7168];
static uint16_t shift_reg;
static uint8_t shift_off;
static uint8_t in0, in1, in2;
static const char HEXDIG[17] = "0123456789abcdef";

static uint8_t board_read(void *, uint16_t addr) {
    uint16_t e = (uint16_t)(addr & 0xbfff);  // bit 14 ignored (mirror alias)
    if (e < 0x2000) return rom[e];
    if (e < 0x2400) return ram[e & 0x3ff];
    if (e < 0x4000) return vram[e - VRAM_BASE];
    return 0xff;
}

static void board_write(void *, uint16_t addr, uint8_t value) {
    uint16_t e = (uint16_t)(addr & 0xbfff);
    if (e < 0x2000) return;                    // ROM
    if (e < 0x2400) ram[e & 0x3ff] = value;
    else if (e < 0x4000) vram[e - VRAM_BASE] = value;
}

static uint8_t board_in(void *, uint8_t port) {
    switch (port) {
    case 0: return (uint8_t)(in0 | 0x0e);      // bits 1-3 read as 1
    case 1: return (uint8_t)(in1 | 0x08);      // bit 3 reads as 1
    case 2: return in2;
    case 3: return (uint8_t)(shift_reg >> (8 - shift_off));
    default: return 0xff;
    }
}

static void board_out(void *, uint8_t port, uint8_t value) {
    switch (port) {
    case 2: shift_off = (uint8_t)(value & 7); break;
    case 4: shift_reg = (uint16_t)((value << 8) | (shift_reg >> 8)); break;
    default: break;  // sound latches and watchdog observed, not modelled
    }
}

static uint8_t flags_byte(const i8080 *cpu) {
    return (uint8_t)((cpu->sf << 7) | (cpu->zf << 6) | (cpu->hf << 4) |
                     (cpu->pf << 2) | 0x02 | cpu->cf);
}

static void print_field(const char *name, unsigned value) {
    printf(",\"%s\":%u", name, value);
}

static void print_image(void) {
    uint8_t image[IMAGE_SIZE];
    memcpy(image, rom, sizeof rom);
    memcpy(image + RAM_BASE, ram, sizeof ram);
    memcpy(image + VRAM_BASE, vram, sizeof vram);
    for (int i = 0; i < IMAGE_SIZE; ++i) {
        putchar(HEXDIG[image[i] >> 4]);
        putchar(HEXDIG[image[i] & 15]);
    }
}

static int load_rom(const char *path) {
    FILE *file = fopen(path, "r");
    if (!file) return -1;
    for (int i = 0; i < 8192; ++i) {
        unsigned v;
        if (fscanf(file, "%x", &v) != 1 || v > 0xff) {
            fclose(file);
            return -1;
        }
        rom[i] = (uint8_t)v;
    }
    fclose(file);
    return 0;
}

static void init_cpu(i8080 *cpu) {
    i8080_init(cpu);
    cpu->read_byte = board_read;
    cpu->write_byte = board_write;
    cpu->port_in = board_in;
    cpu->port_out = board_out;
}

static void step_with_interrupts(i8080 *cpu, long *next_int, int *vector) {
    if (cpu->cyc >= (unsigned long)*next_int) {
        i8080_interrupt(cpu, (uint8_t)*vector);
        *next_int += 16640;
        *vector = *vector == 0xcf ? 0xd7 : 0xcf;
    }
    i8080_step(cpu);
}

static int run_checkpoint(long target) {
    if (target < 1) return 2;
    i8080 cpu;
    init_cpu(&cpu);
    for (long i = 0; i < target; ++i) i8080_step(&cpu);
    printf("{\"pc\":%u", (unsigned)cpu.pc);
    print_field("sp", cpu.sp);
    print_field("a", cpu.a);
    print_field("b", cpu.b);
    print_field("c", cpu.c);
    print_field("d", cpu.d);
    print_field("e", cpu.e);
    print_field("h", cpu.h);
    print_field("l", cpu.l);
    print_field("flags", flags_byte(&cpu));
    print_field("shift", shift_reg);
    print_field("shiftOff", shift_off);
    fputs(",\"image\":\"", stdout);
    print_image();
    fputs("\"}\n", stdout);
    return 0;
}

static int run_play(void) {
    i8080 cpu;
    init_cpu(&cpu);
    long next_int = 16640;
    int vector = 0xcf;
    long instructions = 0;
    // Input schedule (instructions from reset): attract, coin down, coin
    // up, start down, start up, then sweep right while pulsing fire
    // (stationary fire only erodes the player's own shields).
    const long schedule[4] = {200000, 210000, 320000, 330000};
    int phase = 0;
    int fire = 0;
    const long play_until = 4000000;
    while (instructions < play_until) {
        while (phase < 4 && instructions >= schedule[phase]) {
            switch (phase) {
            case 0: in1 = 0x01; break;   // coin
            case 1: in1 = 0x00; break;   // release
            case 2: in1 = 0x04; break;   // 1P start
            default: in1 = 0x00; break;  // release
            }
            ++phase;
        }
        if (phase >= 4) {
            // Right held; fire pulsed every 5000 instructions.
            in1 = (uint8_t)(0x40 | (fire ? 0x10 : 0x00));
            if (instructions % 5000 == 0) fire = !fire;
        }
        step_with_interrupts(&cpu, &next_int, &vector);
        ++instructions;
    }
    uint8_t credit = ram[CREDIT_ADDR - RAM_BASE];
    uint8_t slo = ram[SCORE_LO_ADDR - RAM_BASE];
    uint8_t shi = ram[SCORE_HI_ADDR - RAM_BASE];
    long score = (shi >> 4) * 1000 + (shi & 15) * 100 +
                 (slo >> 4) * 10 + (slo & 15);
    printf("{\"credit\":%u", (unsigned)credit);
    print_field("score", (unsigned)score);
    print_field("instructions", (unsigned)instructions);
    print_field("pc", cpu.pc);
    fputs(",\"vram\":\"", stdout);
    for (int i = 0; i < 7168; ++i) {
        putchar(HEXDIG[vram[i] >> 4]);
        putchar(HEXDIG[vram[i] & 15]);
    }
    fputs("\"}\n", stdout);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 3 && argc != 4) {
        fputs("usage: oracle_board checkpoint|play <rom.hex> [instructions]\n",
              stderr);
        return 2;
    }
    if (load_rom(argv[2]) != 0) {
        fputs("cannot load ROM image\n", stderr);
        return 2;
    }
    if (strcmp(argv[1], "checkpoint") == 0)
        return run_checkpoint(argc > 3 ? strtol(argv[3], NULL, 10) : 30000);
    if (strcmp(argv[1], "play") == 0)
        return run_play();
    fputs("unknown mode\n", stderr);
    return 2;
}
