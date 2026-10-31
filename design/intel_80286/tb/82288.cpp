#include "Vintel_80286_82288.h"
#include "verilated.h"

#include <iostream>
#include <stdexcept>

static void check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

struct Bench {
    Vintel_80286_82288 dut;

    Bench() {
        dut.clk_i = 0;
        dut.reset_i = 1;
        dut.status_valid_i = 0;
        dut.m_io_i = 0;
        dut.s1_i = 0;
        dut.s0_i = 0;
        dut.cenl_i = 1;
        dut.cen_i = 1;
        dut.cmdly_i = 0;
        dut.ready_n_i = 1;
        dut.eval();
        period();
        dut.reset_i = 0;
        dut.eval();
    }

    void period() {
        dut.clk_i = 1;
        dut.eval();
        dut.clk_i = 0;
        dut.eval();
    }

    void start(bool memory, bool write, bool inta=false, bool halt=false,
               bool selected=true, bool delayed=false) {
        dut.status_valid_i = 1;
        dut.m_io_i = memory;
        dut.s1_i = write;
        dut.s0_i = !write && !inta && !halt;
        if (inta) {
            dut.m_io_i = 0;
            dut.s1_i = 0;
            dut.s0_i = 0;
        }
        if (halt) {
            dut.m_io_i = 1;
            dut.s1_i = 0;
            dut.s0_i = 0;
        }
        dut.cenl_i = selected;
        dut.cmdly_i = delayed;
        dut.ready_n_i = 1;
        dut.eval();
        period();
        dut.status_valid_i = 0;
        dut.eval();
    }

