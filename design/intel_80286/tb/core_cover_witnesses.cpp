// Generate pure primary-input-only .smtc traces from reset for all deep
// connected-core formal cover obligations (cov_deep_* in intel_80286_props.sv).
// These traces are subsequently verified against the full assertion model by
// yosys-smtbmc in scripts/run_core_cover_witnesses.py; this tool only produces
// stimulus sequences and step windows.
#include "Vintel_80286.h"
#include "verilated.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct CycleInputs {
    bool rst_n;
    bool bus_ready_i;
    uint16_t bus_rdata_i;
    bool intr_i;
    bool nmi_i;
    bool inta_ready_i;
    uint8_t inta_vector_i;
    bool busy_i;
    bool error_n_i;
    bool pereq_i;
};

struct ScenarioMeta {
    std::string name;
    std::string smtc_filename;
    std::vector<std::string> targets;
    int min_step = 0;
    int max_step = 0;
    int total_steps = 0;
};

std::string hex16(uint16_t value) {
    std::ostringstream out;
    out << "#x" << std::hex << std::nouppercase << std::setw(4) << std::setfill('0') << value;
    return out.str();
}

std::string hex8(uint8_t value) {
    std::ostringstream out;
    out << "#x" << std::hex << std::nouppercase << std::setw(2) << std::setfill('0')
        << static_cast<unsigned>(value);
    return out.str();
}

void write_smtc(const fs::path& path, const std::vector<CycleInputs>& trace) {
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Cannot open .smtc for writing: " + path.string());
    }
    for (size_t step = 0; step < trace.size(); ++step) {
        const auto& c = trace[step];
        out << "state " << step << "\n";
        out << "assume (= [rst_n] " << (c.rst_n ? "true" : "false") << ")\n";
        out << "assume (= [bus_ready_i] " << (c.bus_ready_i ? "true" : "false") << ")\n";
        out << "assume (= [bus_rdata_i] " << hex16(c.bus_rdata_i) << ")\n";
        out << "assume (= [intr_i] " << (c.intr_i ? "true" : "false") << ")\n";
        out << "assume (= [nmi_i] " << (c.nmi_i ? "true" : "false") << ")\n";
        out << "assume (= [inta_ready_i] " << (c.inta_ready_i ? "true" : "false") << ")\n";
        out << "assume (= [inta_vector_i] " << hex8(c.inta_vector_i) << ")\n";
        out << "assume (= [busy_i] " << (c.busy_i ? "true" : "false") << ")\n";
        out << "assume (= [error_n_i] " << (c.error_n_i ? "true" : "false") << ")\n";
        out << "assume (= [pereq_i] " << (c.pereq_i ? "true" : "false") << ")\n\n";
    }
}

void place_bytes(std::vector<uint8_t>& mem, uint32_t addr, const std::vector<uint8_t>& bytes) {
    if (addr + bytes.size() > mem.size()) {
        throw std::runtime_error("Memory write out of bounds");
    }
    std::copy(bytes.begin(), bytes.end(), mem.begin() + addr);
}

void place_real_program(std::vector<uint8_t>& mem, const std::vector<uint8_t>& prog) {
    // At reset cs_base is 0xFF0000, so F000:FFF0 is physical 0xFFFFF0.
    // Far JMP to F000:0100 sets cs_base=0x0F0000 (consistent across IRET).
    place_bytes(mem, 0x00fffff0u, {0xea, 0x00, 0x01, 0x00, 0xf0});
    place_bytes(mem, 0x000f0100u, prog);
}

void set_ivt(std::vector<uint8_t>& mem, uint32_t idt_base, uint8_t vec,
             uint16_t off, uint16_t seg) {
    uint32_t addr = idt_base + static_cast<uint32_t>(vec) * 4u;
    place_bytes(mem, addr, {
        static_cast<uint8_t>(off & 0xffu),
        static_cast<uint8_t>((off >> 8) & 0xffu),
        static_cast<uint8_t>(seg & 0xffu),
        static_cast<uint8_t>((seg >> 8) & 0xffu),
    });
}

