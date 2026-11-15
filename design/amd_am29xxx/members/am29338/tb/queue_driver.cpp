// Am29338 verification driver over the external oracle vectors
// (scripts/generate_oracle.py). Outputs are checked before each clock
// event; then the requested QCLK/DQCLK edges fire.
#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, qedges = 0, dqedges = 0;
static uint64_t failures = 0;

static void eq(unsigned long long got, unsigned long long want,
               const char* what) {
  ++checks;
  if (got != want) {
    ++failures;
    if (failures <= 25)
      std::cout << "MISMATCH case " << cases << ": " << what << " got "
                << std::hex << got << " expected " << want << "\n";
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2) throw std::runtime_error("usage: queue_driver vectors");
    std::ifstream in(argv[1]);
    if (!in) throw std::runtime_error("missing oracle vectors");
    unsigned long long v[13], e[11];
    dut.qclk_i = 0;
    dut.dqclk_i = 0;
    dut.eval();
    while (in >> std::hex >> v[0]) {
      for (unsigned i = 1; i < 13; ++i)
        if (!(in >> std::hex >> v[i])) throw std::runtime_error("short vector");
      for (unsigned i = 0; i < 11; ++i)
        if (!(in >> std::hex >> e[i])) throw std::runtime_error("short expect");
      ++cases;
      dut.qen_n_i = v[2]; dut.dqen_n_i = v[3];
      dut.bq_i = v[4]; dut.bdq_i = v[5]; dut.bsw_i = v[6];
      dut.d_i = v[7]; dut.pd_i = v[8]; dut.pos_i = v[9];
      dut.reset_n_i = v[10]; dut.rxmit_n_i = v[11]; dut.oe_n_i = v[12];
      dut.eval();
      if (e[10]) {
        eq(dut.y_o, e[0], "Y value");
        eq(dut.y_oe_o, e[1], "Y enable");
        if (e[1]) {
          eq(dut.py_o, e[2], "PY parity");
          eq(dut.pyerr_o, e[3], "PYERR");
        }
      } else {
        eq(dut.y_oe_o, e[1], "Y enable");
      }
      eq(dut.pderr_o, e[4], "PDERR");
      eq(dut.cnt_o, e[5], "CNT");
      eq(dut.full_o, e[6], "FULL");
      eq(dut.a_full_o, e[7], "A-FULL");
      eq(dut.empty_o, e[8], "EMPTY");
      eq(dut.a_empty_o, e[9], "A-EMPTY");
      if (v[0]) {
        dut.qclk_i = 1;
        dut.eval();
        dut.qclk_i = 0;
        dut.eval();
        ++qedges;
      }
      if (v[1]) {
        dut.dqclk_i = 1;
        dut.eval();
        dut.dqclk_i = 0;
        dut.eval();
        ++dqedges;
      }
    }
    std::cout << "TEST PASSED: " << cases << " drives, " << qedges
              << " QCLK edges, " << dqedges << " DQCLK edges, " << checks
              << " checks\n";
    if (failures != 0) throw std::runtime_error("mismatches found");
  } catch (const std::exception& e) {
    std::cerr << "TEST FAILED: " << e.what() << "\n";
    return 1;
  }
  dut.final();
  return 0;
}
