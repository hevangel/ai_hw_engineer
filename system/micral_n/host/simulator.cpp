#include "Vmicral_n.h"
#include "verilated.h"
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>

// Private line protocol used only by web/server.py. All state is from RTL.
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vmicral_n board;
    board.clk = 0;
    board.rst_n = 0;
    board.cpu_enable = 0;
    board.substitute = 0;
    board.switch_data = 0;
    board.panel_input = 0;
    board.rom_protect = 1;
    board.host_mem_addr = 0;
    board.host_mem_data = 0;
    board.host_mem_write = 0;
    board.host_io_addr = 8;
    board.eval();
    auto tick = [&]() {
        board.clk = 0; board.eval();
        board.clk = 1; board.eval();
        board.clk = 0; board.eval();
    };
    tick();
    board.rst_n = 1;
    bool running = false, trap_on = false;
    uint16_t trap = 0;
    auto read_mem = [&](uint16_t addr) -> int {
        board.host_mem_addr = addr & 0x3fff;
        board.eval();
        return board.host_mem_read;
    };
    auto state = [&]() {
        std::ostringstream out;
        out << "{\"pc\":" << board.pc
            << ",\"a\":" << unsigned(board.accumulator)
            << ",\"flags\":" << unsigned(board.flags)
            << ",\"halted\":" << (board.halted ? "true" : "false")
            << ",\"running\":" << (running ? "true" : "false")
            << ",\"trapEnabled\":" << (trap_on ? "true" : "false")
            << ",\"trapAddress\":" << trap
            << ",\"substitution\":" << (board.substitute ? "true" : "false")
            << ",\"switchData\":" << unsigned(board.switch_data)
            << ",\"panelInput\":" << unsigned(board.panel_input)
            << ",\"address\":" << board.bus_addr
            << ",\"data\":" << unsigned(board.bus_data)
            << ",\"memoryRead\":" << (board.bus_mem_read ? "true" : "false")
            << ",\"memoryWrite\":" << (board.bus_write ? "true" : "false")
            << ",\"ioRead\":" << (board.bus_io_read ? "true" : "false")
            << ",\"ioWrite\":" << (board.bus_io_write ? "true" : "false")
            << ",\"lastOutputPort\":" << unsigned(board.last_output_port)
            << ",\"lastOutputData\":" << unsigned(board.last_output_data)
            << ",\"cycles\":" << board.cycle_count
            << ",\"instructions\":" << board.instruction_count
            << ",\"memory\":[";
        uint16_t start = board.pc & 0x3ff0;
        for (int i=0; i<16; ++i) {
            if (i) out << ',';
            out << read_mem((start + i) & 0x3fff);
        }
        out << "],\"ram\":[";
        for (int i=0; i<16; ++i) {
            if (i) out << ',';
            out << read_mem(0x1000 + i);
        }
        out << "],\"outputs\":[";
        for (int i=8; i<32; ++i) {
            if (i != 8) out << ',';
            board.host_io_addr = i;
            board.eval();
            out << unsigned(board.host_io_read);
        }
        out << "]}";
        return out.str();
    };
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream in(line);
        std::string command;
        int x = 0, y = 0;
        in >> command >> x >> y;
        if (command == "QUIT") break;
        if (command == "RESET") {
            running = false;
            board.cpu_enable = 0;
            board.rst_n = 0; tick(); board.rst_n = 1; board.eval();
        } else if (command == "AUTO") {
            running = true;
        } else if (command == "PAUSE") {
            running = false;
            board.cpu_enable = 0;
        } else if (command == "INPUT") {
            board.panel_input = x & 255; board.eval();
        } else if (command == "SUB") {
            board.substitute = x != 0;
            board.switch_data = y & 255;
            board.eval();
        } else if (command == "TRAP") {
            trap_on = x != 0; trap = y & 0x3fff;
        } else if (command == "POKE") {
            running = false; board.cpu_enable = 0;
            board.host_mem_addr = x & 0x3fff;
            board.host_mem_data = y & 255;
            board.host_mem_write = 1; tick();
            board.host_mem_write = 0; board.eval();
        } else if (command == "RUN") {
            int count = std::clamp(x, 0, 100000);
            for (int i=0; i<count && running; ++i) {
                board.cpu_enable = 1;
                tick();
                if (board.halted || (trap_on && board.retired && board.pc == trap))
                    running = false;
            }
            board.cpu_enable = 0; board.eval();
        } else if (command == "CYCLE") {
            running = false; board.cpu_enable = 1; tick();
            board.cpu_enable = 0; board.eval();
        } else if (command == "STEP") {
            running = false;
            for (int i=0; i<8; ++i) {
                board.cpu_enable = 1; tick();
                if (board.retired || board.halted) break;
            }
            board.cpu_enable = 0; board.eval();
        }
        std::cout << state() << std::endl;
    }
    board.final();
    return 0;
}
