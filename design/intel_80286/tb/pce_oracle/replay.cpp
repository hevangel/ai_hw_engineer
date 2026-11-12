// RTL side of the PCE-286 oracle comparison: run one scenario image from
// RESET on intel_80286 and write the same trace format as pce286_oracle.c.
// One S line is written at every architectural boundary (an instruction
// retirement or an event/handler entry). Extra trailing fields on S lines
// (kind, vector, error) are for reports only.
#include "Vintel_80286.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <vector>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 3) { std::fprintf(stderr, "usage: %s scenario trace [wait]\n", argv[0]); return 2; }
    const bool wait = argc > 3 && std::atoi(argv[3]) != 0;
    std::vector<uint8_t> mem(1u << 24, 0);
    std::map<uint32_t, bool> written;
    uint8_t ports[0x10000] = {0};
    unsigned long steps = 2000;
    char line[65536];
    FILE* in = std::fopen(argv[1], "r");
    FILE* out = std::fopen(argv[2], "w");
    if (!in || !out) { std::perror("replay"); return 2; }
    while (std::fgets(line, sizeof line, in)) {
        char* p = line; unsigned long a; unsigned v; int used;
        if (!std::strncmp(p, "MEM ", 4)) {
            p += 4; if (std::sscanf(p, "%lx%n", &a, &used) != 1) return 2; p += used;
            while (std::sscanf(p, "%2x%n", &v, &used) == 1) { mem[a++ & 0xffffff] = uint8_t(v); p += used; }
        } else if (!std::strncmp(p, "STEPS ", 6)) steps = std::strtoul(p + 6, nullptr, 10);
        else if (!std::strncmp(p, "PORT ", 5)) { if (std::sscanf(p + 5, "%lx %x", &a, &v) == 2) ports[a & 0xffff] = uint8_t(v); }
    }
    std::fclose(in);

    Vintel_80286 d;
    d.intr_i = 0; d.nmi_i = 0; d.inta_ready_i = 0; d.inta_vector_i = 0;
    d.busy_i = 0; d.error_n_i = 1; d.pereq_i = 0; d.bus_ready_i = 0; d.bus_rdata_i = 0;
    d.rst_n = 0;
    for (int i = 0; i < 4; ++i) { d.clk = 0; d.eval(); d.clk = 1; d.eval(); }
    d.rst_n = 1;

    const char* reason = "steps";
    unsigned long records = 0, cycles = 0, idle = 0;
    const unsigned long max_cycles = steps * 4000ul + 100000ul;
    while (records < steps && cycles < max_cycles) {
        d.clk = 0;
        d.bus_ready_i = !wait || (cycles % 4 == 3);
        d.bus_rdata_i = 0;
        d.eval();
        if (d.bus_req_o && d.bus_ready_i) {
            const uint32_t a = d.bus_addr_o & 0xffffff;
            if (d.bus_io_o) {
                if (d.bus_write_o) std::fprintf(out, "O %x %x\n", a & 0xffff, unsigned(d.bus_wdata_o & 0xff));
                else d.bus_rdata_i = ports[a & 0xffff];
            } else if (d.bus_write_o) { mem[a] = uint8_t(d.bus_wdata_o); written[a] = true; }
            else d.bus_rdata_i = mem[a];
        }
        d.eval();
        d.clk = 1; d.eval();
        ++cycles; ++idle;
        const bool stop = d.fault_o, shut = d.shutdown_o;
        if (d.retire_o || d.event_o || stop || shut) {
            unsigned st = shut ? 2 : stop ? 3 : d.halted_o ? 1 : 0;
            // HLT retires one cycle before the halt latch is visible.
            if (!st && d.retire_o && d.retire_opcode_o == 0xf4 && !d.event_o) st = 1;
            auto reg = [&](unsigned n) { return unsigned(uint16_t(d.regs_o[n / 2] >> ((n % 2) * 16))); };
            std::fprintf(out, "S %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %s %x %x\n",
                unsigned(uint16_t(d.segs_o >> 16)), unsigned(d.ip_o), unsigned(d.flags_o),
                reg(0), reg(1), reg(2), reg(3), reg(4), reg(5), reg(6), reg(7),
                unsigned(uint16_t(d.segs_o)), unsigned(uint16_t(d.segs_o >> 32)),
                unsigned(uint16_t(d.segs_o >> 48)), unsigned(d.msw_o), st,
                d.event_o ? (d.retire_o ? "re" : "e") : (stop ? "stop" : shut ? "shutdown" : "r"),
                unsigned(d.event_vector_o), unsigned(d.event_packet_error_code_o));
            ++records; idle = 0;
            if (st == 1) { reason = "halt"; break; }
            if (st == 2) { reason = "shutdown"; break; }
            if (st == 3) { reason = "stop"; std::fprintf(out, "X fault_code %x\n", unsigned(d.fault_code_o)); break; }
        }
        if (idle > 200000) { reason = "hang"; break; }
    }
    for (const auto& w : written) std::fprintf(out, "W %x %x\n", w.first, unsigned(mem[w.first]));
    std::fprintf(out, "END %s\n", reason);
    std::fclose(out);
    return 0;
}
