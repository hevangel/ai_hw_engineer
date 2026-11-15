// Am29323 verification driver. Expectations come from the external
// functional oracle (scripts/generate_oracle.py), which steps through the
// same drive sequence including readback windows. Each vector: apply all
// inputs with CLK low, check combinational outputs, then raise CLK if the
// vector requests an edge.
#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, edges = 0, failures = 0;
static const char* where = "startup";
static bool fail_once = false;

static void eq(unsigned long long got, unsigned long long want,
               const char* what) {
  ++checks;
  if (got != want) {
    ++failures;
    if (failures <= 20)
      std::cout << "MISMATCH case " << cases << " at " << where << ": "
                << what << " got " << std::hex << got << " expected "
                << want << "\n";
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2) throw std::runtime_error("usage: multiplier_driver oracle_vectors");
    std::ifstream in(argv[1]);
    if (!in) throw std::runtime_error("missing oracle vectors");
    unsigned long long v[26], e[6];
    unsigned f;
    dut.clk_i = 0;
    dut.eval();
    while (in >> std::hex >> f) {
      v[0] = f;
      for (unsigned i = 1; i < 26; ++i)
        if (!(in >> std::hex >> v[i])) throw std::runtime_error("short vector");
      for (unsigned i = 0; i < 6; ++i)
        if (!(in >> std::hex >> e[i])) throw std::runtime_error("short expect");
      ++cases;
      where = "drive";
      dut.x_i = v[0]; dut.y_i = v[1]; dut.px_i = v[2]; dut.py_i = v[3];
      dut.p_i = v[4]; dut.pp_i = v[5]; dut.parerr_i = v[6];
      dut.tcx_i = v[7]; dut.tcy_i = v[8];
      // cmd packing: {ACC1, ACC0, RND, TSEL, FA, PSEL1, PSEL0} MSB-first.
      dut.acc1_i = (v[9] >> 6) & 1; dut.acc0_i = (v[9] >> 5) & 1;
      dut.rnd_i = (v[9] >> 4) & 1; dut.tsel_i = (v[9] >> 3) & 1;
      dut.fa_i = (v[9] >> 2) & 1; dut.psel1_i = (v[9] >> 1) & 1;
      dut.psel0_i = v[9] & 1;
      dut.enxa_n_i = v[10]; dut.enxb_n_i = v[11]; dut.enya_n_i = v[12];
      dut.enyb_n_i = v[13]; dut.enp_n_i = v[14]; dut.eni_n_i = v[15];
      dut.ent_n_i = v[16];
      dut.ftx_i = v[17]; dut.fty_i = v[18]; dut.fti_i = v[19];
      dut.ftp_i = v[20]; dut.xsel_i = v[21]; dut.ysel_i = v[22];
      dut.oe_n_i = v[23]; dut.slave_i = v[24];
      const unsigned do_edge = (unsigned)v[25];
      dut.eval();
      eq(dut.p_o, e[0], "P value");
      eq(dut.p_oe_o, e[1], "P enable");
      eq(dut.pp_o, e[2], "PP parity");
      eq(dut.parerr_o, e[3], "PARERR");
      eq(dut.parerr_oe_o, e[4], "PARERR enable");
      eq(dut.harderr_o, e[5], "HARDERR");
      if (do_edge) {
        dut.clk_i = 1;
        dut.eval();
        dut.clk_i = 0;
        dut.eval();
        ++edges;
      }
    }
    if (failures != 0) throw std::runtime_error("verification mismatches");
    std::cout << "TEST PASSED: " << cases << " drives, " << edges
              << " edges, " << checks << " checks\n";
  } catch (const std::exception& e) {
    std::cerr << "TEST FAILED: " << e.what() << "\n";
    return 1;
  }
  dut.final();
  return 0;
}
