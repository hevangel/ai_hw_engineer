// Am29331 verification driver. Observes the DUT only through native pins:
// PC read back with the FC/CIN stall, SP and stack words through the D-bus
// (POP D with OED), counter through PUSH C then POP D, and interrupt/trap
// returns through the stack. All transition expectations come from the
// external manufacturer-table oracle (scripts/generate_oracle.py).
#include "Vtb_top.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <vector>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, firmwareWords = 0, stackWords = 0;
static const char* where = "startup";

static void eq(unsigned got, unsigned want, const char* what) {
  ++checks;
  if (got != want)
    throw std::runtime_error(std::string(what) + " got " + std::to_string(got) +
                             " expected " + std::to_string(want) + " case " +
                             std::to_string(cases) + " at " + where);
}

// Pin byte: bit0 fc, bit1 cin_n, bit2 oed, bit3 inten, bit4 intr,
// bit5 slave, bit6 hold, bit7 rst_n.
static constexpr unsigned P_RUN = 0x80;        // rst_n high, idle
static constexpr unsigned P_OED = 0x84;        // rst_n high, D driver on
static constexpr unsigned P_STALL = 0x82;      // rst_n high, CIN high
static constexpr unsigned P_READ = 0x86;       // rst_n high, CIN high, OED on

static void drive(unsigned op, unsigned pins, unsigned d = 0, unsigned s = 0,
                  unsigned t = 0, unsigned a = 0, unsigned y_in = 0,
                  const std::array<unsigned, 4>& m = {0, 0, 0, 0},
                  unsigned inta_i = 1, unsigned af_i = 0, unsigned eq_i = 0) {
  dut.cp_i = 0;
  dut.instr_i = op;
  dut.rst_n_i = (pins >> 7) & 1;
  dut.fc_i = pins & 1;
  dut.cin_n_i = (pins >> 1) & 1;
  dut.oed_i = (pins >> 2) & 1;
  dut.inten_i = (pins >> 3) & 1;
  dut.intr_i = (pins >> 4) & 1;
  dut.slave_i = (pins >> 5) & 1;
  dut.hold_i = (pins >> 6) & 1;
  dut.select_i = s;
  dut.test_i = t;
  dut.a_i = a;
  dut.d_i = d;
  dut.y_i = y_in;
  dut.m0_i = m[0];
  dut.m1_i = m[1];
  dut.m2_i = m[2];
  dut.m3_i = m[3];
  dut.inta_i = inta_i;
  dut.a_full_i = af_i;
  dut.equal_i = eq_i;
  dut.eval();
}

static void edge() {
  dut.cp_i = 1;
  dut.eval();
  dut.cp_i = 0;
  dut.eval();
}

static void apply(unsigned op, unsigned pins, unsigned d = 0) {
  drive(op, pins, d);
  edge();
}

static unsigned init_word(unsigned i, const std::array<unsigned, 6>& words) {
  return i < 6 ? words[i] : 0x6600 + i;
}

// Establish AR/SP/counter/comparator state through native instructions.
// Every continue-class instruction advances the address register, so the
// GOTO D that sets AR runs last.
static void initialize(unsigned ar, unsigned sp, unsigned depth,
                       const std::array<unsigned, 6>& words, unsigned c,
                       unsigned r, unsigned cmpen) {
  apply(0x30, 0x00);                                    // synchronous reset
  for (unsigned i = 0; i < depth; ++i)
    apply(0x35, P_RUN, init_word(i, words));            // PUSH D
  apply(0x3C, P_RUN, c);                                // LOAD D
  apply(0x3E, P_RUN, r);                                // SET
  if (!cmpen) apply(0x3F, P_RUN, 0);                    // CLEAR
  drive(0x20, P_RUN, ar);                               // GOTO D
  eq(dut.y_oe_o, 1, "GOTO D drives Y");
  eq(dut.y_o, ar, "GOTO D next address");
  edge();
  drive(0x30, P_READ, sp, 0, 0, 0, ar, {0, 0, 0, 0}, 1,
        sp >= 28 ? 1u : 0u, (cmpen && ar == r) ? 1u : 0u);
  eq(dut.y_o, ar, "init PC readback");
  eq(dut.d_o, sp, "init SP readback");
  eq(dut.a_full_o, sp >= 28 ? 1u : 0u, "init A-FULL");
  eq(dut.equal_o, (cmpen && ar == r) ? 1u : 0u, "init comparator");
  ++checks;
}

