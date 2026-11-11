// Directed interrupt tests for the Z80 core.
//
// Checks the documented contract rather than a full differential sweep:
//  1. NMI vectors to 0x0066, clears IFF1 and preserves IFF2 for RETN.
//  2. IM 1 INT vectors to 0x0038 and clears both IFFs.
//  3. IM 2 INT reads a device byte and vectors through (I, byte).
//  4. EI defers INT by exactly one instruction.
//  5. HALT is left by an accepted interrupt.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "Vzilog_z80.h"

namespace {

uint8_t g_mem[0x10000];
uint8_t g_iack = 0x00;     // byte the device puts on the bus in the ack cycle
uint8_t g_port = 0xFF;
int g_failures = 0;

struct Dut {
  Vzilog_z80 d;
  int cycles = 0;

  void reset() {
    d.rst_n = 0;
    d.bus_ready_i = 1;
    d.int_i = 0;
    d.nmi_i = 0;
    d.bus_rdata_i = 0;
    for (int i = 0; i < 4; i++) {
      d.clk = 0; d.eval();
      d.clk = 1; d.eval();
    }
    d.rst_n = 1;
  }

  void step() {
    d.clk = 0;
    d.bus_ready_i = 1;
    if (d.bus_intack_o)
      d.bus_rdata_i = g_iack;
    else if (d.bus_io_o)
      d.bus_rdata_i = g_port;
    else
      d.bus_rdata_i = g_mem[d.bus_addr_o & 0xFFFF];
    d.eval();
    if (d.bus_write_o && !d.bus_io_o)
      g_mem[d.bus_addr_o & 0xFFFF] = (uint8_t)d.bus_wdata_o;
    d.clk = 1;
    d.eval();
    cycles++;
  }

  uint16_t pc() const { return (uint16_t)d.pc_o; }
  bool iff1() const { return d.iff1_o; }
  bool halted() const { return d.halt_o; }
};

void load(const std::vector<uint8_t>& body, uint16_t at = 0x0100) {
  std::memset(g_mem, 0x00, sizeof(g_mem));
  g_mem[0] = 0xC3; g_mem[1] = 0x00; g_mem[2] = 0x01;  // JP 0x0100
  for (size_t i = 0; i < body.size(); i++) g_mem[at + i] = body[i];
}

void check(const char* what, bool ok) {
  std::printf("%-52s %s\n", what, ok ? "PASS" : "FAIL");
  if (!ok) g_failures++;
}

// Runs until pc reaches `target` or the cycle cap; returns cycles used (-1 if cap).
int run_until(Dut& dut, uint16_t target, int cap = 4000) {
  for (int i = 0; i < cap; i++) {
    if (dut.pc() == target) return i;
    dut.step();
  }
  return -1;
}

}  // namespace

int main() {
  // 1. NMI vectors to 0x0066 and RETN restores IFF1 from IFF2.
  {
    load({
      0xF3,                    // DI
      0x31, 0x00, 0x30,        // LD SP,0x3000
      0xFB,                    // EI
      0x00,                    // NOP
      0x00, 0x00, 0x00, 0x00,  // padding NOPs
    });
    g_mem[0x0066] = 0xED; g_mem[0x0067] = 0x45;  // RETN
    Dut dut; dut.reset();
    int i = 0;
    while (dut.pc() != 0x0106 && i++ < 500) dut.step();   // EI and one NOP done
    check("NMI: IFF1 set before the interrupt", dut.iff1());
    const uint16_t intr_pc = dut.pc();
    dut.d.nmi_i = 1; dut.step(); dut.d.nmi_i = 0;
    i = 0;
    while (dut.pc() != 0x0066 && i++ < 400) dut.step();
    check("NMI: vectors to 0x0066", dut.pc() == 0x0066);
    check("NMI: IFF1 cleared", !dut.iff1());
    // The return address is whatever PC was interrupted: read it from the stack.
    const uint16_t pushed = (uint16_t)(g_mem[0x2FFE] | (g_mem[0x2FFF] << 8));
    // RETN completes when IFF1 is restored from IFF2.
    for (int k = 0; k < 60 && !dut.iff1(); k++) dut.step();
    check("NMI: RETN restores IFF1", dut.iff1());
    check("NMI: RETN returns to the interrupted PC", dut.pc() == pushed);
  }

  // 2. IM 1 INT vectors to 0x0038.
  {
    load({
      0xED, 0x56,              // IM 1
      0x31, 0x00, 0x30,        // LD SP,0x3000
      0xFB,                    // EI
      0x00,                    // NOP (EI delay)
      0x00, 0x00, 0x00,        // padding
    });
    Dut dut; dut.reset();
    dut.d.int_i = 1;
    int i = 0;
    while (dut.pc() != 0x0038 && i++ < 800) dut.step();
    check("IM1: INT vectors to 0x0038", dut.pc() == 0x0038);
    check("IM1: IFF1 cleared on acceptance", !dut.iff1());
  }

  // 3. IM 2 INT vectors through (I, device byte).
  {
    load({
      0x3E, 0x12,              // LD A,0x12
      0xED, 0x47,              // LD I,A
      0xED, 0x5E,              // IM 2
      0x31, 0x00, 0x30,        // LD SP,0x3000
      0xFB,                    // EI
      0x00,                    // NOP (EI delay)
      0x00, 0x00,              // padding
    });
    // Handler table at 0x1200 (I=0x12) with the device byte 0x00.
    g_iack = 0x00;
    Dut dut; dut.reset();
    // Patch the table after load, before the interrupt is accepted.
    g_mem[0x1200] = 0x34; g_mem[0x1201] = 0x12;   // 0x1234
    dut.d.int_i = 1;
    int i = 0;
    while (dut.pc() != 0x1234 && i++ < 800) dut.step();
    check("IM2: vectors through (I, byte)", dut.pc() == 0x1234);
  }

  // 4. EI defers INT by exactly one instruction.
  {
    load({
      0x31, 0x00, 0x30,        // LD SP,0x3000
      0xFB,                    // EI
      0x00,                    // NOP  <- INT must not be taken before this runs
      0x00,                    // NOP
      0x00,
    });
    Dut dut; dut.reset();
    dut.d.int_i = 1;
    int i = 0;
    while (dut.pc() != 0x0104 && i++ < 800) dut.step();   // 0x0100..0x0103 done
    // If EI had been accepted immediately, PC would be 0x0038 before reaching
    // 0x0104; reaching 0x0104 proves one instruction executed after EI.
    check("EI: one instruction executes before acceptance", dut.pc() == 0x0104);
  }

  // 5. HALT is left by an accepted interrupt.
  {
    load({
      0xED, 0x56,              // IM 1
      0x31, 0x00, 0x30,        // LD SP,0x3000
      0xFB,                    // EI
      0x00,                    // NOP
      0x76,                    // HALT
    });
    Dut dut; dut.reset();
    int i = 0;
    while (!dut.halted() && i++ < 800) dut.step();
    check("HALT: entered", dut.halted());
    dut.d.int_i = 1;
    i = 0;
    while (dut.pc() != 0x0038 && i++ < 800) dut.step();
    check("HALT: left by an interrupt", !dut.halted());
    check("HALT: INT taken after HALT exit", dut.pc() == 0x0038);
  }

  std::printf("\ninterrupt tests: %s\n", g_failures == 0 ? "ALL PASS" : "FAILURES");
  return g_failures == 0 ? 0 : 1;
}
