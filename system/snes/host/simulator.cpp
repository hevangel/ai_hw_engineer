// Host harness for the SNES board. Private line protocol used by
// host/server.py and scripts/test_software.py. All machine state comes from
// RTL; the host only loads the IPL ROM image, drives reset and the
// controller buttons, and observes (raster pixels, DSP samples, CPU state and
// the side-effect-free memory peek port).
#include "Vsnes.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

Vsnes board;
constexpr int kW = 512, kH = 240;
std::vector<uint16_t> screen(kW * kH), drawing(kW * kH);
uint64_t frames = 0, cpu_cycles = 0, master_ticks = 0, smp_cycles = 0;
int capture_version = 0;
std::unique_ptr<VerilatedFstC> waveform;
uint64_t waveform_time = 0;
std::vector<int16_t> audio;  // interleaved stereo, 32 kHz

struct TraceRow { unsigned pc, a, x, y, s, d, p, dbr, e; uint64_t cyc; };
std::vector<TraceRow> trace;
bool tracing = false;

void tick() {
    bool cpu_edge = board.bus_ce;
    if (cpu_edge && tracing && board.cpu_fetch)
        trace.push_back({board.cpu_pc, board.cpu_a, board.cpu_x, board.cpu_y, board.cpu_s,
                         board.cpu_d, board.cpu_p, board.cpu_dbr, board.cpu_e, cpu_cycles});
    board.clk = 1; board.eval();
    if (waveform) waveform->dump(++waveform_time);
    board.clk = 0; board.eval();
    if (waveform) waveform->dump(++waveform_time);
    ++master_ticks;
    if (cpu_edge) ++cpu_cycles;
    if (board.apu_tick) ++smp_cycles;
    if (board.pix_valid && board.pix_y < kH) {
        if (board.pix_hires) {
            if (board.pix_x < kW) drawing[board.pix_y * kW + board.pix_x] = board.pix_rgb;
        } else if (board.pix_x < 256) {
            drawing[board.pix_y * kW + board.pix_x * 2] = board.pix_rgb;
            drawing[board.pix_y * kW + board.pix_x * 2 + 1] = board.pix_rgb;
        }
    }
    if (board.sample_valid && audio.size() < 32000 * 2 * 4) {
        audio.push_back(static_cast<int16_t>(board.sample_l));
        audio.push_back(static_cast<int16_t>(board.sample_r));
    }
    if (board.frame_o) {
        screen = drawing;
        ++frames;
    }
}

bool stopped() { return board.dsp_overrun; }

void run_ticks(uint64_t n) {
    for (uint64_t i = 0; i < n && !stopped(); ++i) tick();
}

void run_frames(uint64_t n) {
    uint64_t target = frames + n;
    // Bounded: a frame is 357 368 (NTSC) / 425 568 (PAL) master clocks.
    uint64_t limit = master_ticks + (n + 1) * 500000;
    while (frames < target && master_ticks < limit && !stopped()) tick();
}

void reset_board(bool power) {
    board.rst_n = 0;
    for (int i = 0; i < 64; ++i) {
        board.clk = 1; board.eval();
        board.clk = 0; board.eval();
    }
    board.rst_n = 1;
    board.eval();
    if (power) { frames = 0; cpu_cycles = 0; master_ticks = 0; smp_cycles = 0; }
}

void load_ipl(const std::string& path) {
    std::ifstream in(path);
    if (!in) throw std::runtime_error("cannot open IPL image " + path);
    std::string byte;
    for (int i = 0; i < 64 && in >> byte; ++i) {
        board.ipl_we = 1;
        board.ipl_addr = i;
        board.ipl_data = std::stoul(byte, nullptr, 16);
        board.clk = 1; board.eval();
        board.clk = 0; board.eval();
    }
    board.ipl_we = 0;
}

unsigned peek(unsigned addr) {
    board.host_addr = addr & 0xffffff;
    board.eval();
    return board.host_rdata & 0xff;
}

const char* kHex = "0123456789abcdef";

std::string base64(const uint8_t* data, size_t n) {
    static const char* t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve((n + 2) / 3 * 4);
    for (size_t i = 0; i < n; i += 3) {
        uint32_t v = data[i] << 16;
        if (i + 1 < n) v |= data[i + 1] << 8;
        if (i + 2 < n) v |= data[i + 2];
        out += t[(v >> 18) & 63];
        out += t[(v >> 12) & 63];
        out += i + 1 < n ? t[(v >> 6) & 63] : '=';
        out += i + 2 < n ? t[v & 63] : '=';
    }
    return out;
}

std::string state() {
    std::ostringstream out;
    out << "{\"frames\":" << frames << ",\"cycles\":" << cpu_cycles
        << ",\"ticks\":" << master_ticks << ",\"smpCycles\":" << smp_cycles
        << ",\"pc\":" << unsigned(board.cpu_pc) << ",\"a\":" << unsigned(board.cpu_a)
        << ",\"x\":" << unsigned(board.cpu_x) << ",\"y\":" << unsigned(board.cpu_y)
        << ",\"s\":" << unsigned(board.cpu_s) << ",\"d\":" << unsigned(board.cpu_d)
        << ",\"p\":" << unsigned(board.cpu_p) << ",\"dbr\":" << unsigned(board.cpu_dbr)
        << ",\"e\":" << unsigned(board.cpu_e) << ",\"smpPc\":" << unsigned(board.smp_pc)
        << ",\"vcount\":" << unsigned(board.vcount) << ",\"hcount\":" << unsigned(board.hcount)
        << ",\"overrun\":" << (board.dsp_overrun ? "true" : "false")
        << ",\"pad1\":" << unsigned(board.pad1_i) << ",\"pad2\":" << unsigned(board.pad2_i)
        << ",\"captureVersion\":" << capture_version << "}";
    return out.str();
}

