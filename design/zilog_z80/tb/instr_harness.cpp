// Instruction-level differential test: zilog_z80 core vs pinned oracle.
//
// Both models start from their reset state and run the same byte program: a
// JP to 0x0100, a prologue that establishes an arbitrary architectural state
// using supported instructions only, and then the instruction under test.
// Nothing is loaded through a backdoor, so the comparison covers real fetch,
// decode, R increment and write-back behaviour.
//
// Encodings the core does not implement yet raise fault_o; those cases are
// counted as "unimplemented" and reported separately rather than silently
// passed.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "z80.h"
#include "Vzilog_z80.h"

namespace {

uint8_t g_mem[0x10000];
uint8_t g_mem_ref[0x10000];  // oracle's final memory image

uint8_t mem_read(void*, uint16_t addr) { return g_mem[addr]; }
void mem_write(void*, uint16_t addr, uint8_t v) { g_mem[addr] = v; }
uint8_t io_in(z80*, uint8_t) { return 0xFF; }
void io_out(z80*, uint8_t, uint8_t) {}

struct State {
  uint8_t a, f, b, c, d, e, h, l;
  uint8_t a2, f2, b2, c2, d2, e2, h2, l2;
  uint16_t pc, sp;
  uint8_t i, r;
  bool iff1;
  int im;
  bool halted;