// One oracle transition: pre-edge pin checks, the clock edge, then state
// readback through the CONTINUE stall, POP D and PUSH C/POP D.
static void transition(const std::vector<unsigned>& v) {
  ++cases;
  const unsigned pins = v[1], valid = v[23], nwords = v[24];
  const bool hold = (pins >> 6) & 1;
  drive(v[0], pins, v[5], v[2], v[3], v[4], v[6], {v[7], v[8], v[9], v[10]},
        v[29], v[30], v[31]);
  eq(dut.y_oe_o, v[26], "Y enable");
  if (v[26] && (valid & 1)) eq(dut.y_o, v[25], "pre-edge Y");
  eq(dut.d_oe_o, v[28], "D enable");
  if (v[28] && (valid & 1)) eq(dut.d_o, v[27], "pre-edge D output");
  eq(dut.inta_oe_o, hold ? 0u : 1u, "INTA enable");
  eq(dut.a_full_oe_o, hold ? 0u : 1u, "A-FULL enable");
  eq(dut.equal_oe_o, hold ? 0u : 1u, "EQUAL enable");
  eq(dut.inta_o, v[29], "pre-edge INTA");
  eq(dut.a_full_o, v[30], "pre-edge A-FULL");
  if (valid & 1) eq(dut.equal_o, v[31], "pre-edge EQUAL");
  eq(dut.error_o, v[32], "pre-edge ERROR");
  edge();
  // CONTINUE with CIN high stalls the incrementer: Y shows PC, D shows SP.
  // The accept-cycle instruction completed normally, and the deferred
  // return-address push fires at the edge that ends this readback cycle,
  // so SP shown here is still one below the final pointer.
  const bool accepted = v[29] == 0;
  const unsigned sp_shown = accepted ? (v[34] + 63u) & 63u : v[34];
  drive(0x30, P_READ, sp_shown, 0, 0, 0, v[33], {0, 0, 0, 0}, 1,
        sp_shown >= 28 ? 1u : 0u, v[36]);
  if (valid & 1) eq(dut.y_o, v[33], "post-edge PC");
  eq(dut.d_o, sp_shown, "post-edge SP");
  eq(dut.a_full_o, sp_shown >= 28 ? 1u : 0u, "post-edge A-FULL");
  if (valid & 1) eq(dut.equal_o, v[36], "post-edge comparator");
  if (valid & 1) eq(dut.error_o, 0u, "readback contention-free");
  edge();  // a latched interrupt acceptance pushes its return address here
  for (unsigned k = 0; k < nwords; ++k) {
    drive(0x34, P_OED, v[37 + k]);                      // POP D
    eq(dut.d_o, v[37 + k], "post-edge stack word");
    edge();
    ++stackWords;
  }
  apply(0x39, P_RUN, 0);                                // PUSH C
  drive(0x34, P_OED, v[35]);                            // POP D
  if (valid & 1) eq(dut.d_o, v[35], "post-edge counter");
  edge();
}

static void transitions(const char* path) {
  std::ifstream in(path);
  if (!in) throw std::runtime_error("missing oracle vectors");
  std::vector<unsigned> v(45, 0);
  while (in >> std::hex >> v[0]) {
    for (unsigned i = 1; i < v.size(); ++i)
      if (!(in >> v[i])) throw std::runtime_error("short oracle vector");
    std::array<unsigned, 6> words{};
    for (unsigned i = 0; i < 6; ++i) words[i] = v[14 + i];
    initialize(v[11], v[12], v[13], words, v[20], v[21], v[22]);
    transition(v);
  }
  eq(cases, 81960, "transition count");
}

// Historical microcode flows: exact executed address, next address and
// post-edge PC for every word, with unmapped execution fatal. mutate_at
// replaces one visit's ROM word (loop tails that leave through the same
// address they previously looped from).
struct Word {
  unsigned op, pins, d, a, s, t, yin;
  std::array<unsigned, 4> m{0, 0, 0, 0};
};

