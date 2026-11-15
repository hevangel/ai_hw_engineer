// Am29337 verification driver over the external oracle vectors
// (scripts/generate_oracle.py).
#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, edges = 0;

static void eq(unsigned got, unsigned want, const char* what) {
  ++checks;
  if (got != want)
    throw std::runtime_error(std::string(what) + " got " +
                             std::to_string(got) + " expected " +
                             std::to_string(want) + " case " +
                             std::to_string(cases));
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2) throw std::runtime_error("usage: bounds_driver vectors");
    std::ifstream in(argv[1]);
    if (!in) throw std::runtime_error("missing oracle vectors");
    unsigned long long d, enl_n, enu_n, sgn, cil, ciu, edge, col, cou, oob;
    dut.clk_i = 0;
    dut.eval();
    while (in >> std::hex >> d) {
      if (!(in >> std::hex >> enl_n >> enu_n >> sgn >> cil >> ciu >> edge >>
            col >> cou >> oob))
        throw std::runtime_error("short vector");
      ++cases;
      dut.d_i = d;
      dut.enl_n_i = enl_n;
      dut.enu_n_i = enu_n;
      dut.signed_i = sgn;
      dut.cil_i = cil;
      dut.ciu_i = ciu;
      dut.eval();
      eq(dut.col_o, col, "COL");
      eq(dut.cou_o, cou, "COU");
      eq(dut.oob_o, oob, "OOB");
      if (edge) {
        dut.clk_i = 1;
        dut.eval();
        dut.clk_i = 0;
        dut.eval();
        ++edges;
      }
    }
    std::cout << "TEST PASSED: " << cases << " comparisons, " << edges
              << " edges, " << checks << " checks\n";
  } catch (const std::exception& e) {
    std::cerr << "TEST FAILED: " << e.what() << "\n";
    return 1;
  }
  dut.final();
  return 0;
}