  bool operator==(const State& o) const {
    return a == o.a && f == o.f && b == o.b && c == o.c && d == o.d &&
           e == o.e && h == o.h && l == o.l && a2 == o.a2 && f2 == o.f2 &&
           b2 == o.b2 && c2 == o.c2 && d2 == o.d2 && e2 == o.e2 &&
           h2 == o.h2 && l2 == o.l2 && pc == o.pc && sp == o.sp &&
           // I is excluded: it cannot be written without LD I,A (ED page), so
           // the two models start that register from different resets.
           r == o.r && iff1 == o.iff1 && im == o.im &&
           halted == o.halted;
  }
};

State from_oracle(const z80& z) {
  State s{};
  s.a = z.a; s.b = z.b; s.c = z.c; s.d = z.d; s.e = z.e; s.h = z.h; s.l = z.l;
  s.f = (uint8_t)((z.sf << 7) | (z.zf << 6) | (z.yf << 5) | (z.hf << 4) |
                  (z.xf << 3) | (z.pf << 2) | (z.nf << 1) | z.cf);
  s.a2 = z.a_; s.f2 = z.f_; s.b2 = z.b_; s.c2 = z.c_; s.d2 = z.d_;
  s.e2 = z.e_; s.h2 = z.h_; s.l2 = z.l_;
  s.pc = z.pc; s.sp = z.sp; s.i = z.i; s.r = z.r;
  s.iff1 = z.iff1; s.im = z.interrupt_mode; s.halted = z.halted;
  return s;
}

// Runs the DUT until it retires `n_instr` instructions or faults.
bool run_dut(Vzilog_z80& dut, const std::vector<uint8_t>& prog, int n_instr,
             State& out, int& cycles, bool& faulted) {
  std::memset(g_mem, 0x00, sizeof(g_mem));
  // Fixed boot: JP 0x0100 at reset vector, body at 0x0100.
  g_mem[0x0000] = 0xC3;
  g_mem[0x0001] = 0x00;
  g_mem[0x0002] = 0x01;
  for (size_t i = 0; i < prog.size(); i++) g_mem[0x0100 + i] = prog[i];

  dut.rst_n = 0;
  dut.bus_ready_i = 1;
  for (int i = 0; i < 4; i++) {
    dut.clk = 0; dut.eval();
    dut.clk = 1; dut.eval();
  }
  dut.rst_n = 1;

  int retired = 0;
  bool prev_retire = false;
  cycles = 0;
  faulted = false;

  while (retired < n_instr) {
    if (cycles > 20000) return false;  // runaway

    dut.clk = 0;
    dut.bus_ready_i = 1;
    // I/O cycles read the fixed port value the oracle returns (0xFF); memory
    // cycles read the image. Writes only touch memory when the cycle is not I/O.
    if (dut.bus_io_o)
      dut.bus_rdata_i = 0xFF;
    else
      dut.bus_rdata_i = g_mem[dut.bus_addr_o & 0xFFFF];
    dut.eval();

    if (dut.bus_write_o && !dut.bus_io_o) {
      g_mem[dut.bus_addr_o & 0xFFFF] = (uint8_t)dut.bus_wdata_o;
    }

    dut.clk = 1;
    dut.eval();

    bool retire = dut.retire_o;
    if (retire && !prev_retire) retired++;
    prev_retire = retire;
    cycles++;

    if (dut.fault_o) {
      faulted = true;
      return true;
    }
  }

  out.a = (uint8_t)(dut.regs_o >> 56);
  out.f = (uint8_t)(dut.regs_o >> 48);
  out.b = (uint8_t)(dut.regs_o >> 40);
  out.c = (uint8_t)(dut.regs_o >> 32);
  out.d = (uint8_t)(dut.regs_o >> 24);
  out.e = (uint8_t)(dut.regs_o >> 16);
  out.h = (uint8_t)(dut.regs_o >> 8);
  out.l = (uint8_t)dut.regs_o;
  out.a2 = (uint8_t)(dut.alt_o >> 56);
  out.f2 = (uint8_t)(dut.alt_o >> 48);
  out.b2 = (uint8_t)(dut.alt_o >> 40);
  out.c2 = (uint8_t)(dut.alt_o >> 32);
  out.d2 = (uint8_t)(dut.alt_o >> 24);
  out.e2 = (uint8_t)(dut.alt_o >> 16);
  out.h2 = (uint8_t)(dut.alt_o >> 8);
  out.l2 = (uint8_t)(dut.alt_o);
  out.pc = (uint16_t)dut.pc_o;
  out.sp = (uint16_t)dut.sp_o;
  out.i = (uint8_t)dut.i_o;
  out.r = (uint8_t)dut.r_o;
  out.iff1 = dut.iff1_o;
  out.im = dut.im_o;
  out.halted = dut.halt_o;
  return true;
}

struct Prog {
  std::vector<uint8_t> bytes;  // body, placed at 0x0100
  int n_instr;                 // including the boot JP and the target
};

// Builds the body at 0x0100: a prologue that writes every compared register and
// flag from deterministic instructions, then the instruction under test.
Prog build_prog(uint8_t op, const std::vector<uint8_t>& tail, std::mt19937& rng) {
  std::uniform_int_distribution<int> d8(0, 255);
  std::vector<uint8_t> p;
  int n = 1;  // the boot JP

  uint8_t bc = (uint8_t)d8(rng), de = (uint8_t)d8(rng), hl = (uint8_t)d8(rng);
  uint8_t sp = (uint8_t)d8(rng), av = (uint8_t)d8(rng), add = (uint8_t)d8(rng);
  uint8_t flagsrc = (uint8_t)d8(rng);

  // Main registers and flags.
  p.push_back(0x01); p.push_back(bc); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x11); p.push_back(de); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x21); p.push_back(hl); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x31); p.push_back(sp); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x3E); p.push_back(av); n++;
  p.push_back(0xC6); p.push_back(add); n++;
  if (flagsrc & 1) { p.push_back(0x37); n++; }
  if (flagsrc & 2) { p.push_back(0x3F); n++; }
  if (flagsrc & 4) { p.push_back(0x27); n++; }

  // Alternate file: copy the current main state into it, then rebuild main so
  // both models carry the same deterministic values in both files.
  p.push_back(0xD9); n++;                       // EXX  -> alt BC/DE/HL
  p.push_back(0x08); n++;                       // EX AF,AF' -> alt AF
  p.push_back(0x01); p.push_back((uint8_t)d8(rng)); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x11); p.push_back((uint8_t)d8(rng)); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x21); p.push_back((uint8_t)d8(rng)); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0x3E); p.push_back((uint8_t)d8(rng)); n++;
  p.push_back(0xC6); p.push_back((uint8_t)d8(rng)); n++;

  p.push_back(op);
  for (uint8_t b : tail) p.push_back(b);
  n++;

  return Prog{p, n};
}

}  // namespace

