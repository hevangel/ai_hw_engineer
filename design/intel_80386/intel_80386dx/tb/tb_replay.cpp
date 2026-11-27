// Physical-capture replay bench for intel_80386_core.
//
// Reads vectors.bin from scripts/prepare_vectors.py. For each test: load
// the initial register file through the core's load port, seed memory,
// run until the core halts, then compare every register (EFLAGS through
// the capture's f_umask) and memory. The capture terminates each test
// with HLT; when the instruction transfers control the capture board
// injects HLT at the first code fetch after the transfer, so this bench
// returns F4h for the first fetch after the instruction retires.
//
// I/O reads return FFh per byte (open bus) except ports 22h/23h, which the
// 386EX capture CPU decodes internally (its remap configuration register)
// and which read 7Fh/42h in captures E5 #422, 66 E5 #190 and #422; this is
// a property of the capture fixture, not of the 386DX/SX core.
#include "Vintel_80386_core.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

static const char *kRegNames[20] = {
    "cr0", "cr3", "eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp",
    "cs", "ds", "es", "fs", "gs", "ss", "eip", "eflags", "dr6", "dr7"};
static const uint32_t kNone = 0xFFFFFFFFu;
static const uint32_t kMemMask = 0xFFFFFF;

struct Test {
    uint32_t file, idx, flag_mask, exc_flag_addr, exc_number;
    std::string name;
    uint32_t init[20], fin[20];
    std::vector<std::pair<uint32_t, uint8_t>> init_ram, fin_ram;
};

class Reader {
public:
    explicit Reader(const char *path) : in(path, std::ios::binary) {
        if (!in) throw std::runtime_error("cannot open vectors");
        char magic[4];
        in.read(magic, 4);
        if (std::memcmp(magic, "V386", 4) != 0) throw std::runtime_error("bad vector magic");
        count = u32();
    }
    uint32_t count = 0;
    Test next() {
        Test t;
        t.file = u32(); t.idx = u32(); t.flag_mask = u32();
        t.exc_flag_addr = u32(); t.exc_number = u32();
        uint32_t n = u32();
        t.name.resize(n);
        in.read(&t.name[0], n);
        for (auto &r : t.init) r = u32();
        ram(t.init_ram);
        for (auto &r : t.fin) r = u32();
        ram(t.fin_ram);
        if (!in) throw std::runtime_error("truncated vectors");
        return t;
    }
private:
    std::ifstream in;
    uint32_t u32() {
        uint8_t b[4];
        in.read(reinterpret_cast<char *>(b), 4);
        return b[0] | (b[1] << 8) | (b[2] << 16) | (uint32_t(b[3]) << 24);
    }
    void ram(std::vector<std::pair<uint32_t, uint8_t>> &v) {
        uint32_t n = u32();
        v.reserve(n);
        for (uint32_t k = 0; k < n; ++k) {
            uint32_t a = u32(), d = u32();
            v.emplace_back(a, uint8_t(d));
        }
    }
};

class Bench {
public:
    Vintel_80386_core dut;
    std::vector<uint8_t> memory = std::vector<uint8_t>(kMemMask + 1);
    std::vector<uint32_t> touched;
    std::map<uint32_t, uint8_t> written;
    bool retired = false, injected = false;
    uint64_t cycles = 0;

