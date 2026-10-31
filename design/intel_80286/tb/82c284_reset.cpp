#include "Vintel_80286_82c284_reset.h"
#include "verilated.h"

#include <cstdlib>
#include <iostream>
#include <stdexcept>

static void check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        const unsigned delay_clks = argc > 1
            ? static_cast<unsigned>(std::strtoul(argv[1], nullptr, 10)) : 2;
        check(delay_clks == 1 || delay_clks == 2,
              "test requires a documented one- or two-CLK delay");

        Vintel_80286_82c284_reset dut;
        dut.clk_i = 1;
        dut.res_n_i = 1;
        dut.eval();

        auto full_clk = [&]() {
            dut.clk_i = 0;
            dut.eval();
            const bool after_falling_edge = dut.reset_o;
            dut.clk_i = 1;
            dut.eval();
            check(bool(dut.reset_o) == after_falling_edge,
                  "RESET changed on rising CLK instead of falling CLK");
            return after_falling_edge;
        };

        // Release RES through the synchronizer to establish a known baseline.
        for (unsigned edge = 0; edge < delay_clks; ++edge) full_clk();
        check(!dut.reset_o, "RESET did not deassert after RES-high delay");

        // Assert RES between CLK edges. RESET must wait for the selected number
        // of falling CLK edges before asserting.
        dut.res_n_i = 0;
        dut.eval();
        check(!dut.reset_o, "RESET changed before a falling CLK edge");
        for (unsigned edge = 1; edge <= delay_clks; ++edge) {
            const bool reset = full_clk();
            check(reset == (edge == delay_clks),
                  "RESET assertion did not follow the configured falling-edge delay");
        }

        // The 82C284 datasheet says 80C286 RESET must be high for at least 16
        // external CLK periods. Keep RES asserted throughout that interval.
        for (unsigned cycle = 0; cycle < 16; ++cycle) {
            check(full_clk(), "RESET did not remain asserted for 16 CLK periods");
        }

        // RES release is also sampled at falling CLK; RESET stays high until
        // the configured number of falling edges has elapsed.
        dut.res_n_i = 1;
        dut.eval();
        check(dut.reset_o, "RESET deasserted before a falling CLK edge");
        for (unsigned edge = 1; edge <= delay_clks; ++edge) {
            const bool reset = full_clk();
            check(reset == (edge != delay_clks),
                  "RESET release did not follow the configured falling-edge delay");
        }
        check(!dut.reset_o, "RESET remained asserted after synchronized RES release");

        std::cout << "PASS: 82C284 RES sampling, " << delay_clks
                  << " falling-CLK delay, polarity, and 16-CLK 80C286 reset hold\n";
        dut.final();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