static void historical(const std::map<unsigned, Word>& rom,
                       const std::vector<unsigned>& trace, int mutate_at = -1,
                       const Word& mutate = {0, 0, 0, 0, 0, 0, 0, {0, 0, 0, 0}}) {
  initialize(trace.front(), 0, 0, {}, 0, 0, 0);  // fresh state at entry
  for (unsigned i = 0; i + 1 < trace.size(); ++i) {
    static char where_buf[48];
    std::snprintf(where_buf, sizeof(where_buf), "flow@%x", trace[i]);
    where = where_buf;
    auto it = rom.find(trace[i]);
    if (it == rom.end())
      throw std::runtime_error("unmapped historical execution at " +
                               std::to_string(trace[i]));
    const Word w = (static_cast<int>(i) == mutate_at) ? mutate : it->second;
    const bool accept = ((w.pins >> 4) & 1) && ((w.pins >> 3) & 1);
    drive(w.op, w.pins, w.d, w.s, w.t, w.a, w.yin, w.m);
    if (accept) {
      eq(dut.y_oe_o, 0, "interrupt releases Y");
      eq(dut.inta_o, 0, "INTA on accept");
    } else {
      eq(dut.y_o, trace[i + 1], "historical exact next instruction");
    }
    edge();
    drive(0x30, P_STALL);
    eq(dut.y_o, trace[i + 1], "historical post-edge PC");
    ++firmwareWords;
  }
}

static std::map<unsigned, Word> sequential(unsigned first, unsigned last) {
  std::map<unsigned, Word> rom;
  for (unsigned a = first; a <= last; ++a) rom[a] = {0x30, P_RUN};
  return rom;
}

// Fresh sequencer state at the entry address of a microcode flow.
static void start_flow(unsigned entry) {
  initialize(entry, 0, 0, {}, 0, 0, 0);
}

static unsigned sp_now() {  // SP through the D-bus
  drive(0x30, P_READ);
  const unsigned sp = dut.d_o;
  edge();
  return sp;
}

