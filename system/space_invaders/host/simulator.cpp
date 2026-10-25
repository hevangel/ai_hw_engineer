// Host harness for the Space Invaders board. Private line protocol used by
// host/server.py and scripts/test_software.py. All machine state comes from
// RTL; the host only drives the run switches, the input ports and read-only
// observation.
#include "Vspace_invaders.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>

namespace {

Vspace_invaders board;
std::deque<std::pair<int,int>> snd_log;  // (port, data) events since last state
bool frozen = false;
int capture_version = 0;

void tick() {
    board.clk = 0; board.eval();
    board.clk = 1; board.eval();
    board.clk = 0; board.eval();
}

void step_collect() {
    tick();
    if (board.snd3_we) snd_log.emplace_back(3, board.snd3_data);
    if (board.snd5_we) snd_log.emplace_back(5, board.snd5_data);
}

void run_ticks(uint64_t ticks) {
    for (uint64_t i = 0; i < ticks; ++i) {
        step_collect();
        if (board.halted || board.fault) break;
    }
    board.eval();
}

std::string state() {
    std::ostringstream out;
    auto byte = [](unsigned v) { return static_cast<unsigned>(v & 0xff); };
    uint8_t a = board.cpu_regs >> 48, b = board.cpu_regs >> 40,
            c = board.cpu_regs >> 32, d = board.cpu_regs >> 24,
            e = board.cpu_regs >> 16, h = board.cpu_regs >> 8, l = board.cpu_regs;
    out << "{\"running\":" << (board.run_sw ? "true" : "false")
        << ",\"halted\":" << (board.halted ? "true" : "false")
        << ",\"fault\":" << (board.fault ? "true" : "false")
        << ",\"pc\":" << board.cpu_pc
        << ",\"sp\":" << board.cpu_sp
        << ",\"a\":" << byte(a) << ",\"b\":" << byte(b) << ",\"c\":" << byte(c)
        << ",\"d\":" << byte(d) << ",\"e\":" << byte(e) << ",\"h\":" << byte(h)
        << ",\"l\":" << byte(l)
        << ",\"flags\":" << byte(board.cpu_flags)
        << ",\"cycles\":" << board.cycle_count
        << ",\"instructions\":" << board.instruction_count
        << ",\"frames\":" << board.frame_count
        << ",\"interrupts\":" << board.interrupt_count
        << ",\"watchdogResets\":" << board.watchdog_reset_count
        << ",\"captureVersion\":" << capture_version
        << ",\"shift\":" << board.shift_reg
        << ",\"shiftOffset\":" << unsigned(board.shift_offset)
        << ",\"credit\":" << byte([&]{ board.host_mem_addr = 0x20eb; board.eval();
                                      return board.host_mem_rdata; }())
        << ",\"scoreLo\":" << byte([&]{ board.host_mem_addr = 0x20f8; board.eval();
                                        return board.host_mem_rdata; }())
        << ",\"scoreHi\":" << byte([&]{ board.host_mem_addr = 0x20f9; board.eval();
                                        return board.host_mem_rdata; }())
        << ",\"snd\":[";
    for (size_t i = 0; i < snd_log.size(); ++i) {
        if (i) out << ',';
        out << '[' << snd_log[i].first << ',' << snd_log[i].second << ']';
    }
    snd_log.clear();
    out << "],\"vram\":\"";
    static const char *hexdigits = "0123456789abcdef";
    for (int i = 0; i < 7168; ++i) {
        board.host_vram_addr = i;
        board.eval();
        unsigned v = board.host_vram_rdata & 0xff;
        out << hexdigits[v >> 4] << hexdigits[v & 0xf];
    }
    out << "\",\"mem\":[";
    for (int i = 0; i < 16; ++i) {
        board.host_mem_addr = 0x1a5c + i;
        board.eval();
        if (i) out << ',';
        out << byte(board.host_mem_rdata);
    }
    out << "]}";
    return out.str();
}

std::string checkpoint() {
    std::ostringstream out;
    out << "{\"pc\":" << board.cpu_pc << ",\"sp\":" << board.cpu_sp;
    const char *names[7] = {"a", "b", "c", "d", "e", "h", "l"};
    for (int i = 0; i < 7; ++i) {
        unsigned v = (board.cpu_regs >> ((6 - i) * 8)) & 0xff;
        out << ",\"" << names[i] << "\":" << v;
    }
    out << ",\"flags\":" << unsigned(board.cpu_flags & 0xff)
        << ",\"shift\":" << unsigned(board.shift_reg & 0xffff)
        << ",\"shiftOff\":" << unsigned(board.shift_offset & 7)
        << ",\"instructions\":" << unsigned(board.instruction_count & 0xffffffff)
        << ",\"image\":\"";
    static const char *hexdigits = "0123456789abcdef";
    for (int addr = 0; addr < 16384; ++addr) {
        board.host_mem_addr = addr;
        board.eval();
        unsigned v = board.host_mem_rdata & 0xff;
        out << hexdigits[v >> 4] << hexdigits[v & 0xf];
    }
    out << "\"}";
    return out.str();
}

std::unique_ptr<VerilatedFstC> waveform;
uint64_t waveform_time = 0;

void capture(uint64_t ticks) {
    const char *configured = std::getenv("INVADERS_FST_PATH");
    std::string path = configured ? configured : "invaders-waveform.fst";
    std::string temporary = path + ".tmp";
    waveform = std::make_unique<VerilatedFstC>();
    board.trace(waveform.get(), 2);
    waveform->open(temporary.c_str());
    if (!waveform->isOpen()) throw std::runtime_error("cannot open waveform capture");
    waveform_time = 0;
    waveform->dump(0);
    bool was_run = board.run_sw;
    board.run_sw = 1;
    for (uint64_t i = 0; i < ticks; ++i) {
        waveform->dump(++waveform_time);
        step_collect();
    }
    board.run_sw = was_run;
    board.eval();
    waveform->close();
    waveform.reset();
    if (std::rename(temporary.c_str(), path.c_str()))
        throw std::runtime_error("cannot publish waveform capture");
    ++capture_version;
}

} // namespace

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    board.clk = 0;
    board.rst_n = 0;
    board.run_sw = 0;
    board.step_sw = 0;
    board.reset_sw = 0;
    board.freeze = 0;
    board.in0 = 0;
    board.in1 = 0;
    board.in2 = 0;
    board.host_vram_addr = 0;
    board.host_mem_addr = 0;
    board.eval();
    tick();
    board.rst_n = 1;
    board.eval();

    std::string line;
    while (std::getline(std::cin, line)) {
        try {
            std::istringstream in(line);
            std::string command;
            uint64_t x = 0, y = 0;
            in >> command >> x >> y;
            if (command == "QUIT") break;
            if (command == "STATE") {
                // no action
            } else if (command == "RUN") {
                frozen = false;
                board.freeze = 0;
                board.eval();
                run_ticks(std::min<uint64_t>(x, 200000000));
            } else if (command == "RUNSW") {
                frozen = false;
                board.freeze = 0;
                board.run_sw = x != 0;
                board.eval();
                run_ticks(4);
            } else if (command == "RESET") {
                board.reset_sw = 1; step_collect(); board.reset_sw = 0;
                step_collect(); step_collect(); step_collect();
            } else if (command == "RUNI") {
                // Run to an exact instruction boundary: once N instructions
                // have retired, stall the bus (freeze). The core parks in
                // its wait state before evaluating the next fetch, so pc
                // and registers are exactly post-instruction-N, and the
                // final registered write lands on the following edge.
                uint64_t target = std::min<uint64_t>(x, 200000000);
                frozen = false;
                board.freeze = 0;
                board.run_sw = 1;
                board.eval();
                while (board.instruction_count < target) {
                    step_collect();
                    if (board.halted || board.fault) break;
                }
                frozen = true;
                board.freeze = 1;
                board.eval();
                tick(); tick();  // settle the final write
            } else if (command == "CHECKPOINT") {
                std::cout << checkpoint() << std::endl;
                continue;
            } else if (command == "PEEK") {
                if (x > 0xffff) throw std::runtime_error("address out of range");
                board.host_mem_addr = static_cast<uint16_t>(x);
                board.eval();
                std::cout << "{\"addr\":" << x
                          << ",\"value\":" << unsigned(board.host_mem_rdata & 0xff)
                          << "}" << std::endl;
                continue;
            } else if (command == "IN0") {
                board.in0 = static_cast<uint8_t>(x); board.eval();
            } else if (command == "IN1") {
                board.in1 = static_cast<uint8_t>(x); board.eval();
            } else if (command == "IN2") {
                board.in2 = static_cast<uint8_t>(x); board.eval();
            } else if (command == "CAPTURE") {
                capture(std::clamp<uint64_t>(x, 1, 65536));
            } else {
                throw std::runtime_error("unknown command: " + command);
            }
            std::cout << state() << std::endl;
        } catch (const std::exception &error) {
            std::cout << "{\"error\":\"" << error.what() << "\"}" << std::endl;
        }
    }
    board.final();
    return 0;
}