    void tick() {
        dut.clk = 0;
        dut.eval();
        dut.ack_i = dut.req_o;
        uint32_t data = 0;
        if (dut.req_o && !dut.we_o) {
            if (dut.io_o) {
                // Fixture I/O space: open bus (FFh) except the 386EX's
                // internal 16-bit register at 22h, which reads 427Fh.
                for (unsigned k = 0; k < dut.size_o; ++k) {
                    uint32_t port = (dut.addr_o + k) & 0xFFFF;
                    uint32_t v = port == 0x22 ? 0x7F : port == 0x23 ? 0x42 : 0xFF;
                    data |= v << (8 * k);
                }
            }
            else for (unsigned k = 0; k < dut.size_o; ++k)
                data |= uint32_t(memory[(dut.addr_o + k) & kMemMask]) << (8 * k);
            if (dut.fetch_o && retired && !injected) { data = 0xF4; injected = true; }
        }
        dut.rdata_i = data;
        dut.eval();
        if (dut.req_o && dut.we_o && !dut.io_o) {
            for (unsigned k = 0; k < dut.size_o; ++k) {
                uint32_t a = (dut.addr_o + k) & kMemMask;
                set(a, uint8_t(dut.wdata_o >> (8 * k)));
                written[a] = uint8_t(dut.wdata_o >> (8 * k));
            }
        }
        dut.clk = 1;
        dut.eval();
        ++cycles;
        if (dut.retire_o) retired = true;
    }
    void set(uint32_t a, uint8_t v) { memory[a & kMemMask] = v; touched.push_back(a & kMemMask); }
    void clear() {
        for (auto a : touched) memory[a] = 0;
        touched.clear();
        written.clear();
        retired = injected = false;
    }
    void reset() {
        dut.rst_n = 0; dut.load_i = 0; dut.ack_i = 0;
        tick(); tick();
        dut.rst_n = 1;
    }
    uint32_t reg(int k) { return dut.state_o[k]; }
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) { std::cerr << "usage: replay vectors.bin [max_fail_report]\n"; return 2; }
    unsigned max_report = argc > 2 ? std::stoul(argv[2]) : 3;
    try {
        Reader reader(argv[1]);
        Bench b;
        b.reset();
        std::map<uint32_t, std::pair<uint64_t, uint64_t>> per_file;
        std::map<uint32_t, unsigned> reported;
        uint64_t pass = 0, fail = 0;
        for (uint32_t n = 0; n < reader.count; ++n) {
            Test t = reader.next();
            b.clear();
            b.reset();
            std::map<uint32_t, uint8_t> init_mem;
            for (auto &e : t.init_ram) { b.set(e.first, e.second); init_mem[e.first & kMemMask] = e.second; }
            b.dut.load_i = 1;
            for (int k = 0; k < 20; ++k) {
                b.dut.load_idx_i = k;
                b.dut.load_data_i = t.init[k];
                b.tick();
            }
            b.dut.load_i = 0;
            std::string why;
            unsigned guard = 0;
            while (!b.dut.halted_o && !b.dut.shutdown_o && guard < 400000) { b.tick(); ++guard; }
            if (!b.dut.halted_o) why = b.dut.shutdown_o ? "shutdown" : "watchdog";
            for (int k = 0; k < 20 && why.empty(); ++k) {
                uint32_t mask = (k == 17) ? t.flag_mask : 0xFFFFFFFFu;
                if ((b.reg(k) & mask) != (t.fin[k] & mask)) {
                    char line[160];
                    std::snprintf(line, sizeof line, "%s expected %08X got %08X (mask %08X)",
                                  kRegNames[k], t.fin[k], b.reg(k), mask);
                    why = line;
                }
            }
            std::map<uint32_t, uint8_t> expect;
            for (auto &e : t.fin_ram) expect[e.first & kMemMask] = e.second;
            auto byte_mask = [&](uint32_t a) -> uint8_t {
                if (t.exc_flag_addr == kNone) return 0xFF;
                if ((a & kMemMask) == (t.exc_flag_addr & kMemMask)) return uint8_t(t.flag_mask);
                if ((a & kMemMask) == ((t.exc_flag_addr + 1) & kMemMask)) return uint8_t(t.flag_mask >> 8);
                return 0xFF;
            };
            for (auto &e : expect) {
                if (!why.empty()) break;
                uint8_t m = byte_mask(e.first);
                if ((b.memory[e.first] & m) != (e.second & m)) {
                    char line[160];
                    std::snprintf(line, sizeof line, "mem[%06X] expected %02X got %02X",
                                  e.first, e.second, b.memory[e.first]);
                    why = line;
                }
            }
            for (auto &w : b.written) {
                if (!why.empty()) break;
                if (expect.count(w.first)) continue;
                auto it = init_mem.find(w.first);
                uint8_t before = it == init_mem.end() ? 0 : it->second;
                if (w.second != before) {
                    char line[160];
                    std::snprintf(line, sizeof line, "unexpected write mem[%06X]=%02X", w.first, w.second);
                    why = line;
                }
            }
            auto &pf = per_file[t.file];
            if (why.empty()) { ++pass; ++pf.first; }
            else {
                ++fail; ++pf.second;
                if (reported[t.file]++ < max_report)
                    std::cout << "FAIL file " << t.file << " test " << t.idx << " [" << t.name
                              << "] " << why << (t.exc_number != kNone ? " (exception " +
                              std::to_string(t.exc_number) + ")" : "") << "\n";
            }
        }
        for (auto &f : per_file)
            std::cout << "RESULT file " << f.first << " pass " << f.second.first
                      << " fail " << f.second.second << "\n";
        std::cout << "TOTAL pass " << pass << " fail " << fail << " cycles " << b.cycles << "\n";
        b.dut.final();
        return fail ? 1 : 0;
    } catch (const std::exception &e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 2;
    }
}