// Original AMD Figure 3 microcode constructs plus the Figures 4-7 interrupt
// and trap flows, with exact addresses.
static void software() {
  { // Figure 3-2: FOR ... END FOR with a known iteration count. The counter
    // is loaded with N and DJMP_S exits when it reaches one; N=0 means 65536.
    auto rom = sequential(0x40, 0x44);
    rom[0x43] = {0x2F, P_RUN};                          // DJMP_S
    for (unsigned n : {0u, 1u, 2u, 5u}) {
      rom[0x40] = {0x31, P_RUN, n};                     // FOR D n
      std::vector<unsigned> trace{0x40};
      const unsigned iters = (n == 0) ? 65536u : n;
      for (unsigned i = 0; i < iters; ++i) {
        trace.push_back(0x41);
        trace.push_back(0x42);
        trace.push_back(0x43);
      }
      trace.push_back(0x44);
      historical(rom, trace);
      eq(sp_now(), 0u, "FOR loop frame popped");
    }
    rom[0x40] = {0x37, P_RUN, 0, 5};                    // FOR A 5
    std::vector<unsigned> trace{0x40};
    for (unsigned i = 0; i < 5; ++i) {
      trace.push_back(0x41);
      trace.push_back(0x42);
      trace.push_back(0x43);
    }
    trace.push_back(0x44);
    historical(rom, trace);
  }
  { // Figure 3-1: REPEAT ... UNTIL with LOOP and a conditional GOTO TOS.
    // The loop-back instruction repeats while its test passes and exits by
    // popping when it fails on the final visit.
    auto rom = sequential(0x50, 0x53);
    rom[0x50] = {0x33, P_RUN};                          // LOOP
    for (unsigned passes : {0u, 1u, 2u}) {
      for (unsigned op : {0x0Cu, 0x1Cu}) {              // BRCC_S / BRNC_S
        const unsigned loop_cc = (op == 0x0C) ? 1u : 0u;  // passes: repeat
        const unsigned exit_cc = (op == 0x0C) ? 0u : 1u;  // fails: exit
        rom[0x52] = {op, P_RUN, 0, 0, 0, loop_cc};
        std::vector<unsigned> trace{0x50};
        for (unsigned i = 0; i < passes; ++i) {
          trace.push_back(0x51);
          trace.push_back(0x52);
        }
        trace.push_back(0x51);
        trace.push_back(0x52);
        trace.push_back(0x53);                          // after the exit pop
        historical(rom, trace, static_cast<int>(trace.size()) - 2,
                   {op, P_RUN, 0, 0, 0, exit_cc});
        eq(sp_now(), 0u, "REPEAT frame popped");
      }
    }
  }
  { // Figure 3-1: WHILE ... END WHILE with LOOP, conditional EXIT and BRA_S.
    for (unsigned op : {0x02u, 0x12u}) {                // XTCC_D / XTNC_D
      auto rom = sequential(0x60, 0x65);
      rom[0x60] = {0x33, P_RUN};                        // LOOP
      rom[0x64] = {0x2C, P_RUN};                        // BRA_S to TOS
      const unsigned loop_cc = (op == 0x02) ? 0u : 1u;  // failing polarity
      const unsigned exit_cc = (op == 0x02) ? 1u : 0u;  // passing polarity
      rom[0x61] = {op, P_RUN, 0x65, 0, 0, loop_cc};
      std::vector<unsigned> trace{0x60};
      for (unsigned i = 0; i < 2; ++i) {
        trace.push_back(0x61);
        trace.push_back(0x62);
        trace.push_back(0x63);
        trace.push_back(0x64);
      }
      trace.push_back(0x61);
      trace.push_back(0x65);
      historical(rom, trace, static_cast<int>(trace.size()) - 2,
                 {op, P_RUN, 0x65, 0, 0, exit_cc});
      eq(sp_now(), 0u, "WHILE frame popped");
      rom[0x61] = {op, P_RUN, 0x65, 0, 0, exit_cc};
      historical(rom, {0x60, 0x61, 0x65});              // immediate exit
      eq(sp_now(), 0u, "WHILE immediate frame popped");
    }
  }
  { // Figure 3-3: CASE statement through PUSH D and GOTO M. D carries the
    // four-way table base with D1 D0 selecting the multiway set whose four
    // bits replace D3-D0, exactly as the datasheet's note prescribes.
    auto rom = sequential(0x1230, 0x1238);
    rom[0x1250] = {0x30, P_RUN};
    rom[0x1230] = {0x35, P_RUN, 0x1250};                // PUSH D B
    for (unsigned cs = 0; cs < 4; ++cs) {
      rom[0x1231] = {0x28, P_RUN, 0x1230 + cs, 0, 0, 0, 0, {2, 4, 6, 8}};  // BRA_M
      for (unsigned target : {0x1232u, 0x1234u, 0x1236u, 0x1238u})
        rom[target] = {0x2E, P_RUN};                    // RETURN to B
      historical(rom, {0x1230, 0x1231, 0x1232 + 2 * cs, 0x1250});
      eq(sp_now(), 0u, "CASE frame popped");
    }
  }
  { // Figure 3-4: double nested if-statement with PUSH D C and RETURNs.
    auto rom = sequential(0x1300, 0x1306);
    rom[0x1300] = {0x35, P_RUN, 0x1306};                // PUSH D C
    rom[0x1304] = {0x2E, P_RUN};                        // RETURN to C
    rom[0x1321] = {0x2E, P_RUN};
    rom[0x1330] = {0x2E, P_RUN};
    rom[0x1340] = {0x2E, P_RUN};
    struct Branch { unsigned addr, d, s, t; };
    for (const auto& [trace, ifs] : {
        // x=1, y=1: both inner tests fail, body runs, RETURN to C.
        std::pair<std::vector<unsigned>, std::array<Branch, 2>>{
            {0x1300, 0x1301, 0x1302, 0x1303, 0x1304, 0x1306},
            {Branch{0x1301, 0x1320, 0, 0x1}, Branch{0x1302, 0x1330, 1, 0x2}}},
        // x=1, y=0: second test passes, GOTO B, RETURN to C.
        std::pair<std::vector<unsigned>, std::array<Branch, 2>>{
            {0x1300, 0x1301, 0x1302, 0x1330, 0x1306},
            {Branch{0x1301, 0x1320, 0, 0x1}, Branch{0x1302, 0x1330, 1, 0x0}}},
        // x=0, z=1: first test passes to A, z fails, RETURN to C.
        std::pair<std::vector<unsigned>, std::array<Branch, 2>>{
            {0x1300, 0x1301, 0x1320, 0x1321, 0x1306},
            {Branch{0x1301, 0x1320, 0, 0x0}, Branch{0x1320, 0x1340, 2, 0x4}}},
        // x=0, z=0: first test passes to A, z passes to D, RETURN to C.
        std::pair<std::vector<unsigned>, std::array<Branch, 2>>{
            {0x1300, 0x1301, 0x1320, 0x1340, 0x1306},
            {Branch{0x1301, 0x1320, 0, 0x0}, Branch{0x1320, 0x1340, 2, 0x0}}}}) {
      for (const auto& b : ifs) rom[b.addr] = {0x10, P_RUN, b.d, 0, b.s, b.t};
      historical(rom, trace);
      eq(sp_now(), 0u, "nested-if frame popped");
    }
  }
  { // Figures 4-5: interrupt at A, routine at B, return through the stack.
    auto rom = sequential(0x100, 0x102);
    rom[0x200] = {0x30, P_RUN};
    rom[0x201] = {0x2E, P_RUN};                         // RETURN
    rom[0x100] = {0x30, P_RUN | 0x18, 0, 0, 0, 0, 0x200};  // CONT, INTR+INTEN
    // The interrupted instruction completes; the routine returns to the
    // next sequential address.
    historical(rom, {0x100, 0x200, 0x201, 0x101, 0x102});
    eq(sp_now(), 0u, "interrupt frame popped");
  }
  { // Nested interrupts: each acceptance saves its own return address in
    // first-in last-out order.
    auto rom = sequential(0x100, 0x102);
    rom[0x200] = {0x30, P_RUN};
    rom[0x201] = {0x2E, P_RUN};
    rom[0x300] = {0x30, P_RUN};
    rom[0x301] = {0x2E, P_RUN};
    rom[0x100] = {0x30, P_RUN | 0x18, 0, 0, 0, 0, 0x200};
    rom[0x200] = {0x30, P_RUN | 0x18, 0, 0, 0, 0, 0x300};
    historical(rom, {0x100, 0x200, 0x300, 0x301, 0x201, 0x101, 0x102});
    eq(sp_now(), 0u, "nested interrupt frames popped");
  }
  { // Figures 6-7: trap at A with FC=1, CIN=1, INTR=1. The address register
    // already holds the trap return address; the routine returns there and
    // the trapped microinstruction re-executes.
    auto rom = sequential(0x100, 0x102);
    rom[0x200] = {0x30, P_RUN};
    rom[0x201] = {0x2E, P_RUN};
    rom[0x100] = {0x30, P_RUN | 0x1B, 0, 0, 0, 0, 0x200};  // FC+CIN+INTR+INTEN
    // The routine takes corrective measures before returning, so the
    // re-executed microinstruction runs as a plain continue.
    historical(rom, {0x100, 0x200, 0x201, 0x100, 0x101}, 3, {0x30, P_RUN});
    eq(sp_now(), 0u, "trap frame popped");
    // FC and CIN without INTR stall on the current address (trap request
    // path without the interrupt completion).
    initialize(0x150, 0, 0, {}, 0, 0, 0);
    drive(0x30, P_RUN | 0x03);
    eq(dut.y_oe_o, 1u, "trap stall drives Y");
    eq(dut.y_o, 0x150u, "trap stall repeats address");
    edge();
    drive(0x30, P_STALL);
    eq(dut.y_o, 0x150u, "trap stall post-edge PC");
  }
}

