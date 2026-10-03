#include "Vmos_6502.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

// Expectations use the MOS/Synertek programming manual sections 3, 4, 7.
// This is a directed test, not an ISS and not a substitute for real software.
static Vmos_6502 cpu;
static std::array<uint8_t, 65536> mem;
static void require(bool ok, const char* message) {
    if (!ok) { std::fprintf(stderr, "%s at PC=%04x P=%02x\n", message,
                           cpu.pc_o, cpu.status_o); std::exit(1); }
}
static void tick() {
    cpu.clk = 0; cpu.eval();
    cpu.bus_data_i = mem[cpu.bus_addr]; cpu.eval();
    if (cpu.rst_n && cpu.bus_we) mem[cpu.bus_addr] = cpu.bus_data_o;
    cpu.clk = 1; cpu.eval();
}
static void reset(uint16_t start) {
    mem.fill(0x02);
    mem[0xfffc] = start & 255; mem[0xfffd] = start >> 8;
    cpu.rst_n = 0; tick(); tick(); cpu.rst_n = 1;
    for (int i = 0; i < 8 && !cpu.fetch_o; ++i) tick();
    require(cpu.fetch_o && cpu.pc_o == start, "reset vector");
}
static void step(uint16_t next) {
    require(cpu.fetch_o, "step must start at opcode fetch");
    tick();
    for (int i = 0; i < 8 && !cpu.fetch_o && !cpu.fault_o; ++i) tick();
    require(!cpu.fault_o && cpu.fetch_o, "instruction failed to finish");
    require(cpu.pc_o == next && cpu.bus_addr == next, "wrong next fetch PC");
    cpu.clk = 0; cpu.eval(); cpu.bus_data_i = mem[cpu.bus_addr]; cpu.eval();
    require(cpu.bus_data_i == mem[next], "wrong next opcode");
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    const uint8_t loads[] = {0xa5,0xa6,0xa4,0xad,0xae,0xac};
    for (unsigned op : loads) for (unsigned value = 0; value < 256; ++value) {
        reset(0x8000);
        mem[0x8000] = op; mem[0x8001] = 0xff; mem[0x8002] = 0x40;
        mem[(op < 0xa8) ? 0x00ff : 0x40ff] = value;
        step((op < 0xa8) ? 0x8002 : 0x8003);
        unsigned actual = (op == 0xa5 || op == 0xad) ? cpu.bus_data_o
                        : (op == 0xa6 || op == 0xae) ? cpu.x_o : cpu.y_o;
        require(actual == value, "load value");
        require(cpu.status_o == (0x24 | (value & 0x80) | (value == 0 ? 2 : 0)),
                "load flags");
    }
    for (unsigned op : {0x24, 0x2c})
    for (unsigned a : {0x00, 0x01, 0x80, 0xff})
    for (unsigned value=0; value<256; ++value) {
        reset(0x8000);
        mem[0x8000] = 0xa9; mem[0x8001] = a;
        mem[0x8002] = op; mem[0x8003] = 0xff; mem[0x8004] = 0x40;
        mem[op == 0x24 ? 0xff : 0x40ff] = value;
        step(0x8002); step(op == 0x24 ? 0x8004 : 0x8005);
        require(cpu.bus_data_o == a, "BIT changed accumulator");
        require(cpu.status_o == (0x24 | (value & 0xc0) | ((a & value) ? 0 : 2)),
                "BIT flags");
    }
    const uint8_t branches[] = {0x10,0x30,0x50,0x70,0x90,0xb0,0xd0,0xf0};
    const uint16_t sites[] = {0x4000,0x40fe,0xfffe,0x0000};
    unsigned count = 0;
    for (unsigned flags = 0; flags < 16; ++flags)
    for (unsigned off = 0; off < 256; ++off)
    for (unsigned op : branches) for (uint16_t site : sites) {
        reset(0x8000);
        const bool n = flags & 8, v = flags & 4, c = flags & 2, z = flags & 1;
        mem[0x8000] = 0xa9; mem[0x8001] = z ? 0 : 1;
        mem[0x8002] = 0x2c; mem[0x8003] = 0; mem[0x8004] = 0x60;
        mem[0x6000] = (n ? 0x80 : 0) | (v ? 0x40 : 0) | 1;
        mem[0x8005] = c ? 0x38 : 0x18;
        mem[0x8006] = 0x4c; mem[0x8007] = site & 255; mem[0x8008] = site >> 8;
        mem[site] = op; mem[uint16_t(site+1)] = off;
        step(0x8002); step(0x8005); step(0x8006); step(site);
        const unsigned expected_p = 0x24 | (n ? 0x80 : 0) | (v ? 0x40 : 0)
                                  | (c ? 1 : 0) | (z ? 2 : 0);
        require(cpu.status_o == expected_p, "BIT/carry setup");
        bool taken = false;
        switch (op) {
            case 0x10: taken = !n; break; case 0x30: taken = n; break;
            case 0x50: taken = !v; break; case 0x70: taken = v; break;
            case 0x90: taken = !c; break; case 0xb0: taken = c; break;
            case 0xd0: taken = !z; break; case 0xf0: taken = z; break;
        }
        const int displacement = off < 128 ? int(off) : int(off) - 256;
        const uint16_t next = uint16_t(site + 2 + (taken ? displacement : 0));
        step(next);
        require(cpu.status_o == expected_p, "branch changed status");
        // Install and execute one exact target instruction, without landing padding.
        mem[next] = 0xa2; mem[uint16_t(next+1)] = 0x5a;
        step(uint16_t(next+2));
        require(cpu.x_o == 0x5a, "branch target instruction did not execute");
        ++count;
    }
    reset(0x8000);
    const uint8_t controls[] = {0x38,0x18,0x58,0x78,0xf8,0xd8,0xb8};
    const uint8_t results[] = {0x25,0x24,0x20,0x24,0x2c,0x24,0x24};
    for (unsigned i=0; i<7; ++i) {
        mem[0x8000+i] = controls[i]; step(0x8001+i);
        require(cpu.status_o == results[i], "flag control");
    }
    reset(0x8000);
    mem[0x8000]=0x24; mem[0x8001]=0xff; mem[0xff]=0xc0;
    mem[0x8002]=0xb8;
    step(0x8002); require(cpu.status_o == 0xe6, "BIT must set V before CLV");
    step(0x8003); require(cpu.status_o == 0xa6, "CLV must preserve N/Z/I");
    std::printf("PASS: 1536 memory loads, 2048 BIT cases, %u branches, flag controls\n", count);
}
