// Host harness for the NES board. Private line protocol used by
// host/server.py and scripts/test_software.py. All machine state comes from
// RTL; the host only drives reset, the controller buttons and read-only
// observation (raster pixels, DAC codes, CPU bus and the work-RAM peek port).
#include "Vnes.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

Vnes board;
std::vector<uint8_t> screen(256 * 240), drawing(256 * 240);
uint64_t frames = 0, cpu_cycles = 0, master_ticks = 0;
int last_scanline = 0;
int capture_version = 0;
std::unique_ptr<VerilatedFstC> waveform;
uint64_t waveform_time = 0;

// Audio: the NES non-linear mixer (NESdev "APU Mixer" formulas) evaluated
// on every CPU cycle and box-averaged down to 44.1 kHz.
#if NES_REGION
const double kCpuHz = 26601712.0 / 16.0;
#else
const double kCpuHz = 21477272.0 / 12.0;
#endif
const double kRate = 44100.0;
double audio_acc = 0, audio_phase = 0;
int audio_count = 0;
std::vector<int16_t> audio;

double mix() {
    double p = board.pulse1 + board.pulse2;
    double pulse = p == 0 ? 0 : 95.88 / (8128.0 / p + 100.0);
    double t = board.triangle / 8227.0 + board.noise / 12241.0 + board.dmc / 22638.0;
    double tnd = t == 0 ? 0 : 159.79 / (1.0 / t + 100.0);
    return pulse + tnd;   // 0 .. ~1.0
}

struct TraceRow { unsigned pc, a, x, y, p, s; uint64_t cyc; };
std::vector<TraceRow> trace;
bool tracing = false;

void tick() {
    // Sample the CPU bus for the cycle the coming master edge completes.
    bool cpu_edge = board.cpu_tick;
    if (cpu_edge) {
        if (tracing && board.cpu_fetch && !board.cpu_dma)
            trace.push_back({board.cpu_addr, board.cpu_a, board.cpu_x, board.cpu_y,
                             board.cpu_p, board.cpu_s, cpu_cycles});
        audio_acc += mix();
        ++audio_count;
        audio_phase += kRate;
        if (audio_phase >= kCpuHz) {
            audio_phase -= kCpuHz;
            if (audio.size() < 44100 * 4) {
                double v = audio_acc / audio_count;
                audio.push_back(static_cast<int16_t>(std::clamp(v * 2.0 - 1.0, -1.0, 1.0) * 24000));
            }
            audio_acc = 0;
            audio_count = 0;
        }
    }
    if (board.pixel_valid && board.dot >= 2 && board.dot <= 257 && board.scanline < 240)
        drawing[board.scanline * 256 + board.dot - 2] = board.pixel & 0x3f;
    board.clk = 1; board.eval();
    if (waveform) waveform->dump(++waveform_time);
    board.clk = 0; board.eval();
    if (waveform) waveform->dump(++waveform_time);
    ++master_ticks;
    if (cpu_edge) ++cpu_cycles;
    int line = board.scanline;
    if (line == 240 && last_scanline == 239) {
        screen = drawing;
        ++frames;
    }
    last_scanline = line;
}

bool stopped() { return board.cpu_jammed || board.cpu_fault; }

void run_ticks(uint64_t n) {
    for (uint64_t i = 0; i < n && !stopped(); ++i) tick();
}

void run_frames(uint64_t n) {
    uint64_t target = frames + n;
    // Bounded: a frame is 357 366 (NTSC) / 532 034 (PAL) master clocks.
    uint64_t limit = master_ticks + (n + 1) * 600000;
    while (frames < target && master_ticks < limit && !stopped()) tick();
}

void run_cycles(uint64_t n) {
    uint64_t target = cpu_cycles + n;
    while (cpu_cycles < target && !stopped()) tick();
}

void reset_board(bool power) {
    // Power drops both lines; the reset button only /RST.
    board.rst_n = 0;
    board.por_n = !power;
    for (int i = 0; i < 64; ++i) {
        board.clk = 1; board.eval();
        board.clk = 0; board.eval();
    }
    board.rst_n = 1;
    board.por_n = 1;
    board.eval();
    if (power) { frames = 0; cpu_cycles = 0; master_ticks = 0; }
    last_scanline = 0;
}

unsigned peek(unsigned addr) {
    board.host_addr = addr & 0xffff;
    board.eval();
    return board.host_rdata & 0xff;
}

