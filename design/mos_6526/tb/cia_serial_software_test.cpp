#include "Vcia_software_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        const bool load = argc == 3 && std::string(argv[1]) == "--load";
        if (argc != 2 && !load) throw std::runtime_error("Pass original cia-sdr-delay.prg or --load cia-sdr-load.prg");
        std::ifstream input(argv[load ? 2 : 1], std::ios::binary);
        std::vector<std::uint8_t> image((std::istreambuf_iterator<char>(input)), {});
        if (image.size() < (load ? 449u : 512u) || image[0] != 1 || image[1] != 8)
            throw std::runtime_error("Original PRG header/length");
        std::array<std::uint8_t, 65536> ram{};
        std::copy(image.begin()+2, image.end(), ram.begin()+0x0801);
        auto require = [](bool ok, const char* message) {
            if (!ok) throw std::runtime_error(message);
        };
        const unsigned entry = load ? 0x0820 : 0x080d;
        if (load) {
            require(ram[entry] == 0xa9 && ram[entry+2] == 0x20 &&
                    ram[0x08c9] == 0x8c && ram[0x08d6] == 0x8c &&
                    ram[0x08cc] == 0xa9 && ram[0x08d9] == 0xa9,
                    "Original double-write checkpoints changed");
        } else require(ram[0x080d] == 0xa9 && ram[0x080f] == 0x20 &&
                ram[0x08cf] == 0x8c && ram[0x08d0] == 0xff && ram[0x08d1] == 0xd7 &&
                ram[0x08d2] == 0xd0, "Original instruction checkpoints changed");
        ram[0xfffc] = entry & 255; ram[0xfffd] = entry >> 8;
        ram[0xffd2] = 0x60; // Actual RTS; minimal console sink below.
        Vcia_software_top dut;
        dut.tod_input_i = 0;
        dut.rdy_i = 1; dut.reference_cia_i = 0;
        dut.reference_irq_n_i = 1; dut.reference_nmi_n_i = 1;
        std::uint64_t cycles = 0;
        unsigned startup = 0, writes = 0;
        unsigned cursor = 0, result_next = 0, console_lines = 0;
        std::string console;
        bool result_written = false;
        unsigned result = 0;
        auto settle = [&]() {
            dut.eval();
            const unsigned address = dut.bus_addr;
            const unsigned line = (cycles / 63) % 312;
            dut.memory_data_i = address == 0xd011 ?
                ((ram[address] & 0x7f) | (line >= 256 ? 0x80 : 0)) :
                address == 0xd012 ? (line & 255) : ram[address];
            dut.eval();
        };
        dut.clk = 0; dut.rst_n = 0;
        for (unsigned i = 0; i < 2; ++i) {
            dut.clk = 1; settle(); dut.clk = 0; dut.eval(); ++cycles;
        }
        dut.rst_n = 1;
        while (cycles < 1000000) {
            dut.clk = 1; settle();
            require(!dut.fault_o && !dut.jammed_o, "CPU fault/jam");
            if (dut.fetch_o) {
                if (startup < 2) {
                    require(dut.bus_addr == entry + (startup ? 2 : 0) &&
                            dut.read_data_o == (startup ? 0x20 : 0xa9),
                            "Exact original entry/next instruction PC and opcode");
                    ++startup;
                }
                if (load && dut.bus_addr == 0xffd2) {
                    const unsigned value = dut.a_o;
                    if (value == 0x93) {
                        std::fill(ram.begin()+0x0400, ram.begin()+0x07e8, 0x20);
                        cursor = 0;
                    } else if (value == 13) {
                        cursor = (cursor/40+1)*40; ++console_lines; console += '\n';
                    } else {
                        require(cursor < 1000, "Console sink does not implement screen scrolling");
                        ram[0x0400+cursor++] = value >= 0x40 && value <= 0x5f ? value-0x40 : value;
                        console += char(value);
                    }
                }
                if (result_written) {
                    require(dut.bus_addr == result_next && dut.read_data_o == (load ? 0xa9 : 0xd0),
                            "Exact instruction following result store");
                    if (load) {
                        require(console_lines == 10, "Original program emitted all ten measurements");
                        std::cout << "Original SDR double-write output:\n" << console
                                  << "cycles=" << cycles << " result=" << result << '\n';
                        require(result == 0, "Original SDR double-write screen table reported FAILURE");
                        std::cout << "MOS 6526 SERIAL SOFTWARE PASS: original double-write program; "
                                     "store PC=08c9 next PC=08cc\n";
                        return 0;
                    }
                    require(writes == 42, "All 21 original timing samples executed");
                    std::cout << "Original serial delay table:" << std::hex << std::setfill('0');
                    for (unsigned i = 0; i < 21; ++i)
                        std::cout << ' ' << std::setw(4) << unsigned(ram[0x2000+2*i] |
                            (ram[0x2001+2*i] << 8));
                    std::cout << std::dec << " cycles=" << cycles << " result=" << result << '\n';
                    require(result == 0, "Original hardware-table serial test reported FAILURE");
                    std::cout << "MOS 6526 SERIAL SOFTWARE PASS: 21 hardware timing samples; "
                                 "store PC=08cf next PC=08d2\n";
                    return 0;
                }
            }
            if (dut.bus_we) {
                if (dut.bus_addr == 0xd7ff) {
                    result_next = load ? (dut.bus_data_o ? 0x08d9 : 0x08cc) : 0x08d2;
                    require(dut.pc_o == result_next && startup == 2, "Exact result-store post-instruction PC");
                    result_written = true; result = dut.bus_data_o;
                }
                if (dut.bus_addr >= 0x2000 && dut.bus_addr < 0x202a) ++writes;
                if ((dut.bus_addr & 0xfe00) != 0xdc00) ram[dut.bus_addr] = dut.bus_data_o;
            }
            dut.clk = 0; dut.eval(); ++cycles;
        }
        throw std::runtime_error("Original serial test timed out");
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n'; return 1;
    }
}