    void finish_cycle() {
        // Tc contains two external CLK periods; READY# is sampled at its end.
        period();
        period();
        check(dut.mrdc_n_o && dut.mwtc_n_o && dut.iorc_n_o &&
              dut.iowc_n_o && dut.inta_n_o && !dut.den_o && dut.dt_r_o,
              "completed cycle did not release command/data enables");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        Bench b;

        // Memory read: ALE occupies phase two of Ts; MRDC and DEN cover Tc.
        b.start(true, false);
        check(b.dut.ale_o && !b.dut.den_o,
              "memory-read Ts timing or ALE assertion was incorrect");
        b.period();
        check(!b.dut.ale_o && !b.dut.mrdc_n_o && b.dut.den_o && !b.dut.dt_r_o,
              "memory read did not assert MRDC/DEN with read direction in Tc");
        b.period();
        check(!b.dut.mrdc_n_o && b.dut.den_o,
              "memory-read command did not remain active through Tc");
        b.period();
        check(!b.dut.mrdc_n_o,
              "READY# high did not repeat Tc with command active");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // CEN is an asynchronous active-high gate; changing it needs no CLK.
        b.start(false, false);
        b.period();
        check(!b.dut.iorc_n_o && b.dut.den_o && !b.dut.dt_r_o,
              "I/O read decode failed");
        b.dut.cen_i = 0;
        b.dut.eval();
        check(b.dut.iorc_n_o && !b.dut.den_o,
              "CEN low did not asynchronously suppress IORC and DEN");
        b.dut.cen_i = 1;
        b.dut.eval();
        check(!b.dut.iorc_n_o && b.dut.den_o,
              "CEN high did not asynchronously restore the active I/O read");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // Write direction and DEN may be prepared in Ts phase two.
        b.start(true, true);
        check(b.dut.ale_o && b.dut.den_o && b.dut.dt_r_o,
              "write DEN/direction were not prepared during phase two of Ts");
        b.period();
        check(!b.dut.ale_o && !b.dut.mwtc_n_o && b.dut.iowc_n_o && b.dut.den_o &&
              b.dut.dt_r_o,
              "memory write strobes or direction were incorrect");
        b.dut.cen_i = 0;
        b.dut.eval();
        check(b.dut.mwtc_n_o && !b.dut.den_o,
              "CEN low failed to gate memory-write command and DEN");
        b.dut.cen_i = 1;
        b.dut.ready_n_i = 0;
        b.dut.eval();
        b.finish_cycle();

        // CMDLY delays command assertion, but READY may end the cycle first.
        b.start(false, false, false, false, true, true);
        check(b.dut.ale_o, "CMDLY affected ALE timing");
        b.period();
        check(b.dut.iorc_n_o && !b.dut.den_o,
              "CMDLY high did not delay the read command");
        b.dut.cmdly_i = 0;
        b.period();
        check(!b.dut.iorc_n_o && b.dut.den_o,
              "CMDLY low did not enable the delayed command");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // A bus can terminate before CMDLY has enabled a read command.
        b.start(false, false, false, false, true, true);
        b.dut.ready_n_i = 0;
        b.period();
        check(b.dut.iorc_n_o && !b.dut.den_o,
              "early-READY setup asserted a delayed I/O read command");
        b.period();
        b.period();
        check(b.dut.iorc_n_o && !b.dut.den_o,
              "READY low did not terminate a cycle before command activation");

        // CENL is latched high to select. A low sample suppresses commands,
        // DEN, and read direction while READY still terminates the cycle.
        b.start(true, false, false, false, false);
        check(b.dut.ale_o, "CENL selection incorrectly gated ALE");
        b.period();
        check(b.dut.mrdc_n_o && !b.dut.den_o && b.dut.dt_r_o,
              "CENL low did not suppress the selected read outputs");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // A write buffer can be prepared before the end-Ts CENL decision.
        b.start(true, true, false, false, false);
        check(b.dut.ale_o && b.dut.den_o && b.dut.dt_r_o,
              "write DEN was not prepared before the CENL selection boundary");
        b.period();
        check(!b.dut.ale_o && b.dut.mwtc_n_o && !b.dut.den_o && b.dut.dt_r_o,
              "CENL low did not suppress the prepared write at Tc start");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // INTA asserts MCE with ALE and keeps it for one extra system CLK.
        b.start(false, false, true);
        check(b.dut.ale_o && b.dut.mce_o && b.dut.inta_n_o,
              "INTA Ts did not assert ALE/MCE without an early INTA strobe");
        b.period();
        check(!b.dut.ale_o && b.dut.mce_o && !b.dut.inta_n_o,
              "MCE did not extend one CLK beyond ALE into the INTA Tc");
        b.period();
        check(!b.dut.mce_o && !b.dut.inta_n_o,
              "MCE did not deassert after one extra CLK");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        b.start(false, false, true, false, false);
        b.dut.cen_i = 0;
        b.dut.eval();
        check(b.dut.ale_o && b.dut.mce_o && b.dut.inta_n_o,
              "CEN/CENL incorrectly gated ALE or MCE during unselected INTA");
        b.period();
        check(b.dut.mce_o && b.dut.inta_n_o,
              "MCE was affected by CEN or CENL");
        b.dut.ready_n_i = 0;
        b.finish_cycle();
        b.dut.cen_i = 1;

        // READY can hand a completed Tc directly to the next Ts without Ti.
        b.start(true, false);
        b.period();
        b.period();
        b.dut.ready_n_i = 0;
        b.dut.status_valid_i = 1;
        b.dut.m_io_i = 0;
        b.dut.s1_i = 1;
        b.dut.s0_i = 0;
        b.dut.eval();
        b.period();
        check(!b.dut.ale_o && b.dut.mrdc_n_o && b.dut.iowc_n_o,
              "completed Tc did not release outputs for the next Ts");
        b.dut.ready_n_i = 1;
        b.period();
        check(b.dut.ale_o && b.dut.iowc_n_o,
              "back-to-back I/O write did not enter phase two of Ts");
        b.dut.status_valid_i = 0;
        b.period();
        check(!b.dut.ale_o && !b.dut.iowc_n_o && b.dut.den_o && b.dut.dt_r_o,
              "back-to-back I/O write did not issue its Tc strobes");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        // HALT has no ALE or command. Reserved tuples also decode to no command.
        b.start(true, false, false, true);
        check(!b.dut.ale_o && !b.dut.den_o,
              "HALT status emitted ALE or DEN");
        b.period();
        check(b.dut.mrdc_n_o && b.dut.mwtc_n_o && b.dut.iorc_n_o &&
              b.dut.iowc_n_o && b.dut.inta_n_o,
              "HALT status emitted a command strobe");
        b.start(false, true);
        b.period();
        check(!b.dut.iowc_n_o && b.dut.iorc_n_o && b.dut.den_o && b.dut.dt_r_o,
              "I/O write did not assert IOWC/DEN with write direction");
        b.dut.ready_n_i = 0;
        b.finish_cycle();

        b.dut.status_valid_i = 1;
        b.dut.m_io_i = 0;
        b.dut.s1_i = 1;
        b.dut.s0_i = 1; // reserved I/O status tuple
        b.dut.ready_n_i = 1;
        b.dut.eval();
        b.period();
        b.dut.status_valid_i = 0;
        b.period();
        b.period();
        check(b.dut.mrdc_n_o && b.dut.mwtc_n_o && b.dut.iorc_n_o &&
              b.dut.iowc_n_o && b.dut.inta_n_o && !b.dut.den_o && b.dut.dt_r_o,
              "reserved status tuple emitted a command strobe");
        b.dut.ready_n_i = 0;
        b.period();
        b.period();

        std::cout << "PASS: 82288 local strobes, control gates, waits, ALE and MCE timing\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