const char *kHex = "0123456789abcdef";

std::string base64(const uint8_t *data, size_t n) {
    static const char *t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
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
        << ",\"ticks\":" << master_ticks
        << ",\"pc\":" << unsigned(board.cpu_pc) << ",\"a\":" << unsigned(board.cpu_a)
        << ",\"x\":" << unsigned(board.cpu_x) << ",\"y\":" << unsigned(board.cpu_y)
        << ",\"s\":" << unsigned(board.cpu_s) << ",\"p\":" << unsigned(board.cpu_p)
        << ",\"scanline\":" << unsigned(board.scanline) << ",\"dot\":" << unsigned(board.dot)
        << ",\"jammed\":" << (board.cpu_jammed ? "true" : "false")
        << ",\"fault\":" << (board.cpu_fault ? "true" : "false")
        << ",\"pad1\":" << unsigned(board.pad1_i) << ",\"pad2\":" << unsigned(board.pad2_i)
        << ",\"captureVersion\":" << capture_version << "}";
    return out.str();
}

void capture(uint64_t ticks) {
    const char *configured = std::getenv("NES_FST_PATH");
    std::string path = configured ? configured : "nes-waveform.fst";
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

uint64_t plusarg(const char *name, uint64_t fallback) {
    std::string match = Verilated::commandArgsPlusMatch(name);
    if (match.empty()) return fallback;
    return std::strtoull(match.c_str() + std::string(name).size() + 1, nullptr, 0);
}

} // namespace

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    // Cartridge header fields, from scripts/prepare_rom.py.
    board.mapper_i = plusarg("mapper=", 0);
    board.mirror_v_i = plusarg("mirror=", 0);
    board.chr_ram_i = plusarg("chrram=", 0);
    board.prg_mask_i = plusarg("prgmask=", 0x7fff);
    board.chr_mask_i = plusarg("chrmask=", 0x1fff);
    board.pad1_i = 0;
    board.pad2_i = 0;
    board.host_addr = 0;
    board.clk = 0;
    board.eval();
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
            } else if (command == "CYCLES") {
                run_cycles(std::min<uint64_t>(x, 100000000));
            } else if (command == "RESET") {
                reset_board(false);
            } else if (command == "PAD1") {
                board.pad1_i = x & 0xff; board.eval();
            } else if (command == "PAD2") {
                board.pad2_i = x & 0xff; board.eval();
            } else if (command == "PEEK") {
                std::cout << "{\"addr\":" << (x & 0xffff) << ",\"value\":" << peek(x) << "}"
                          << std::endl;
                continue;
            } else if (command == "MEM") {
                // MEM addr len: hex dump through the side-effect-free port.
                uint64_t n = std::min<uint64_t>(y, 8192);
                std::string hex;
                for (uint64_t i = 0; i < n; ++i) {
                    unsigned v = peek(x + i);
                    hex += kHex[v >> 4];
                    hex += kHex[v & 15];
                }
                std::cout << "{\"addr\":" << x << ",\"hex\":\"" << hex << "\"}" << std::endl;
                continue;
            } else if (command == "SCREEN") {
                std::cout << "{\"frames\":" << frames << ",\"screen\":\""
                          << base64(screen.data(), screen.size()) << "\"}" << std::endl;
                continue;
            } else if (command == "AUDIO") {
                std::cout << "{\"rate\":44100,\"samples\":\""
                          << base64(reinterpret_cast<const uint8_t *>(audio.data()),
                                    audio.size() * 2)
                          << "\"}" << std::endl;
                audio.clear();
                continue;
            } else if (command == "TRACE") {
                // TRACE n: run until n instruction fetches, report each one
                // with the registers as they stand at that fetch.
                trace.clear();
                tracing = true;
                uint64_t n = std::min<uint64_t>(x, 100000);
                while (trace.size() < n && !stopped()) tick();
                tracing = false;
                std::cout << "{\"trace\":[";
                for (size_t i = 0; i < trace.size(); ++i) {
                    const TraceRow &r = trace[i];
                    if (i) std::cout << ',';
                    std::cout << '[' << r.pc << ',' << r.a << ',' << r.x << ',' << r.y << ','
                              << r.p << ',' << r.s << ',' << r.cyc << ']';
                }
                std::cout << "]}" << std::endl;
                continue;
            } else if (command == "CAPTURE") {
                capture(std::clamp<uint64_t>(x, 1, 200000));
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
