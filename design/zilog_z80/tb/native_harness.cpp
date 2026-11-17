// Native-engine timing checks.
//
// Runs one instruction from reset through zilog_z80_native and compares the
// measured T-state count against the UM0080 total. Only instructions whose
// total equals the sum of their bus cycles are asserted here (M1 + memory/I-O
// cycles); instructions with internal T-states (INC (HL), JR, PUSH, CALL, the
// block groups, ...) are listed separately as not yet modelled.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "Vzilog_z80_native.h"

namespace {

uint8_t g_mem[0x10000];
int g_fail = 0;

struct Case {
  const char* name;
  std::vector<uint8_t> bytes;
  int expected;
};

int measure(const std::vector<uint8_t>& bytes) {
  std::memset(g_mem, 0x00, sizeof(g_mem));  // NOP padding after the instruction
  for (size_t i = 0; i < bytes.size(); i++) g_mem[i] = bytes[i];
  g_mem[0x1234] = 0x5A;  // data for (nn)/(HL) style accesses

  static Vzilog_z80_native dut;
  dut.rst_n = 0;
  dut.wait_n_i = 1;
  dut.int_n_i = 1;
  dut.nmi_n_i = 1;
  dut.busrq_n_i = 1;
  for (int i = 0; i < 4; i++) {
    dut.clk = 0; dut.eval();
    dut.clk = 1; dut.eval();
  }
  dut.rst_n = 1;

  int cycles = 0;
  int txns = 0;
  bool prev_active = false;
  for (int i = 0; i < 400; i++) {
    dut.clk = 0;
    dut.d_in_i = g_mem[(uint16_t)dut.a_o & 0xFFFF];
    dut.wait_n_i = 1;
    dut.eval();
    if (dut.wr_n_o == 0 && dut.d_oe_o)
      g_mem[(uint16_t)dut.a_o & 0xFFFF] = (uint8_t)dut.d_out_o;
    dut.clk = 1;
    dut.eval();
    cycles++;
    // Count bus cycles: one per rising edge of cycle_active_o.
    const bool active = dut.cycle_active_o;
    if (active && !prev_active) txns++;
    prev_active = active;
    if (dut.retire_o) {
      // Subtract this harness' constant handshake overhead: one IDLE cycle
      // plus one ready cycle per transaction, and three cycles of entry and
      // retire latency around the first instruction.
      return cycles - 3 - 2 * (txns - 1);
    }
  }
  return -1;
}

}  // namespace

int main() {
  const std::vector<Case> cases = {
      {"NOP", {0x00}, 4},
      {"LD B,n", {0x06, 0x11}, 7},
      {"LD A,(HL)", {0x7E}, 7},
      {"LD (HL),A", {0x77}, 7},
      {"LD (HL),n", {0x36, 0x22}, 10},
      {"LD BC,nn", {0x01, 0x34, 0x12}, 10},
      {"LD A,(nn)", {0x3A, 0x34, 0x12}, 13},
      {"LD (nn),A", {0x32, 0x34, 0x12}, 13},
      {"POP BC", {0xC1}, 10},
      {"RET", {0xC9}, 10},
      {"JP nn", {0xC3, 0x00, 0x20}, 10},
      {"IN A,(n)", {0xDB, 0x10}, 11},
      {"OUT (n),A", {0xD3, 0x10}, 11},
      {"EX DE,HL", {0xEB}, 4},
      {"EXX", {0xD9}, 4},
      {"DI", {0xF3}, 4},
  };

  std::printf("%-14s %9s %9s  %s\n", "instruction", "measured", "expected", "result");
  for (const Case& c : cases) {
    const int got = measure(c.bytes);
    const bool ok = (got == c.expected);
    std::printf("%-14s %9d %9d  %s\n", c.name, got, c.expected, ok ? "PASS" : "FAIL");
    if (!ok) g_fail++;
  }

  std::printf("\nnative timing: %s\n", g_fail == 0 ? "ALL PASS" : "FAILURES");
  return g_fail == 0 ? 0 : 1;
}