void capture(uint64_t ticks) {
    const char* configured = std::getenv("SNES_FST_PATH");
    std::string path = configured ? configured : "snes-waveform.fst";
    std::string temporary = path + ".tmp";
    waveform = std::make_unique<VerilatedFstC>();
    board.trace(waveform.get(), 3);
    waveform->open(temporary.c_str());
    if (!waveform->isOpen()) throw std::runtime_error("cannot open waveform capture");
    waveform_time = 0;
    waveform->dump(0);
    run_ticks(ticks);
    waveform->close();
    waveform.reset();
    if (std::rename(temporary.c_str(), path.c_str()))
        throw std::runtime_error("cannot publish waveform capture");
    ++capture_version;
}

uint64_t plusarg(const char* name, uint64_t fallback) {
    std::string match = Verilated::commandArgsPlusMatch(name);
    if (match.empty()) return fallback;
    return std::strtoull(match.c_str() + std::string(name).size() + 1, nullptr, 0);
}

std::string plusarg_str(const char* name) {
    std::string match = Verilated::commandArgsPlusMatch(name);
    return match.empty() ? "" : match.substr(std::string(name).size() + 1);
}

} // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    // Cartridge map, from scripts/prepare_rom.py.
    board.hirom_i = plusarg("hirom=", 0);
    board.rom_mask_i = plusarg("rommask=", 0x7fff);
    board.sram_mask_i = plusarg("srammask=", 0);
    board.sram_en_i = plusarg("sramen=", 0);
    board.pad1_i = 0;
    board.pad2_i = 0;
    board.host_addr = 0;
    board.ipl_we = 0;
    board.clk = 0;
    board.eval();
    std::string ipl = plusarg_str("ipl=");
    if (ipl.empty()) {
        std::cerr << "missing +ipl=<work/ipl.hex> (scripts/fetch_ipl.py)" << std::endl;
        return 2;
    }
    load_ipl(ipl);
    reset_board(true);

    std::string line;
    while (std::getline(std::cin, line)) {
        try {
            std::istringstream in(line);
            std::string command;
            uint64_t x = 0, y = 0;
            in >> command >> x >> y;
            if (command == "QUIT") break;
            if (command == "STATE") {
            } else if (command == "RUN") {
                run_ticks(std::min<uint64_t>(x, 400000000));
            } else if (command == "FRAMES") {
                run_frames(std::min<uint64_t>(x, 3600));
            } else if (command == "RESET") {
                reset_board(false);
            } else if (command == "PAD1") {
                board.pad1_i = x & 0xfff; board.eval();
            } else if (command == "PAD2") {
                board.pad2_i = x & 0xfff; board.eval();
            } else if (command == "PEEK") {
                std::cout << "{\"addr\":" << (x & 0xffffff) << ",\"value\":" << peek(x) << "}"
                          << std::endl;
                continue;
            } else if (command == "MEM") {
                // MEM addr len: hex dump through the side-effect-free port.
                uint64_t n = std::min<uint64_t>(y, 65536);
                std::string hex;
                for (uint64_t i = 0; i < n; ++i) {
                    unsigned v = peek(x + i);
                    hex += kHex[v >> 4];
                    hex += kHex[v & 15];
                }
                std::cout << "{\"addr\":" << x << ",\"hex\":\"" << hex << "\"}" << std::endl;
                continue;
            } else if (command == "SCREEN") {
                // 512 x 240 BGR555, little-endian; low-resolution pixels doubled.
                std::cout << "{\"frames\":" << frames << ",\"width\":" << kW << ",\"height\":" << kH
                          << ",\"screen\":\""
                          << base64(reinterpret_cast<const uint8_t*>(screen.data()), screen.size() * 2)
                          << "\"}" << std::endl;
                continue;
            } else if (command == "AUDIO") {
                std::cout << "{\"rate\":32000,\"channels\":2,\"samples\":\""
                          << base64(reinterpret_cast<const uint8_t*>(audio.data()), audio.size() * 2)
                          << "\"}" << std::endl;
                audio.clear();
                continue;
            } else if (command == "TRACE") {
                trace.clear();
                tracing = true;
                uint64_t n = std::min<uint64_t>(x, 100000);
                while (trace.size() < n && !stopped()) tick();
                tracing = false;
                std::cout << "{\"trace\":[";
                for (size_t i = 0; i < trace.size(); ++i) {
                    const TraceRow& r = trace[i];
                    if (i) std::cout << ',';
                    std::cout << '[' << r.pc << ',' << r.a << ',' << r.x << ',' << r.y << ',' << r.s
                              << ',' << r.d << ',' << r.p << ',' << r.dbr << ',' << r.e << ','
                              << r.cyc << ']';
                }
                std::cout << "]}" << std::endl;
                continue;
            } else if (command == "CAPTURE") {
                capture(std::clamp<uint64_t>(x, 1, 200000));
            } else {
                throw std::runtime_error("unknown command: " + command);
            }
            std::cout << state() << std::endl;
        } catch (const std::exception& error) {
            std::cout << "{\"error\":\"" << error.what() << "\"}" << std::endl;
        }
    }
    board.final();
    return 0;
}
