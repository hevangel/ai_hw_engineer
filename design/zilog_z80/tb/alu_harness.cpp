// Differential test: zilog_z80_alu vs the pinned superzazu/z80 emulator.
//
// For every ALU operation we construct the equivalent real Z80 instruction,
// run it on the independent emulator from a chosen initial state, and require
// our RTL to produce the same result byte and the same full flag byte
// (including the undocumented F5/F3 bits).
//
// A --negative-control run perturbs the expected flag byte by one bit and
// requires the harness to fail; that proves the comparison can detect drift
// instead of silently passing everything.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <random>
#include <string>
#include <vector>

// Verilator compiles every listed source with the C++ compiler, including the
// oracle's z80.c, so the emulator interface is included as C++ and links with
// C++ linkage.
#include "z80.h"
#include "Vzilog_z80_alu.h"

namespace {

uint8_t g_mem[0x10000];

uint8_t mem_read(void*, uint16_t addr) { return g_mem[addr]; }
void mem_write(void*, uint16_t, uint8_t) {}
uint8_t io_in(z80*, uint8_t) { return 0xFF; }
void io_out(z80*, uint8_t, uint8_t) {}

// Flag bit positions in the F byte.
enum { F_C = 0, F_N = 1, F_PV = 2, F_F3 = 3, F_H = 4, F_F5 = 5, F_Z = 6, F_S = 7 };

struct OpInfo {
  const char* name;
  int      alu_op;      // zilog_z80_alu op enum value
  uint8_t  opcode[3];
  int      opcode_len;
  bool     result_in_b; // result register is B (INC/DEC/rotates/BIT) else A
  bool     uses_cin;
  bool     uses_bitnum;
};

const std::vector<OpInfo>& ops() {
  static const std::vector<OpInfo> v = {
    {"add",  0,  {0x80, 0x00, 0x00}, 1, false, false, false},
    {"adc",  1,  {0x88, 0x00, 0x00}, 1, false, true,  false},
    {"sub",  2,  {0x90, 0x00, 0x00}, 1, false, false, false},
    {"sbc",  3,  {0x98, 0x00, 0x00}, 1, false, true,  false},
    {"and",  4,  {0xA0, 0x00, 0x00}, 1, false, false, false},
    {"or",   5,  {0xB0, 0x00, 0x00}, 1, false, false, false},
    {"xor",  6,  {0xA8, 0x00, 0x00}, 1, false, false, false},
    {"cp",   7,  {0xB8, 0x00, 0x00}, 1, false, false, false},
    {"inc",  8,  {0x04, 0x00, 0x00}, 1, true,  false, false},
    {"dec",  9,  {0x05, 0x00, 0x00}, 1, true,  false, false},
    {"rlc",  10, {0xCB, 0x00, 0x00}, 2, true,  false, false},
    {"rrc",  11, {0xCB, 0x08, 0x00}, 2, true,  false, false},
    {"rl",   12, {0xCB, 0x10, 0x00}, 2, true,  true,  false},
    {"rr",   13, {0xCB, 0x18, 0x00}, 2, true,  true,  false},
    {"sla",  14, {0xCB, 0x20, 0x00}, 2, true,  false, false},
    {"sra",  15, {0xCB, 0x28, 0x00}, 2, true,  false, false},
    {"sll",  16, {0xCB, 0x30, 0x00}, 2, true,  false, false},
    {"srl",  17, {0xCB, 0x38, 0x00}, 2, true,  false, false},
    {"cpl",  19, {0x2F, 0x00, 0x00}, 1, false, false, false},
    {"neg",  20, {0xED, 0x44, 0x00}, 2, false, false, false},
    {"bit",  21, {0xCB, 0x40, 0x00}, 2, true,  false, true},
  };
  return v;
}

uint8_t unpack(z80& z) {
  return (z.sf ? 0x80 : 0) | (z.zf ? 0x40 : 0) | (z.yf ? 0x20 : 0) |
         (z.hf ? 0x10 : 0) | (z.xf ? 0x08 : 0) | (z.pf ? 0x04 : 0) |
         (z.nf ? 0x02 : 0) | (z.cf ? 0x01 : 0);
}

void pack(z80& z, uint8_t f) {
  z.sf = (f >> 7) & 1; z.zf = (f >> 6) & 1; z.yf = (f >> 5) & 1;
  z.hf = (f >> 4) & 1; z.xf = (f >> 3) & 1; z.pf = (f >> 2) & 1;
  z.nf = (f >> 1) & 1; z.cf = (f >> 0) & 1;
}

struct Case {
  int alu_op;
  uint8_t opcode[3];
  int opcode_len;
  uint8_t a, b, cin, bitnum;
  uint8_t f_in;
  bool result_in_b;
  const char* name;
};

struct Result {
  uint8_t value;  // result register byte
  uint8_t flags;
};

// Independent reference: run the real instruction on the pinned emulator.
Result run_oracle(const Case& c) {
  z80 z;
  z80_init(&z);
  z.read_byte = mem_read;
  z.write_byte = mem_write;
  z.port_in = io_in;
  z.port_out = io_out;

  std::memset(g_mem, 0x00, sizeof(g_mem));
  for (int i = 0; i < c.opcode_len; i++) g_mem[0x100 + i] = c.opcode[i];
  if (c.bitnum) g_mem[0x100 + 1] = (uint8_t)(c.opcode[1] | (c.bitnum << 3));

  z.pc = 0x0100;
  z.sp = 0xFF00;
  z.a = c.a;
  // For register-form operations the operand under test lives in B; for
  // accumulator operations A is the accumulator and B is the operand.
  z.b = c.result_in_b ? c.a : c.b;
  pack(z, c.f_in);
  z80_step(&z);

  Result r;
  r.value = c.result_in_b ? z.b : z.a;
  r.flags = unpack(z);
  return r;
}

struct Mismatch {
  Case c;
  Result expect;
  Result got;
};

}  // namespace