// The 33-entry envelope: fill to the full depth, drain through RET, then
// exercise the documented single-wrap overflow where a push onto a full
// stack overwrites the item at the bottom.
static void envelope() {
  std::array<unsigned, 6> words{};
  initialize(0, 0, 0, words, 0, 0, 0);
  for (unsigned i = 0; i < 33; ++i) apply(0x35, P_RUN, 0xA000 + i);  // PUSH D
  drive(0x30, P_READ);
  eq(dut.d_o, 33u, "SP at 33 after full fill");
  eq(dut.a_full_o, 1u, "A-FULL with full stack");
  edge();
  for (unsigned i = 0; i < 33; ++i) {
    drive(0x2E, P_RUN);                                 // RET
    eq(dut.y_o, 0xA000 + 32 - i, "stack LIFO drain");
    edge();
    ++stackWords;
  }
  eq(sp_now(), 0u, "SP empty after drain");
  for (unsigned i = 0; i < 34; ++i) apply(0x35, P_RUN, 0xB000 + i);
  drive(0x30, P_READ);
  eq(dut.d_o, 34u, "SP after overflow push");
  eq(dut.a_full_o, 1u, "A-FULL after overflow");
  edge();
  drive(0x2E, P_RUN);
  eq(dut.y_o, 0xB000 + 33u, "overflowed entry on top");
  edge();
  ++stackWords;
  for (unsigned i = 0; i < 32; ++i) {
    drive(0x2E, P_RUN);
    eq(dut.y_o, 0xB000 + 32 - i, "surviving stack after bottom overwrite");
    edge();
    ++stackWords;
  }
  eq(sp_now(), 1u, "SP after draining wrapped stack");
}

