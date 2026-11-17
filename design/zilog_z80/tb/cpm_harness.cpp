// CP/M-80 harness for the Z80 core.
//
// Loads a .com image at 0x0100, traps the BDOS entry at 0x0005 and the warm
// boot at 0x0000, and captures console output. Only the BDOS functions the
// exercisers use are implemented (2 = console output, 9 = print string,
// 0 = terminate); anything else stops the run with a visible error rather than
// silently continuing.
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "Vzilog_z80.h"

namespace {

uint8_t g_mem[0x10000];
std::string g_out;
uint64_t g_instructions = 0;

struct Dut {
  Vzilog_z80 d;
  void reset() {
    d.rst_n = 0;
    d.bus_ready_i = 1;
    d.int_i = 0;
    d.nmi_i = 0;
    for (int i = 0; i < 4; i++) {
      d.clk = 0; d.eval();
      d.clk = 1; d.eval();
    }
    d.rst_n = 1;
  }
  bool step() {  // returns true when an instruction retired
    bool retired = false;
    // One instruction can take several implementation steps; run until the
    // retire pulse is seen (or the CPU halts).
    for (int guard = 0; guard < 200; guard++) {
      d.clk = 0;
      d.bus_ready_i = 1;
      d.bus_rdata_i = d.bus_io_o ? 0xFF : g_mem[d.bus_addr_o & 0xFFFF];
      d.eval();
      if (d.bus_write_o && !d.bus_io_o)
        g_mem[d.bus_addr_o & 0xFFFF] = (uint8_t)d.bus_wdata_o;
      d.clk = 1;
      d.eval();
      if (d.retire_o) { retired = true; break; }
      if (d.halt_o) break;
    }
    return retired;
  }
  uint16_t pc() const { return (uint16_t)d.pc_o; }
  uint16_t sp() const { return (uint16_t)d.sp_o; }
  void set_sp(uint16_t v) { /* SP is set by an instruction in the loader */ }
};

uint8_t rd8(uint16_t a) { return g_mem[a]; }
void wr8(uint16_t a, uint8_t v) { g_mem[a] = v; }
uint16_t rd16(uint16_t a) { return (uint16_t)(g_mem[a] | (g_mem[a + 1] << 8)); }
void wr16(uint16_t a, uint16_t v) { g_mem[a] = (uint8_t)v; g_mem[a + 1] = (uint8_t)(v >> 8); }
uint8_t rd_reg(Vzilog_z80& d, int idx) {
  // regs_o = {A,F,B,C,D,E,H,L}
  return (uint8_t)(d.regs_o >> (56 - 8 * idx));
}

void put(const std::string& s) {
  g_out += s;
  std::fputs(s.c_str(), stdout);
}

// Executes one BDOS call at 0x0005 and returns to the caller.
bool bdos(Vzilog_z80& d) {
  const uint8_t fn = rd_reg(d, 3);      // C
  // regs_o packs {A,F,B,C,D,E,H,L}: D is index 4, E is index 5.
  const uint16_t de = (uint16_t)((rd_reg(d, 4) << 8) | rd_reg(d, 5));  // D:E
  bool alive = true;
  switch (fn) {
    case 0:  // terminate
      alive = false;
      break;
    case 2:  // console output
      put(std::string(1, (char)(de & 0xFF)));
      break;
    case 9: {  // print string until '$'
      uint16_t a = de;
      std::string s;
      for (int i = 0; i < 4096; i++) {
        const uint8_t c = rd8(a++);
        if (c == '$') break;
        s.push_back((char)c);
      }
      put(s);
      break;
    }
    default:
      std::printf("\n[cpm] unsupported BDOS function %u\n", fn);
      alive = false;
      break;
  }
  return alive;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    std::printf("usage: cpm_harness <image.com> [max_instructions]\n");
    return 2;
  }
  const char* path = argv[1];
  const uint64_t limit = (argc > 2) ? std::strtoull(argv[2], nullptr, 0) : 2000000ull;

  std::FILE* f = std::fopen(path, "rb");
  if (!f) { std::printf("cannot open %s\n", path); return 2; }
  std::fseek(f, 0, SEEK_END);
  const long size = std::ftell(f);
  std::fseek(f, 0, SEEK_SET);
  std::vector<uint8_t> image((size_t)size);
  if (std::fread(image.data(), 1, image.size(), f) != image.size()) {
    std::printf("short read\n");
    std::fclose(f);
    return 2;
  }
  std::fclose(f);
  if (image.size() > 0x10000 - 0x100) { std::printf("image too large\n"); return 2; }

  std::memset(g_mem, 0x00, sizeof(g_mem));
  // BDOS stub at 0x0005: RET (the harness services the call at the boundary).
  g_mem[0x0005] = 0xC9;
  for (size_t i = 0; i < image.size(); i++) g_mem[0x0100 + i] = image[i];

  static Dut dut;
  dut.reset();

  // 0x0000: JP 0x0100. SP starts at 0 and wraps to 0xFFFF on the first push;
  // CP/M programs set their own stack before heavy use.
  g_mem[0x0000] = 0xC3; g_mem[0x0001] = 0x00; g_mem[0x0002] = 0x01;  // JP 0x0100
  g_mem[0x0005] = 0xC9;                                            // RET (BDOS stub)

  std::printf("[cpm] loaded %s (%ld bytes), limit %llu instructions\n", path, size,
              (unsigned long long)limit);

  bool alive = true;
  while (alive) {
    if (!dut.step()) {
      if (dut.d.halt_o) { std::printf("\n[cpm] halted\n"); }
      break;
    }
    g_instructions++;
    const uint16_t pc = dut.pc();
    if (pc == 0x0005) {
      alive = bdos(dut.d);
      // Returning is the stub's job: 0x0005 holds RET, so the next step pops
      // the caller's address and execution resumes there.
      continue;
    }
    if (pc == 0x0000) {
      std::printf("\n[cpm] warm boot (0x0000)\n");
      break;
    }
    if (g_instructions >= limit) {
      std::printf("\n[cpm] instruction limit reached (%llu)\n",
                  (unsigned long long)g_instructions);
      break;
    }
    if (g_out.size() > 200000) { std::printf("\n[cpm] output limit reached\n"); break; }
  }

  std::printf("\n[cpm] instructions executed: %llu\n", (unsigned long long)g_instructions);
  return 0;
}