void set_desc(std::vector<uint8_t>& mem, uint32_t gdt_base, uint16_t sel,
              uint16_t limit, uint32_t base, uint8_t access) {
    uint32_t addr = gdt_base + (sel & 0xfff8u);
    place_bytes(mem, addr, {
        static_cast<uint8_t>(limit & 0xffu),
        static_cast<uint8_t>((limit >> 8) & 0xffu),
        static_cast<uint8_t>(base & 0xffu),
        static_cast<uint8_t>((base >> 8) & 0xffu),
        static_cast<uint8_t>((base >> 16) & 0xffu),
        access,
        0x00,
        0x00,
    });
}

uint32_t cache_base(const Vintel_80286& d, unsigned n) {
    const unsigned bit = n * 24, word = bit / 32, shift = bit % 32;
    uint64_t value = d.seg_bases_o[word];
    if (shift > 8 && word < 2) {
        value |= static_cast<uint64_t>(d.seg_bases_o[word + 1]) << 32;
    }
    return static_cast<uint32_t>(value >> shift) & 0xffffffu;
}

void set_gate(std::vector<uint8_t>& mem, uint32_t idt_base, uint8_t vec,
              uint16_t sel, uint16_t off, uint8_t access) {
    uint32_t addr = idt_base + static_cast<uint32_t>(vec) * 8u;
    place_bytes(mem, addr, {
        static_cast<uint8_t>(off & 0xffu),
        static_cast<uint8_t>((off >> 8) & 0xffu),
        static_cast<uint8_t>(sel & 0xffu),
        static_cast<uint8_t>((sel >> 8) & 0xffu),
        0x00,
        access,
        0x00,
        0x00,
    });
}

struct Machine {
    Vintel_80286 dut;
    std::vector<uint8_t> mem;
    std::unordered_map<uint16_t, uint8_t> ports;
    std::vector<CycleInputs> trace;

    Machine() : mem(1u << 24, 0) {}

    template <typename StepHook, typename DoneHook>
    ScenarioMeta run(const std::string& name,
                     const std::vector<std::string>& targets,
                     int max_cycles,
                     StepHook step_hook,
                     DoneHook done_hook,
                     int forced_min_step = -1) {
        int min_step = -1;
        int max_step = -1;
        int done_countdown = -1;

        for (int k = 0; k < max_cycles; ++k) {
            CycleInputs in{};
            if (k == 0) {
                in.rst_n = false;
                in.bus_ready_i = false;
                in.bus_rdata_i = 0;
                in.intr_i = false;
                in.nmi_i = false;
                in.inta_ready_i = false;
                in.inta_vector_i = 0;
                in.busy_i = false;
                in.error_n_i = true;
                in.pereq_i = false;
            } else {
                in.rst_n = true;
                in.bus_ready_i = true;
                in.bus_rdata_i = 0;
                in.intr_i = false;
                in.nmi_i = false;
                in.inta_ready_i = false;
                in.inta_vector_i = 0;
                in.busy_i = false;
                in.error_n_i = true;
                in.pereq_i = false;
            }

            dut.clk = 0;
            dut.rst_n = in.rst_n;
            dut.bus_ready_i = in.bus_ready_i;
            dut.bus_rdata_i = in.bus_rdata_i;
            dut.intr_i = in.intr_i;
            dut.nmi_i = in.nmi_i;
            dut.inta_ready_i = in.inta_ready_i;
            dut.inta_vector_i = in.inta_vector_i;
            dut.busy_i = in.busy_i;
            dut.error_n_i = in.error_n_i;
            dut.pereq_i = in.pereq_i;
            dut.eval();

            if (k > 0) {
                step_hook(k, dut, in);
                if (dut.bus_req_o && in.bus_ready_i) {
                    const uint32_t addr = dut.bus_addr_o & 0xffffffu;
                    if (dut.bus_io_o) {
                        const uint16_t port = static_cast<uint16_t>(addr & 0xffffu);
                        if (dut.bus_write_o) {
                            ports[port] = static_cast<uint8_t>(dut.bus_wdata_o & 0xffu);
                        } else {
                            auto it = ports.find(port);
                            in.bus_rdata_i = (it != ports.end()) ? it->second : 0;
                        }
                    } else {
                        if (dut.bus_write_o) {
                            mem[addr] = static_cast<uint8_t>(dut.bus_wdata_o & 0xffu);
                        } else {
                            in.bus_rdata_i = mem[addr];
                        }
                    }
                }
                if (dut.inta_req_o) {
                    in.inta_ready_i = true;
                }
                dut.rst_n = in.rst_n;
                dut.bus_ready_i = in.bus_ready_i;
                dut.bus_rdata_i = in.bus_rdata_i;
                dut.intr_i = in.intr_i;
                dut.nmi_i = in.nmi_i;
                dut.inta_ready_i = in.inta_ready_i;
                dut.inta_vector_i = in.inta_vector_i;
                dut.busy_i = in.busy_i;
                dut.error_n_i = in.error_n_i;
                dut.pereq_i = in.pereq_i;
                dut.eval();
            }

            if (dut.fault_o) {
                throw std::runtime_error(name + ": unexpected fault_o at cycle " + std::to_string(k));
            }

            bool relevant = false;
            bool finished = false;
            if (k > 0) {
                done_hook(k, dut, relevant, finished);
                if (relevant) {
                    if (min_step < 0) min_step = std::max(0, k - 2);
                    max_step = k + 2;
                }
                if (finished && done_countdown < 0) {
                    done_countdown = 3;
                }
            }

            trace.push_back(in);

            dut.clk = 1;
            dut.eval();
            dut.clk = 0;
            dut.eval();

            if (done_countdown == 0) {
                break;
            }
            if (done_countdown > 0) {
                --done_countdown;
            }
        }

        if (min_step < 0) {
            throw std::runtime_error(name + ": scenario never reached its completion condition");
        }
        if (forced_min_step >= 0) {
            min_step = forced_min_step;
        }
        const int total = static_cast<int>(trace.size());
        max_step = std::min(total - 1, std::max(min_step, max_step));
        return ScenarioMeta{name, name + ".smtc", targets, min_step, max_step, total};
    }
};

