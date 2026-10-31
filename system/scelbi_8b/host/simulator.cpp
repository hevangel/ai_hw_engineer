#include "Vscelbi_8b.h"
#include "verilated.h"
#include <algorithm>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>
#include <deque>

// Private line protocol used only by web/server.py. All state is from RTL.
// The console is a byte pipe: queued bytes enter the board's receiver FIFO
// with backpressure (the board's tty_rx_full gates the push), and transmit
// strobes are logged for the panel.
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vscelbi_8b board;
    board.clk = 0;
    board.rst_n = 0;
    board.cpu_enable = 0;
    board.tty_rx_push = 0;
    board.tty_rx_data = 0;
    board.host_mem_addr = 0;
    board.host_mem_data = 0;
    board.host_mem_write = 0;
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
    std::deque<uint8_t> tty_in;
    std::deque<uint8_t> tty_log;
    auto step_tick = [&]() {
        if (!tty_in.empty() && !board.tty_rx_full) {
            board.tty_rx_push = 1;
            board.tty_rx_data = tty_in.front();
            tty_in.pop_front();
        } else {
            board.tty_rx_push = 0;
        }
        tick();
        if (board.tty_tx_strobe) {
            tty_log.push_back(board.tty_tx_data);
            if (tty_log.size() > 4096) tty_log.erase(tty_log.begin(), tty_log.end() - 4096);
        }
    };
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
            << ",\"pendingInput\":" << tty_in.size()
            << ",\"address\":" << board.bus_addr
            << ",\"data\":" << unsigned(board.bus_data)
            << ",\"memoryRead\":" << (board.bus_mem_read ? "true" : "false")
            << ",\"memoryWrite\":" << (board.bus_write ? "true" : "false")
            << ",\"ioRead\":" << (board.bus_io_read ? "true" : "false")
            << ",\"ioWrite\":" << (board.bus_io_write ? "true" : "false")
            << ",\"cycles\":" << board.cycle_count
            << ",\"instructions\":" << board.instruction_count
            << ",\"tty\":\"";
        char hex[3];
        for (uint8_t byte : tty_log) {
            snprintf(hex, sizeof hex, "%02x", byte);
            out << hex;
        }
        out << "\",\"memory\":[";
        uint16_t start = board.pc & 0x3ff0;
        for (int i=0; i<16; ++i) {
            if (i) out << ',';
            out << read_mem((start + i) & 0x3fff);
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
        } else if (command == "TRAP") {
            trap_on = x != 0; trap = y & 0x3fff;
        } else if (command == "TTYIN") {
            tty_in.push_back(x & 255);
        } else if (command == "LOAD") {
            // x = count of raw bytes following on... not used; the server
            // streams TTYIN commands instead. Kept for protocol room.
        } else if (command == "POKE") {
            running = false; board.cpu_enable = 0;
            board.host_mem_addr = x & 0x3fff;
            board.host_mem_data = y & 255;
            board.host_mem_write = 1; tick();
            board.host_mem_write = 0; board.eval();
        } else if (command == "RUN") {
            int count = std::clamp(x, 0, 200000);
            for (int i=0; i<count && running; ++i) {
                board.cpu_enable = 1;
                step_tick();
                if (board.halted || (trap_on && board.retired && board.pc == trap))
                    running = false;
            }
            board.cpu_enable = 0; board.eval();
        } else if (command == "CYCLE") {
            running = false; board.cpu_enable = 1; step_tick();
            board.cpu_enable = 0; board.eval();
        } else if (command == "STEP") {
            running = false;
            for (int i=0; i<8; ++i) {
                board.cpu_enable = 1; step_tick();
                if (board.retired || board.halted) break;
            }
            board.cpu_enable = 0; board.eval();
        }
        std::cout << state() << std::endl;
    }
    board.final();
    return 0;
}