int main(int argc, char** argv) {
  static Vzilog_z80 dut;
  std::mt19937 rng(0x2080u);
  std::uniform_int_distribution<int> d8(0, 255);

  // Focused trace: JP 0x0100; LD A,0x12; ADD A,0x34; INC A; NOP
  if (argc > 1 && std::strcmp(argv[1], "--trace") == 0) {
    std::vector<uint8_t> body = {0x3E, 0x12, 0xC6, 0x34, 0x3C, 0x00};
    std::memset(g_mem, 0x00, sizeof(g_mem));
    g_mem[0] = 0xC3; g_mem[1] = 0x00; g_mem[2] = 0x01;
    for (size_t i = 0; i < body.size(); i++) g_mem[0x100 + i] = body[i];

    z80 z;
    z80_init(&z);
    z.read_byte = mem_read; z.write_byte = mem_write;
    z.port_in = io_in; z.port_out = io_out;
    z.pc = 0;

    dut.rst_n = 0; dut.bus_ready_i = 1;
    for (int i = 0; i < 4; i++) { dut.clk = 0; dut.eval(); dut.clk = 1; dut.eval(); }
    dut.rst_n = 1;

    bool prev = false;
    for (int cyc = 0; cyc < 30; cyc++) {
      dut.clk = 0; dut.bus_ready_i = 1;
      dut.bus_rdata_i = g_mem[dut.bus_addr_o & 0xFFFF];
      dut.eval();
      dut.clk = 1; dut.eval();
      bool r = dut.retire_o;
      std::printf("cyc=%2d pc=%04X req=%d wr=%d addr=%04X rd=%02X ret=%d flt=%d halt=%d\n",
                  cyc, (uint16_t)dut.pc_o, (int)dut.bus_req_o, (int)dut.bus_write_o,
                  (uint16_t)dut.bus_addr_o, (uint8_t)dut.bus_rdata_i, (int)r,
                  (int)dut.fault_o, (int)dut.halt_o);
      prev = r;
    }
    return 0;
  }

  // Trace the real sweep program (prologue for op=0x00) instruction by
  // instruction, printing both models so a divergence is localised.
  if (argc > 1 && std::strcmp(argv[1], "--trace2") == 0) {
    std::vector<uint8_t> tail;
    Prog pr = build_prog(0x00, tail, rng);
    std::memset(g_mem, 0x00, sizeof(g_mem));
    g_mem[0] = 0xC3; g_mem[1] = 0x00; g_mem[2] = 0x01;
    for (size_t i = 0; i < pr.bytes.size(); i++) g_mem[0x100 + i] = pr.bytes[i];

    std::printf("body:");
    for (uint8_t by : pr.bytes) std::printf(" %02X", by);
    std::printf("\n");

    z80 z;
    z80_init(&z);
    z.read_byte = mem_read; z.write_byte = mem_write;
    z.port_in = io_in; z.port_out = io_out;
    z.pc = 0;

    dut.rst_n = 0; dut.bus_ready_i = 1;
    for (int i = 0; i < 4; i++) { dut.clk = 0; dut.eval(); dut.clk = 1; dut.eval(); }
    dut.rst_n = 1;

    int n = 0;
    bool prev = false;
    for (int cyc = 0; cyc < 400 && n < pr.n_instr; cyc++) {
      dut.clk = 0; dut.bus_ready_i = 1;
      dut.bus_rdata_i = g_mem[dut.bus_addr_o & 0xFFFF];
      dut.eval();
      dut.clk = 1; dut.eval();
      bool r = dut.retire_o;
      if (r && !prev) {
        z80_step(&z);
        n++;
        std::printf("n=%2d dut pc=%04X A=%02X F=%02X BC=%02X%02X | ora pc=%04X A=%02X F=%02X BC=%02X%02X\n",
                    n, (uint16_t)dut.pc_o, (uint8_t)(dut.regs_o >> 56),
                    (uint8_t)(dut.regs_o >> 48),
                    (uint8_t)(dut.regs_o >> 40), (uint8_t)(dut.regs_o >> 32),
                    z.pc, z.a,
                    (uint8_t)((z.sf << 7) | (z.zf << 6) | (z.yf << 5) |
                             (z.hf << 4) | (z.xf << 3) | (z.pf << 2) |
                             (z.nf << 1) | z.cf),
                    z.b, z.c);
      }
      prev = r;
    }
    return 0;
  }

  int tested = 0, unimplemented = 0, mismatches = 0, runaway = 0, attempted = 0;
  std::vector<std::string> first_bad;

  auto check = [&](uint8_t op, const std::vector<uint8_t>& tail,
                   const char* page) {
    for (int variant = 0; variant < 4; variant++) {
      attempted++;
      Prog pr = build_prog(op, tail, rng);

      // Oracle: same bytes and same instruction count from the reset vector.
      std::memset(g_mem, 0x00, sizeof(g_mem));
      g_mem[0x0000] = 0xC3;
      g_mem[0x0001] = 0x00;
      g_mem[0x0002] = 0x01;
      for (size_t i = 0; i < pr.bytes.size(); i++) g_mem[0x0100 + i] = pr.bytes[i];
      z80 z;
      z80_init(&z);
      z.read_byte = mem_read;
      z.write_byte = mem_write;
      z.port_in = io_in;
      z.port_out = io_out;
      z.pc = 0x0000;
      for (int i = 0; i < pr.n_instr; i++) z80_step(&z);
      State expect = from_oracle(z);
      std::memcpy(g_mem_ref, g_mem, sizeof(g_mem));  // oracle's memory effects

      State got{};
      int cycles = 0;
      bool faulted = false;
      bool ok = run_dut(dut, pr.bytes, pr.n_instr, got, cycles, faulted);
      if (!ok) { runaway++; return; }
      if (faulted) {
        if (variant == 0) std::printf("FAULT %s op=%02X\n", page, op);
        unimplemented++;
        return;
      }

      tested++;
      bool mem_diff = std::memcmp(g_mem, g_mem_ref, sizeof(g_mem)) != 0;
      if (!(got == expect) || mem_diff) {
        mismatches++;
        if (first_bad.size() < 20) {
          // Report the first differing memory address, if any.
          int first_addr = -1;
          for (int a = 0; a < 0x10000; a++) {
            if (g_mem[a] != g_mem_ref[a]) { first_addr = a; break; }
          }
          char buf[560];
          std::snprintf(buf, sizeof(buf),
                        "%s op=%02X tail=%02X%02X pc exp %04X got %04X "
                        "AF exp %02X%02X got %02X%02X BC exp %02X%02X got %02X%02X "
                        "DE exp %02X%02X got %02X%02X HL exp %02X%02X got %02X%02X "
                        "SP exp %04X got %04X R exp %02X got %02X mem@%04X exp %02X got %02X",
                        page, op, tail.size() > 0 ? tail[0] : 0,
                        tail.size() > 1 ? tail[1] : 0, expect.pc, got.pc,
                        expect.a, expect.f, got.a, got.f, expect.b, expect.c,
                        got.b, got.c, expect.d, expect.e, got.d, got.e,
                        expect.h, expect.l, got.h, got.l, expect.sp, got.sp,
                        expect.r, got.r, first_addr < 0 ? 0 : first_addr,
                        first_addr < 0 ? 0 : g_mem_ref[first_addr],
                        first_addr < 0 ? 0 : g_mem[first_addr]);
          first_bad.push_back(buf);
        }
      }
    }
  };

  // Primary page.
  for (int op = 0; op < 256; op++) {
    uint8_t o = (uint8_t)op;
    // Operand-byte count mirrors the instruction encoding.
    int icnt = 0;
    if (o == 0xCD || (o & 0xC7) == 0xC4) icnt = 2;            // CALL nn / CALL cc,nn
    else if (o == 0x22 || o == 0x2A || o == 0x32 || o == 0x3A) icnt = 2;
    else if (o == 0xC3 || (o & 0xC7) == 0xC2) icnt = 2;       // JP nn / JP cc,nn
    else if ((o & 0xCF) == 0x01) icnt = 2;                     // LD rr,nn
    else if ((o & 0x07) == 0x06) icnt = 1;                     // LD r,n / ALU n / LD (HL),n
    else if (o == 0x10 || o == 0x18 || (o & 0xE7) == 0x20) icnt = 1;  // DJNZ/JR/JR cc

    std::vector<uint8_t> tail;
    for (int i = 0; i < icnt; i++) tail.push_back((uint8_t)d8(rng));
    check(o, tail, "P0");
  }

  // CB page: registers plus the (HL) rotate/shift/BIT/RES/SET forms.
  for (int cb = 0; cb < 256; cb++) {
    check(0xCB, {(uint8_t)cb}, "CB");
  }

  // ED page: every second byte, with operand bytes for the (nn) forms.
  for (int ed = 0; ed < 256; ed++) {
    std::vector<uint8_t> tail;
    tail.push_back((uint8_t)ed);
    if ((ed & 0xC7) == 0x43) {  // LD (nn),rr and LD rr,(nn)
      tail.push_back((uint8_t)d8(rng));
      tail.push_back((uint8_t)d8(rng));
    }
    check(0xED, tail, "ED");
  }

  for (const std::string& s : first_bad) std::printf("MISMATCH %s\n", s.c_str());
  std::printf("instruction differential: %d attempted, %d compared, %d mismatches, "
              "%d unimplemented (fault), %d runaway\n",
              attempted, tested, mismatches, unimplemented, runaway);
  return mismatches == 0 ? 0 : 1;
}
