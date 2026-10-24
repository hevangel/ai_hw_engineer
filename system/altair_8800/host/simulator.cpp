// Host harness for the Altair 8800 board. Private line protocol used by
// host/server.py and scripts/test_software.py. All machine state comes from
// RTL; the host only drives panel switches, the SIO "teletype" wires and
// read-only observation.
#include "Valtair_8800.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <sstream>
#include <string>

namespace {

Valtair_8800 board;
std::deque<uint8_t> tape;
std::deque<uint8_t> tx_log;

void tick() {
    board.clk = 0; board.eval();
    board.clk = 1; board.eval();
    board.clk = 0; board.eval();
}

void clear_pulses() {
    board.step_sw = 0;
    board.examine_sw = 0;
    board.examine_next_sw = 0;
    board.deposit_sw = 0;
    board.deposit_next_sw = 0;
    board.reset_sw = 0;
    board.clr_sw = 0;
    board.protect_sw = 0;
    board.unprotect_sw = 0;
    board.tty_in_we = 0;
    board.eval();
}

// Advance one step and capture any byte the 88-SIO transmits during it.
void step_collect() {
    tick();
    if (board.tty_out_we) tx_log.push_back(board.tty_out_data);
}

// Panel memory operations need the bus (HLDA) and a stopped machine. The
// RTL grants HLDA one step after HOLD asserts, so wait for it.
void wait_panel_ready() {
    if (board.run_sw) return; // ops are ignored while running
    for (int guard = 0; !board.lamp_hlda; ++guard) {
        if (guard > 100000 || board.fault)
            throw std::runtime_error("panel bus not available");
        step_collect();
    }
}

// Push one byte into the 88-SIO receiver, waiting for FIFO space.
void push_byte(uint8_t byte) {
    for (int guard = 0; !board.tty_in_ready; ++guard) {
        if (guard > 100000) throw std::runtime_error("SIO receiver FIFO stayed full");
        step_collect();
    }
    board.tty_in_data = byte;
    board.tty_in_we = 1;
    board.eval();
    step_collect();
    board.tty_in_we = 0;
    board.eval();
}

// Advance the machine: feed tape bytes, collect transmitted bytes.
void run_ticks(uint64_t ticks) {
    for (uint64_t i = 0; i < ticks; ++i) {
        board.tty_in_we = 0;
        if (!tape.empty() && board.tty_in_ready) {
            board.tty_in_data = tape.front();
            board.tty_in_we = 1;
            tape.pop_front();
        }
        step_collect();
        board.tty_in_we = 0;
        if (board.halted) break;
    }
    board.eval();
}

std::unique_ptr<VerilatedFstC> waveform;
uint64_t waveform_time = 0;
int capture_version = 0;

std::string state() {    std::ostringstream out;
    auto byte = [](unsigned v) { return static_cast<unsigned>(v & 0xff); };
    uint8_t a = board.cpu_regs >> 48, b = board.cpu_regs >> 40,
            c = board.cpu_regs >> 32, d = board.cpu_regs >> 24,
            e = board.cpu_regs >> 16, h = board.cpu_regs >> 8, l = board.cpu_regs;
    out << "{\"running\":" << (board.run_sw ? "true" : "false")
        << ",\"halted\":" << (board.halted ? "true" : "false")
        << ",\"fault\":" << (board.fault ? "true" : "false")
        << ",\"hlda\":" << (board.lamp_hlda ? "true" : "false")
        << ",\"inte\":" << (board.lamp_inte ? "true" : "false")
        << ",\"protected\":" << (board.protect_lamp ? "true" : "false")
        << ",\"lampAddr\":" << board.lamp_addr
        << ",\"lampData\":" << byte(board.lamp_data)
        << ",\"lampStatus\":" << byte(board.lamp_status)
        << ",\"lampHlta\":" << (board.lamp_hlta ? "true" : "false")
        << ",\"displayAddr\":" << board.display_addr
        << ",\"switchAddr\":" << board.address_sw
        << ",\"switchData\":" << byte(board.data_sw)
        << ",\"pc\":" << board.cpu_pc
        << ",\"sp\":" << board.cpu_sp
        << ",\"a\":" << byte(a) << ",\"b\":" << byte(b) << ",\"c\":" << byte(c)
        << ",\"d\":" << byte(d) << ",\"e\":" << byte(e) << ",\"h\":" << byte(h)
        << ",\"l\":" << byte(l)
        << ",\"flags\":" << byte(board.cpu_flags)
        << ",\"cycles\":" << board.cycle_count
        << ",\"instructions\":" << board.instruction_count
        << ",\"rxCount\":" << board.rx_count
        << ",\"tapePending\":" << tape.size()
        << ",\"retired\":" << (board.retired ? "true" : "false")
        << ",\"captureVersion\":" << capture_version
        << ",\"tx\":[";
    for (size_t i = 0; i < tx_log.size(); ++i) {
        if (i) out << ',';
        out << byte(tx_log[i]);
    }
    tx_log.clear();
    out << "],\"mem\":[";
    uint16_t base = board.display_addr & 0xfff0;
    for (int i = 0; i < 16; ++i) {
        board.host_mem_addr = static_cast<uint16_t>(base + i);
        board.eval();
        if (i) out << ',';
        out << byte(board.host_mem_rdata);
    }
    out << "],\"memBase\":" << base << "}";
    return out.str();
}

void capture(uint64_t ticks) {
    const char *configured = std::getenv("ALTAIR_FST_PATH");
    std::string path = configured ? configured : "altair-waveform.fst";
    std::string temporary = path + ".tmp";
    waveform = std::make_unique<VerilatedFstC>();
    board.trace(waveform.get(), 2);
    waveform->open(temporary.c_str());
    if (!waveform->isOpen()) throw std::runtime_error("cannot open waveform capture");
    waveform_time = 0;
    waveform->dump(0);
    // Capture runs the machine with the RUN switch forced on, then restores it.
    bool was_run = board.run_sw;
    board.run_sw = 1;
    for (uint64_t i = 0; i < ticks; ++i) {
        waveform->dump(++waveform_time);
        board.tty_in_we = 0;
        if (!tape.empty() && board.tty_in_ready) {
            board.tty_in_data = tape.front();
            board.tty_in_we = 1;
            tape.pop_front();
        }
        tick();
        if (board.tty_out_we) tx_log.push_back(board.tty_out_data);
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
    board.address_sw = 0;
    board.data_sw = 0;
    board.tty_tx_delay = 300;
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
            in >> command;
            std::string rest;
            std::getline(in, rest);
            if (!rest.empty() && rest.front() == ' ') rest.erase(0, 1);
            uint64_t x = 0, y = 0;
            {
                std::istringstream numbers(rest);
                numbers >> x >> y; // non-numeric arguments (paths) leave x=y=0
            }
            clear_pulses();
            if (command == "QUIT") break;
            if (command == "STATE") {
                // no action
            } else if (command == "RUN") {
                run_ticks(std::min<uint64_t>(x, 100000000));
            } else if (command == "RUNSW") {
                board.run_sw = x != 0;
                board.eval();
                run_ticks(4);
            } else if (command == "SWITCHES") {
                board.address_sw = static_cast<uint16_t>(x);
                board.data_sw = static_cast<uint8_t>(y);
                board.eval();
            } else if (command == "STEP") {
                if (board.halted || board.fault) throw std::runtime_error("CPU is halted or faulted");
                board.step_sw = 1;
                board.eval();
                // One step first so a stale retire pulse cannot end the wait.
                step_collect();
                for (int i = 0; i < 100000 && !board.retired; ++i) step_collect();
                if (!board.retired) throw std::runtime_error("single step did not retire");
                board.step_sw = 0;
            } else if (command == "EXAMINE") {
                wait_panel_ready();
                board.examine_sw = 1; step_collect(); board.examine_sw = 0;
                step_collect(); // display read result latches on this edge
            } else if (command == "EXNEXT") {
                wait_panel_ready();
                board.examine_next_sw = 1; step_collect(); board.examine_next_sw = 0;
                step_collect();
            } else if (command == "DEPOSIT") {
                wait_panel_ready();
                board.deposit_sw = 1; step_collect(); board.deposit_sw = 0;
                step_collect(); // the registered write lands on this edge
            } else if (command == "DEPNEXT") {
                wait_panel_ready();
                board.deposit_next_sw = 1; step_collect(); board.deposit_next_sw = 0;
                step_collect();
            } else if (command == "RESET") {
                board.reset_sw = 1; step_collect(); board.reset_sw = 0;
                // Let the 3-clock internal reset finish before returning.
                step_collect(); step_collect(); step_collect();
            } else if (command == "CLR") {
                board.clr_sw = 1; step_collect(); board.clr_sw = 0;
                tape.clear();
            } else if (command == "PROTECT") {
                board.protect_sw = 1; step_collect(); board.protect_sw = 0;
            } else if (command == "UNPROTECT") {
                board.unprotect_sw = 1; step_collect(); board.unprotect_sw = 0;
            } else if (command == "KEY") {
                if (x > 255) throw std::runtime_error("invalid key byte");
                push_byte(static_cast<uint8_t>(x));
            } else if (command == "TAPE") {
                if (rest.empty()) throw std::runtime_error("TAPE needs a file path");
                std::ifstream file(rest, std::ios::binary);
                if (!file) throw std::runtime_error("cannot open tape file: " + rest);
                tape.assign(std::istreambuf_iterator<char>(file),
                            std::istreambuf_iterator<char>());
            } else if (command == "TAPEOFF") {
                tape.clear();
            } else if (command == "TXDELAY") {
                board.tty_tx_delay = static_cast<uint16_t>(x);
                board.eval();
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
