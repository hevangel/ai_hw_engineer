// Am29332 verification driver. Expectations come from the external
// functional oracle (scripts/generate_oracle.py), which steps through the
// same drive sequence including the PASS-STAT / PASS-Q readback windows.
// Vector fields (hex): instr p w da db pa pb mcin mlink borow macro rs hold
// slave oey_n y_ext py_ext cznvl_ext perr_ext edge exp_y exp_yoe exp_py
// exp_cznvl exp_perr exp_mserr. Outputs are checked before each clock edge;
// the edge then updates the status/Q registers unless HOLD is high.
#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>

static Vtb_top dut;
static uint64_t checks = 0, cases = 0, failures = 0;
static const char* where = "startup";

static unsigned long long cur_instr;

static void eq(unsigned long long got, unsigned long long want,
               const char* what, unsigned long long idx) {
  ++checks;
  if (got != want) {
    ++failures;
    if (failures <= 20)
      std::cout << "MISMATCH case " << idx << " instr=" << std::hex
                << cur_instr << " at " << where << ": " << what << " got "
                << got << " expected " << want << std::dec << "\n";
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  try {
    if (argc != 2) throw std::runtime_error("usage: tb_am29332_driver vectors");
    std::ifstream in(argv[1]);
    if (!in) throw std::runtime_error("missing oracle vectors");
    unsigned long long v[26];
    unsigned f;
    dut.cp_i = 0;
    dut.eval();
    while (in >> std::hex >> f) {
      v[0] = f;
      for (unsigned i = 1; i < 26; ++i)
        if (!(in >> std::hex >> v[i])) throw std::runtime_error("short vector");
      ++cases;
      where = "drive";
      cur_instr = v[0];
      dut.instr_i = v[0];
      dut.p_i = v[1];
      dut.w_i = v[2];
      dut.da_i = v[3];
      dut.db_i = v[4];
      dut.pa_i = v[5];
      dut.pb_i = v[6];
      dut.mcin_i = v[7];
      dut.mlink_i = v[8];
      dut.borow_i = v[9];
      dut.macro_i = v[10];
      dut.rs_i = v[11];
      dut.hold_i = v[12];
      dut.slave_i = v[13];
      dut.oey_n_i = v[14];
      dut.y_ext_i = v[15];
      dut.py_ext_i = v[16];
      dut.cznvl_ext_i = v[17];
      dut.perr_ext_i = v[18];
      dut.eval();
      where = "check";
      eq(dut.y_oe_o, v[21], "y_oe", cases);
      if (v[21]) eq(dut.y_o, v[20], "y", cases);
      eq(dut.py_o, v[22], "py", cases);
      eq(dut.cznvl_o, v[23], "cznvl", cases);
      eq(dut.perr_o, v[24], "perr", cases);
      eq(dut.mserr_o, v[25], "mserr", cases);
      if (v[19]) {
        dut.cp_i = 1;
        dut.eval();
        dut.cp_i = 0;
        dut.eval();
      }
    }
    std::cout << "cases=" << cases << " checks=" << checks << " failures="
              << failures << "\n";
    if (failures != 0) {
      std::cout << "TEST FAILED\n";
      return 1;
    }
    std::cout << "TEST PASSED: am29332 lockstep vectors\n";
    return 0;
  } catch (const std::exception& e) {
    std::cout << "ERROR after " << cases << " cases: " << e.what() << "\n";
    return 2;
  }
}