// Master contention and slave comparison through the ERROR pin.
static void master_slave() {
  std::array<unsigned, 6> words{};
  initialize(0x1234, 3, 3, words, 7, 0x1234, 1);
  drive(0x30, P_READ, 0xdead);                          // D driven, mismatch
  eq(dut.error_o, 1u, "master D contention");
  drive(0x30, P_READ, 3, 0, 0, 0, 0xbaad);              // Y driven, mismatch
  eq(dut.error_o, 1u, "master Y contention");
  drive(0x30, P_READ, 3, 0, 0, 0, 0x1234, {0, 0, 0, 0}, 1, 0, 1);
  eq(dut.error_o, 0u, "master clean");
  // Slave: computed outputs compared against the master-driven pins.
  drive(0x30, P_READ | 0x20, 3, 0, 0, 0, 0x1234, {0, 0, 0, 0}, 1, 0, 1);
  eq(dut.error_o, 0u, "slave agreeing");
  drive(0x30, P_READ | 0x20, 3, 0, 0, 0, 0xbaad);
  eq(dut.error_o, 1u, "slave Y mismatch");
  drive(0x30, P_READ | 0x20, 0xdead);
  eq(dut.error_o, 1u, "slave D mismatch");
  drive(0x30, P_READ | 0x20, 3, 0, 0, 0, 0x1234, {0, 0, 0, 0}, 0);
  eq(dut.error_o, 1u, "slave INTA mismatch");
  drive(0x30, P_READ | 0x20, 3, 0, 0, 0, 0x1234, {0, 0, 0, 0}, 1, 1);
  eq(dut.error_o, 1u, "slave A-FULL mismatch");
  drive(0x30, P_READ | 0x20, 3, 0, 0, 0, 0x1234, {0, 0, 0, 0}, 1, 0, 0);
  eq(dut.error_o, 1u, "slave EQUAL mismatch");
  drive(0x30, P_READ | 0x20 | 0x40, 3);                 // hold gates ERROR
  eq(dut.error_o, 0u, "hold silences ERROR");
  // Slave interrupt acceptance compares the acknowledge like the master.
  initialize(0x100, 0, 0, words, 0, 0, 0);
  drive(0x30, P_RUN | 0x38, 0, 0, 0, 0, 0x200, {0, 0, 0, 0}, 0);
  eq(dut.inta_o, 0u, "slave INTA on accept");
  eq(dut.error_o, 0u, "slave accepting cleanly");
  drive(0x30, P_RUN | 0x38, 0, 0, 0, 0, 0x200, {0, 0, 0, 0}, 1);
  eq(dut.error_o, 1u, "slave INTA mismatch on accept");
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2)
      throw std::runtime_error("usage: sequencer_driver oracle_vectors");
    transitions(argv[1]);
    software();
    envelope();
    master_slave();
    std::cout << "TEST PASSED: " << cases << " manufacturer-table transitions, "
              << firmwareWords << " historical microcode words, " << stackWords
              << " stack words, " << checks << " checks\n";
  } catch (const std::exception& e) {
    std::cerr << "TEST FAILED: " << e.what() << "\n";
    return 1;
  }
  dut.final();
  return 0;
}