ScenarioMeta run_real_control_stack(const fs::path& dir) {
    Machine m;
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0xe8, 0x00, 0x00,              // CALL $+3
        0x60,                          // PUSHA
        0xc8, 0x04, 0x00, 0x00,        // ENTER 4, 0
        0x9a, 0x00, 0x02, 0x00, 0xf0,  // CALL FAR F000:0200
    });
    place_bytes(m.mem, 0x000f0200u, {0xf4});  // HLT
    unsigned mask = 0;
    auto meta = m.run(
        "real_control_stack",
        {"cov_deep_near_call", "cov_deep_pusha", "cov_deep_enter", "cov_deep_real_far_call"},
        200,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.retire_o) {
                if (d.retire_opcode_o == 0xe8) { mask |= 1u; rel = true; }
                if (d.retire_opcode_o == 0x60) { mask |= 2u; rel = true; }
                if (d.retire_opcode_o == 0xc8) { mask |= 4u; rel = true; }
                if (d.retire_opcode_o == 0x9a) { mask |= 8u; rel = true; }
            }
            done = (mask == 0x0fu);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_bcd_io_lds(const fs::path& dir) {
    Machine m;
    place_bytes(m.mem, 0x000040u, {0x34, 0x12, 0x00, 0x01});  // 0100:1234 -> ds_base=0x1000
    m.ports[0x0080] = 0x55;
    place_real_program(m.mem, {
        0xb8, 0x0a, 0x00,              // MOV AX, 000Ah
        0x37,                          // AAA -> AX=0100h
        0xd4, 0x0a,                    // AAM 10
        0xba, 0x80, 0x00,              // MOV DX, 0080h
        0xbf, 0x00, 0x02,              // MOV DI, 0200h
        0x6c,                          // INSB
        0xc5, 0x1e, 0x40, 0x00,        // LDS BX, [0040h]
        0xf4                           // HLT
    });
    unsigned mask = 0;
    auto meta = m.run(
        "real_bcd_io_lds",
        {"cov_deep_aaa_0100", "cov_deep_aam", "cov_deep_insb_element", "cov_deep_real_lds"},
        200,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.element_o) { mask |= 1u; rel = true; }
            if (d.retire_o) {
                if (d.retire_opcode_o == 0x37) { mask |= 2u; rel = true; }
                if (d.retire_opcode_o == 0xd4) { mask |= 4u; rel = true; }
                if (d.retire_opcode_o == 0xc5) { mask |= 8u; rel = true; }
            }
            done = (mask == 0x0fu);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_div_and_de(const fs::path& dir) {
    Machine m;
    set_ivt(m.mem, 0, 0, 0x0200, 0x0000);
    place_bytes(m.mem, 0x000200u, {0xf4});
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0xba, 0x00, 0x00,              // MOV DX, 0000h
        0xb8, 0x04, 0x00,              // MOV AX, 0004h
        0xbb, 0x02, 0x00,              // MOV BX, 0002h
        0xf7, 0xf3,                    // DIV BX
        0xbb, 0x00, 0x00,              // MOV BX, 0000h
        0xf7, 0xf3                     // DIV BX -> #DE
    });
    unsigned mask = 0;
    auto meta = m.run(
        "real_div_and_de",
        {"cov_deep_div16", "cov_deep_div_zero_vec0"},
        250,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.retire_o && d.retire_opcode_o == 0xf7) { mask |= 1u; rel = true; }
            if (d.event_o && d.event_vector_o == 0) { mask |= 2u; rel = true; }
            done = (mask == 3u);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_bound_ud_vec13(const fs::path& dir) {
    Machine m;
    place_bytes(m.mem, 0x000040u, {0x00, 0x00, 0x10, 0x00});
    set_ivt(m.mem, 0, 5, 0x0200, 0x0000);
    set_ivt(m.mem, 0, 6, 0x0210, 0x0000);
    set_ivt(m.mem, 0, 13, 0x0220, 0x0000);
    place_bytes(m.mem, 0x000200u, {0x64});              // #UD
    place_bytes(m.mem, 0x000210u, {0xa1, 0xff, 0xff});  // MOV AX, [FFFF] -> #13
    place_bytes(m.mem, 0x000220u, {0xf4});
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0xb8, 0x05, 0x00,              // MOV AX, 0005h
        0x62, 0x06, 0x40, 0x00,        // BOUND AX, [0040h] (ok)
        0xb8, 0x20, 0x00,              // MOV AX, 0020h
        0x62, 0x06, 0x40, 0x00         // BOUND AX, [0040h] -> #BR (5)
    });
    unsigned mask = 0;
    auto meta = m.run(
        "real_bound_ud_vec13",
        {"cov_deep_bound_retire", "cov_deep_bound_vec5", "cov_deep_ud_64h_vec6", "cov_deep_vec13_fault"},
        300,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.retire_o && d.retire_opcode_o == 0x62) { mask |= 1u; rel = true; }
            if (d.event_o && !d.retire_o) {
                if (d.event_vector_o == 5) { mask |= 2u; rel = true; }
                if (d.event_vector_o == 6) { mask |= 4u; rel = true; }
                if (d.event_vector_o == 13) { mask |= 8u; rel = true; }
            }
            done = (mask == 0x0fu);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_strings_and_rep_nmi(const fs::path& dir) {
    Machine m;
    place_bytes(m.mem, 0x000040u, {0x11, 0x22, 0x33, 0x44});
    place_bytes(m.mem, 0x000050u, {0x11, 0x99, 0x33, 0x44});
    set_ivt(m.mem, 0, 2, 0x0200, 0x0000);
    place_bytes(m.mem, 0x000200u, {0xf4});
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0xbe, 0x40, 0x00,              // MOV SI, 0040h
        0xbf, 0x50, 0x00,              // MOV DI, 0050h
        0xb9, 0x03, 0x00,              // MOV CX, 0003h
        0xf3, 0xa6,                    // REPE CMPSB (stops at elem 2, CX=1)
        0xb9, 0x04, 0x00,              // MOV CX, 0004h
        0xf3, 0xa4                     // REP MOVSB (NMI interrupts after elem 1)
    });
    bool cmps_retired = false;
    bool nmi_sent = false;
    unsigned mask = 0;
    auto meta = m.run(
        "real_strings_and_rep_nmi",
        {"cov_deep_rep_element", "cov_deep_repe_cmpsb_early", "cov_deep_async_rep"},
        300,
        [&](int, const Vintel_80286& d, CycleInputs& in) {
            if (cmps_retired && d.element_o && !d.retire_o && !nmi_sent) {
                in.nmi_i = true;
                nmi_sent = true;
            }
        },
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.element_o && !d.retire_o) { mask |= 1u; rel = true; }
            if (d.retire_o && d.retire_opcode_o == 0xa6) {
                cmps_retired = true;
                mask |= 2u;
                rel = true;
            }
            if (d.event_o && d.event_vector_o == 2) { mask |= 4u; rel = true; }
            done = (mask == 7u);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_async_events(const fs::path& dir) {
    Machine m;
    set_ivt(m.mem, 0, 0x20, 0x0200, 0x0000);
    set_ivt(m.mem, 0, 0x02, 0x0200, 0x0000);
    set_ivt(m.mem, 0, 0x01, 0x0210, 0x0000);
    place_bytes(m.mem, 0x000200u, {0xcf});  // IRET
    place_bytes(m.mem, 0x000210u, {0xf4});  // HLT
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0xfb,                          // STI
        0x90,                          // NOP (accepts INTR 0x20)
        0x90,                          // NOP
        0xf4,                          // HLT (woken by NMI)
        0xb8, 0x00, 0x01,              // MOV AX, 0100h (TF=1)
        0x50,                          // PUSH AX
        0x9d,                          // POPF
        0x90                           // NOP -> #DB vector 1
    });
    bool sti_retired = false;
    bool intr_done = false;
    bool nmi_sent = false;
    unsigned mask = 0;
    auto meta = m.run(
        "real_async_events",
        {
            "cov_deep_intr_vec20", "cov_deep_async_halt",
            "cov_deep_nmi_event", "cov_deep_async_nmi", "cov_deep_async_debug_tf"
        },
        350,
        [&](int, const Vintel_80286& d, CycleInputs& in) {
            if (sti_retired && !intr_done) {
                in.intr_i = true;
            }
            if (d.inta_req_o) {
                in.inta_vector_i = 0x20;
            }
            if (d.halted_o && !nmi_sent) {
                in.nmi_i = true;
                nmi_sent = true;
            }
        },
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.retire_o && d.retire_opcode_o == 0xfb) {
                sti_retired = true;
            }
            if (d.event_o) {
                if (d.event_vector_o == 0x20) { intr_done = true; mask |= 1u; rel = true; }
                if (d.event_vector_o == 0x02) { mask |= 2u; rel = true; }
                if (d.event_vector_o == 0x01) { mask |= 4u; rel = true; }
            }
            done = (mask == 7u);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_system_and_idt_limit(const fs::path& dir) {
    Machine m;
    place_bytes(m.mem, 0x000040u, {0x1f, 0x00, 0x00, 0x03, 0x00, 0x00});  // GDTR base 0x000300
    place_bytes(m.mem, 0x000048u, {0x23, 0x00, 0x00, 0x06, 0x00, 0x00});  // IDTR limit 35, base 0x000600
    set_ivt(m.mem, 0x000600u, 8, 0x0200, 0x0000);
    place_bytes(m.mem, 0x000200u, {0xf4});
    place_real_program(m.mem, {
        0xbc, 0x00, 0x01,              // MOV SP, 0100h
        0x0f, 0x01, 0x16, 0x40, 0x00,  // LGDT [0040h]
        0x0f, 0x01, 0x06, 0x50, 0x00,  // SGDT [0050h]
        0x0f, 0x01, 0x1e, 0x48, 0x00,  // LIDT [0048h]
        0xb8, 0x08, 0x00,              // MOV AX, 0008h (TS=1)
        0x0f, 0x01, 0xf0,              // LMSW AX
        0x0f, 0x01, 0xe0,              // SMSW AX (retires 0F with msw[3]==1)
        0xcd, 0x10                     // INT 10h -> exceeds IDT limit 35 -> #8
    });
    int sys_retires = 0;
    bool df_seen = false;
    auto meta = m.run(
        "real_system_and_idt_limit",
        {"cov_deep_lgdt_nonzero", "cov_deep_sgdt", "cov_deep_msw_ts_0f", "cov_deep_real_idt_limit_df"},
        250,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (d.retire_o && d.retire_opcode_o == 0x0f) {
                ++sys_retires;
                rel = true;
            }
            if (d.event_o && d.event_vector_o == 8 && !d.retire_o) {
                df_seen = true;
                rel = true;
            }
            done = (sys_retires >= 5 && df_seen);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_real_shutdown_nmi_fail(const fs::path& dir) {
    Machine m;
    place_real_program(m.mem, {
        0xbc, 0x01, 0x00,              // MOV SP, 0001h
        0x50                           // PUSH AX -> SHUTDOWN
    });
    bool first_shutdown = false;
    bool nmi_pulsed = false;
    int wait_after_nmi = 0;
    auto meta = m.run(
        "real_shutdown_nmi_fail",
        {"cov_deep_shutdown_nmi_failed"},
        120,
        [&](int, const Vintel_80286& d, CycleInputs& in) {
            if (d.shutdown_o && !nmi_pulsed) {
                first_shutdown = true;
                in.nmi_i = true;
                nmi_pulsed = true;
            }
        },
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if (first_shutdown) {
                rel = true;
                if (nmi_pulsed) ++wait_after_nmi;
                if (wait_after_nmi > 4 && d.shutdown_o) {
                    done = true;
                }
            }
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

void setup_protected_gdt(std::vector<uint8_t>& mem, bool with_es_ds2) {
    const uint16_t limit = with_es_ds2 ? 0x0027u : 0x001fu;
    place_bytes(mem, 0x000040u, {
        static_cast<uint8_t>(limit & 0xffu),
        static_cast<uint8_t>((limit >> 8) & 0xffu),
        0x00, 0x03, 0x00, 0x00
    });
    set_desc(mem, 0x000300u, 0x0008, 0x0fff, 0x010000u, 0x9a);  // code
    set_desc(mem, 0x000300u, 0x0010, 0x0fff, 0x020000u, 0x92);  // data
    set_desc(mem, 0x000300u, 0x0018, 0x0fff, 0x030000u, 0x92);  // stack
    if (with_es_ds2) {
        set_desc(mem, 0x000300u, 0x0020, 0x0fff, 0x040000u, 0x92);  // data2
    }
}

ScenarioMeta run_prot_segments_and_jmp(const fs::path& dir) {
    Machine m;
    setup_protected_gdt(m.mem, true);
    place_bytes(m.mem, 0x040020u, {0x34, 0x12, 0x10, 0x00});
    place_real_program(m.mem, {
        0x0f, 0x01, 0x16, 0x40, 0x00,  // LGDT [0040h]
        0xb8, 0x01, 0x00,              // MOV AX, 0001h
        0x0f, 0x01, 0xf0,              // LMSW AX
        0xeb, 0x00,                    // JMP $+2
        0xea, 0x00, 0x00, 0x08, 0x00   // JMP FAR 0008:0000
    });
    place_bytes(m.mem, 0x010000u, {
        0xb8, 0x10, 0x00,              // MOV AX, 0010h
        0x8e, 0xd8,                    // MOV DS, AX
        0x8e, 0xc0,                    // MOV ES, AX
        0xb8, 0x18, 0x00,              // MOV AX, 0018h
        0x8e, 0xd0,                    // MOV SS, AX
        0xbc, 0x80, 0x00,              // MOV SP, 0080h
        0xb8, 0x20, 0x00,              // MOV AX, 0020h
        0x50,                          // PUSH AX
        0x1f,                          // POP DS (ds_base=0x040000)
        0xc5, 0x1e, 0x20, 0x00,        // LDS BX, [0020h] (ds_base=0x020000)
        0xf4                           // HLT
    });
    unsigned mask = 0;
    auto meta = m.run(
        "prot_segments_and_jmp",
        {
            "cov_deep_prot_far_jmp", "cov_deep_prot_mov_ds", "cov_deep_prot_mov_es",
            "cov_deep_prot_mov_ss", "cov_deep_prot_pop_ds", "cov_deep_prot_lds"
        },
        350,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int, const Vintel_80286& d, bool& rel, bool& done) {
            if ((d.msw_o & 1u) && d.retire_o) {
                if (d.retire_opcode_o == 0xea) { mask |= 1u; rel = true; }
                if (d.retire_opcode_o == 0x8e) {
                    if (cache_base(d, 3) != 0) mask |= 2u;  // ds_base != 0
                    if (cache_base(d, 0) != 0) mask |= 4u;  // es_base != 0
                    if (cache_base(d, 2) != 0) mask |= 8u;  // ss_base != 0
                    rel = true;
                }
                if (d.retire_opcode_o == 0x1f) { mask |= 16u; rel = true; }
                if (d.retire_opcode_o == 0xc5) { mask |= 32u; rel = true; }
            }
            done = (mask == 0x3fu);
        });
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_prot_event_and_iret(const fs::path& dir) {
    Machine m;
    setup_protected_gdt(m.mem, false);
    place_bytes(m.mem, 0x000046u, {0x7f, 0x00, 0x00, 0x05, 0x00, 0x00});  // IDTR base 0x000500
    set_gate(m.mem, 0x000500u, 13, 0x0008, 0x0100, 0x86);
    place_real_program(m.mem, {
        0x0f, 0x01, 0x16, 0x40, 0x00,  // LGDT [0040h]
        0x0f, 0x01, 0x1e, 0x46, 0x00,  // LIDT [0046h]
        0xb8, 0x01, 0x00,              // MOV AX, 0001h
        0x0f, 0x01, 0xf0,              // LMSW AX
        0xeb, 0x00,                    // JMP $+2
        0xea, 0x00, 0x00, 0x08, 0x00   // JMP FAR 0008:0000
    });
    place_bytes(m.mem, 0x010000u, {
        0xb8, 0x18, 0x00,              // MOV AX, 0018h
        0x8e, 0xd0,                    // MOV SS, AX
        0xbc, 0x80, 0x00,              // MOV SP, 0080h
        0xb8, 0x28, 0x00,              // MOV AX, 0028h (out of GDT limit)
        0x8e, 0xd8                     // MOV DS, AX -> #GP(0028)
    });
    place_bytes(m.mem, 0x010100u, {
        0x83, 0xc4, 0x02,              // ADD SP, 2
        0xcf                           // IRET -> IRET_COMMIT
    });
    bool gp_entered = false;
    bool iret_retired = false;
    int first_pe = -1;
    auto meta = m.run(
        "prot_event_and_iret",
        {"cov_deep_prot_event_gate_tail", "cov_deep_prot_event_frame_error", "cov_deep_prot_iret_commit"},
        350,
        [](int, const Vintel_80286&, CycleInputs&) {},
        [&](int k, const Vintel_80286& d, bool& rel, bool& done) {
            if ((d.msw_o & 1u) && first_pe < 0) {
                first_pe = k;
            }
            if (d.event_o && d.event_vector_o == 13) {
                gp_entered = true;
                rel = true;
            }
            if (gp_entered && d.retire_o && d.retire_opcode_o == 0xcf) {
                iret_retired = true;
                rel = true;
            }
            done = gp_entered && iret_retired;
        });
    if (first_pe >= 0) {
        meta.min_step = std::min(meta.min_step, first_pe);
    }
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

ScenarioMeta run_prot_nested_df_and_shutdown_nmi(const fs::path& dir) {
    Machine m;
    setup_protected_gdt(m.mem, false);
    place_bytes(m.mem, 0x000046u, {0x00, 0x00, 0x00, 0x05, 0x00, 0x00});  // IDTR limit 0
    place_real_program(m.mem, {
        0x0f, 0x01, 0x16, 0x40, 0x00,  // LGDT [0040h]
        0x0f, 0x01, 0x1e, 0x46, 0x00,  // LIDT [0046h]
        0xb8, 0x01, 0x00,              // MOV AX, 0001h
        0x0f, 0x01, 0xf0,              // LMSW AX
        0xeb, 0x00,                    // JMP $+2
        0xea, 0x00, 0x00, 0x08, 0x00   // JMP FAR 0008:0000
    });
    place_bytes(m.mem, 0x010000u, {
        0xb8, 0x18, 0x00,              // MOV AX, 0018h
        0x8e, 0xd0,                    // MOV SS, AX
        0xbc, 0x80, 0x00,              // MOV SP, 0080h
        0xb8, 0x28, 0x00,              // MOV AX, 0028h
        0x8e, 0xd8                     // MOV DS, AX -> #GP -> #DF -> SHUTDOWN
    });
    bool nmi_pulsed = false;
    int after_nmi = 0;
    int start_window = -1;
    auto meta = m.run(
        "prot_nested_df_and_shutdown_nmi",
        {"cov_deep_prot_nested_df", "cov_deep_shutdown_nmi_prot"},
        350,
        [&](int, const Vintel_80286& d, CycleInputs& in) {
            if (d.shutdown_o && !nmi_pulsed) {
                in.nmi_i = true;
                nmi_pulsed = true;
            }
        },
        [&](int k, const Vintel_80286& d, bool& rel, bool& done) {
            if ((d.msw_o & 1u) && d.event_packet_valid_o) {
                if (start_window < 0) start_window = std::max(0, k - 2);
                rel = true;
            }
            if (nmi_pulsed) {
                ++after_nmi;
                rel = true;
            }
            done = (after_nmi >= 4);
        });
    if (start_window >= 0) {
        meta.min_step = std::min(meta.min_step, start_window);
    }
    write_smtc(dir / meta.smtc_filename, m.trace);
    return meta;
}

void write_manifest(const fs::path& path, const std::vector<ScenarioMeta>& scenarios) {
    std::ofstream out(path, std::ios::binary);
    if (!out) {
        throw std::runtime_error("Cannot open scenarios.json for writing");
    }
    out << "{\n  \"scenarios\": [\n";
    for (size_t i = 0; i < scenarios.size(); ++i) {
        const auto& s = scenarios[i];
        out << "    {\n";
        out << "      \"name\": \"" << s.name << "\",\n";
        out << "      \"smtc\": \"" << s.smtc_filename << "\",\n";
        out << "      \"min_step\": " << s.min_step << ",\n";
        out << "      \"max_step\": " << s.max_step << ",\n";
        out << "      \"total_steps\": " << s.total_steps << ",\n";
        out << "      \"targets\": [";
        for (size_t j = 0; j < s.targets.size(); ++j) {
            if (j > 0) out << ", ";
            out << "\"" << s.targets[j] << "\"";
        }
        out << "]\n";
        out << "    }" << (i + 1 < scenarios.size() ? "," : "") << "\n";
    }
    out << "  ]\n}\n";
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output_dir>\n";
        return 2;
    }
    try {
        const fs::path out_dir(argv[1]);
        fs::create_directories(out_dir);
        std::vector<ScenarioMeta> scenarios;
        scenarios.push_back(run_real_control_stack(out_dir));
        scenarios.push_back(run_real_bcd_io_lds(out_dir));
        scenarios.push_back(run_real_div_and_de(out_dir));
        scenarios.push_back(run_real_bound_ud_vec13(out_dir));
        scenarios.push_back(run_real_strings_and_rep_nmi(out_dir));
        scenarios.push_back(run_real_async_events(out_dir));
        scenarios.push_back(run_real_system_and_idt_limit(out_dir));
        scenarios.push_back(run_real_shutdown_nmi_fail(out_dir));
        scenarios.push_back(run_prot_segments_and_jmp(out_dir));
        scenarios.push_back(run_prot_event_and_iret(out_dir));
        scenarios.push_back(run_prot_nested_df_and_shutdown_nmi(out_dir));
        write_manifest(out_dir / "scenarios.json", scenarios);
        std::cout << "Generated " << scenarios.size() << " cover witness scenarios in "
                  << out_dir.string() << "\n";
        return 0;
    } catch (const std::exception& err) {
        std::cerr << "FAIL: " << err.what() << "\n";
        return 1;
    }
}