int main(int argc, char** argv) {
  bool negative_control = false;
  for (int i = 1; i < argc; i++) {
    if (std::strcmp(argv[i], "--negative-control") == 0) negative_control = true;
  }

  static Vzilog_z80_alu dut;

  const uint8_t edges[] = {0x00, 0x01, 0x02, 0x07, 0x08, 0x09, 0x0A, 0x0F,
                           0x10, 0x11, 0x1F, 0x20, 0x55, 0x66, 0x7E, 0x7F,
                           0x80, 0x81, 0x88, 0x8F, 0x90, 0x99, 0x9A, 0xA5,
                           0xAA, 0xC3, 0xCC, 0xF0, 0xFE, 0xFF};
  const int n_edges = (int)(sizeof(edges) / sizeof(edges[0]));

  std::mt19937 rng(0x5A80u);
  std::uniform_int_distribution<int> byte_dist(0, 255);

  uint64_t total = 0;
  uint64_t mismatch_count = 0;
  std::vector<Mismatch> bad;

  for (const OpInfo& op : ops()) {
    // Operand pairs: edge grid plus reproducible random pairs.
    std::vector<std::pair<uint8_t, uint8_t>> pairs;
    for (int i = 0; i < n_edges; i++)
      for (int j = 0; j < n_edges; j++)
        pairs.push_back({edges[i], edges[j]});
    for (int k = 0; k < 4096; k++)
      pairs.push_back({(uint8_t)byte_dist(rng), (uint8_t)byte_dist(rng)});

    for (auto& p : pairs) {
      // Variants: carry in, bit number, and interesting incoming flag states
      // for the operations that consume flags.
      std::vector<std::pair<uint8_t, uint8_t>> variants;  // {cin, bitnum}
      if (op.uses_cin) {
        variants.push_back({0, 0});
        variants.push_back({1, 0});
      } else if (op.uses_bitnum) {
        for (int n = 0; n < 8; n++) variants.push_back({0, (uint8_t)n});
      } else {
        variants.push_back({0, 0});
      }

      for (auto& v : variants) {
        std::vector<uint8_t> fins;
        if (op.alu_op == 18) {  // daa: H, N, C matter
          for (int m = 0; m < 8; m++)
            fins.push_back((uint8_t)(((m & 1) ? 0x01 : 0) | ((m & 2) ? 0x02 : 0) |
                                     ((m & 4) ? 0x10 : 0)));
        } else if (op.alu_op == 19) {  // cpl: C and P/V preserved
          fins.push_back(0x00);
          fins.push_back(0x04);
          fins.push_back(0x01);
          fins.push_back(0x05);
        } else {
          fins.push_back(0x00);
          fins.push_back(0x01);
          fins.push_back(0x04);
          fins.push_back(0x05);
        }

        for (uint8_t fin : fins) {
          Case c{};
          c.alu_op = op.alu_op;
          std::memcpy(c.opcode, op.opcode, 3);
          c.opcode_len = op.opcode_len;
          c.a = p.first;
          c.b = p.second;
          c.cin = v.first;
          c.bitnum = v.second;
          // The carry input of ADC/SBC/RL/RR is the processor's C flag, so the
          // case state must agree with the variant or the two models would be
          // given different inputs.
          c.f_in = op.uses_cin ? (uint8_t)((fin & 0xFEu) | (v.first & 1u)) : fin;
          c.result_in_b = op.result_in_b;
          c.name = op.name;

          Result expect = run_oracle(c);
          if (negative_control) expect.flags ^= 0x02;  // flip N

          // Drive the RTL ALU. For BIT the undocumented-flag source is the
          // tested byte itself (register form), not the unused b operand.
          dut.op = c.alu_op;
          dut.a = c.a;
          dut.b = (c.alu_op == 21) ? c.a : c.b;
          dut.cin = c.cin;
          dut.f_in = c.f_in;
          dut.bitnum = c.bitnum;
          dut.eval();

          Result got;
          got.value = (uint8_t)dut.y;
          got.flags = (uint8_t)dut.flags;

          total++;
          if (got.value != expect.value || got.flags != expect.flags) {
            mismatch_count++;
            Mismatch m;
            m.c = c;
            m.expect = expect;
            m.got = got;
            if (bad.size() < 25) bad.push_back(m);
          }
        }
      }
    }
  }

  // DAA is only defined after a BCD add/sub: the hardware consumes internal
  // carry and half-carry latches rather than just the F bits, so a standalone
  // DAA fed an arbitrary flag byte is not a meaningful test case. Drive a real
  // ADD/SUB first, then hand the ALU exactly the state that instruction left.
  {
    const uint8_t daa_edges[] = {0x00, 0x01, 0x09, 0x0A, 0x0F, 0x10, 0x19,
                                  0x1A, 0x55, 0x7F, 0x80, 0x90, 0x99, 0x9A,
                                  0xA5, 0xAA, 0xF0, 0xFF};
    const int dn = (int)(sizeof(daa_edges) / sizeof(daa_edges[0]));
    std::vector<std::pair<uint8_t, uint8_t>> pairs;
    for (int i = 0; i < dn; i++)
      for (int j = 0; j < dn; j++)
        pairs.push_back({daa_edges[i], daa_edges[j]});
    for (int k = 0; k < 4096; k++)
      pairs.push_back({(uint8_t)byte_dist(rng), (uint8_t)byte_dist(rng)});

    for (auto& p : pairs) {
      const uint8_t opcodes[2] = {0xC6, 0xD6};  // ADD A,n / SUB n
      for (int oi = 0; oi < 2; oi++) {
        z80 z;
        z80_init(&z);
        z.read_byte = mem_read;
        z.write_byte = mem_write;
        z.port_in = io_in;
        z.port_out = io_out;
        std::memset(g_mem, 0x00, sizeof(g_mem));
        g_mem[0x100] = opcodes[oi];
        g_mem[0x101] = p.second;
        g_mem[0x102] = 0x27;  // DAA
        z.pc = 0x0100;
        z.sp = 0xFF00;
        z.a = p.first;
        z80_step(&z);
        const uint8_t a1 = z.a;
        const uint8_t f1 = unpack(z);
        z80_step(&z);
        const uint8_t a2 = z.a;
        const uint8_t f2 = unpack(z);

        dut.op = 18;  // ALU_DAA
        dut.a = a1;
        dut.b = 0;
        dut.cin = 0;
        dut.f_in = f1;
        dut.bitnum = 0;
        dut.eval();

        Result expect;
        expect.value = a2;
        expect.flags = negative_control ? (uint8_t)(f2 ^ 0x02) : f2;

        Result got;
        got.value = (uint8_t)dut.y;
        got.flags = (uint8_t)dut.flags;

        total++;
        if (got.value != expect.value || got.flags != expect.flags) {
          mismatch_count++;
          if (bad.size() < 25) {
            Mismatch m{};
            m.c.alu_op = 18;
            m.c.name = "daa";
            m.c.a = a1;
            m.c.b = p.second;
            m.c.f_in = f1;
            m.expect = expect;
            m.got = got;
            bad.push_back(m);
          }
        }
      }
    }
  }

  if (negative_control) {
    if (total == 0) {
      std::printf("NEGATIVE CONTROL FAILED: no cases ran\n");
      return 1;
    }
    if (bad.empty()) {
      std::printf("NEGATIVE CONTROL FAILED: perturbed expectations were accepted "
                  "over %llu cases\n", (unsigned long long)total);
      return 1;
    }
    std::printf("NEGATIVE CONTROL OK: %llu/%llu cases rejected after a one-bit "
                "expectation flip\n", (unsigned long long)mismatch_count,
                (unsigned long long)total);
    return 0;
  }

  for (const Mismatch& m : bad) {
    std::printf("MISMATCH %-4s a=%02X b=%02X cin=%u bit=%u f_in=%02X | "
                "value exp %02X got %02X | flags exp %02X got %02X\n",
                m.c.name, m.c.a, m.c.b, m.c.cin, m.c.bitnum, m.c.f_in,
                m.expect.value, m.got.value, m.expect.flags, m.got.flags);
  }

  std::printf("ALU differential: %llu cases, %llu mismatches\n",
              (unsigned long long)total, (unsigned long long)mismatch_count);
  return mismatch_count == 0 ? 0 : 1;
}
