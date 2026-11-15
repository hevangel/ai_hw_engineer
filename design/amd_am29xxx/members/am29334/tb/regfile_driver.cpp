// Am29334 verification driver. Observes the DUT only through native pins.
// The vector stream includes readback windows (read address, both latches
// transparent, OE on the observed side), so RAM contents are checked
// through the output latches exactly as the system would. Expectations
// come from the external functional oracle (scripts/generate_oracle.py),
// which steps through the same drive sequence.
#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, readWindows = 0;
static const char* where = "startup";

static void eq(unsigned long long got, unsigned long long want, const char* what) {
  ++checks;
  if (got != want)
    throw std::runtime_error(std::string(what) + " got " +
                             std::to_string(got) + " expected " +
                             std::to_string(want) + " case " +
                             std::to_string(cases) + " at " + where);
}

static void drive(unsigned ara, unsigned awa, unsigned arb, unsigned awb,
                  unsigned da, unsigned db, unsigned bits) {
  dut.ara_i = ara;
  dut.awa_i = awa;
  dut.arb_i = arb;
  dut.awb_i = awb;
  dut.da_i = da;
  dut.db_i = db;
  dut.lea_i = bits & 1;
  dut.leb_i = (bits >> 1) & 1;
  dut.oea_n_i = (bits >> 2) & 1;
  dut.oeb_n_i = (bits >> 3) & 1;
  dut.wea_c_n_i = (bits >> 4) & 1;
  dut.wea_l_n_i = (bits >> 5) & 1;
  dut.wea_h_n_i = (bits >> 6) & 1;
  dut.web_c_n_i = (bits >> 7) & 1;
  dut.web_l_n_i = (bits >> 8) & 1;
  dut.web_h_n_i = (bits >> 9) & 1;
  dut.eval();
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2) throw std::runtime_error("usage: regfile_driver oracle_vectors");
    std::ifstream in(argv[1]);
    if (!in) throw std::runtime_error("missing oracle vectors");
    unsigned ara, awa, arb, awb, da, db, bits, ya, yb, valid;
    // Establish the model's prewritten landscape (cells 0..63 = low
    // 0x100+i, high 0xA0+i) through the A write port.
    for (unsigned i = 0; i < 64; ++i)
      drive(i, i, 0, 0,
            (((0x0A0u + i) & 0x1FFu) << 9) | ((0x100u + i) & 0x1FFu),
            0, 0x00u);
    while (in >> std::hex >> ara) {
      if (!(in >> std::hex >> awa >> arb >> awb >> da >> db >> bits >> ya >>
            yb >> valid))
        throw std::runtime_error("short oracle vector");
      ++cases;
      where = "drive";
      drive(ara, awa, arb, awb, da, db, bits);
      eq(dut.ya_oe_o, ((bits >> 2) & 1) ? 0u : 1u, "YA enable");
      eq(dut.yb_oe_o, ((bits >> 3) & 1) ? 0u : 1u, "YB enable");
      if ((valid & 1) && dut.ya_oe_o) eq(dut.ya_o, ya, "YA value");
      if ((valid & 2) && dut.yb_oe_o) eq(dut.yb_o, yb, "YB value");
    }
    std::cout << "TEST PASSED: " << cases << " drive cases, " << checks
              << " checks\n";
  } catch (const std::exception& e) {
    std::cerr << "TEST FAILED: " << e.what() << "\n";
    return 1;
  }
  dut.final();
  return 0;
}
