#include "Vintel_80286_native_cpu.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <unordered_map>
#include <vector>

static void check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

struct Transfer {
    uint32_t address;
    uint8_t bytes;
    uint16_t data;
    bool write;
    bool io;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
    Vintel_80286_native_cpu dut;
        auto request_reset = [&](bool asserted) {
#ifdef TEST_82C284_RESET
            dut.reset_i = 0;
            dut.res_n_i = asserted ? 0 : 1;
#else
            dut.reset_i = asserted ? 1 : 0;
            dut.res_n_i = 1;
#endif
        };
        std::unordered_map<uint32_t, uint8_t> memory;
        std::vector<Transfer> transfers;
        auto put = [&](uint32_t address, std::initializer_list<uint8_t> bytes) {
            for (uint8_t byte : bytes) memory[address++] = byte;
        };
        auto read_byte = [&](uint32_t address) -> uint8_t {
            const auto found = memory.find(address);
            return found == memory.end() ? 0 : found->second;
        };
        auto word_at = [&](uint32_t address) -> uint16_t {
            return uint16_t(read_byte(address)) |
                   (uint16_t(read_byte(address + 1)) << 8);
        };

        // Reset far jump; exercise even/odd words, enable INTR and halt.
        put(0xfffff0, {0xea, 0x00, 0x01, 0x00, 0xf0});
        put(0xf0100, {0xd8, 0xf8,             // register ESC: command and pointers
                      0xb8, 0x34, 0x12,       // MOV AX,1234h
                      0xa3, 0x00, 0x02,       // even word store
                      0xa1, 0x00, 0x02,       // even word load
                      0xbb, 0x00, 0x03,       // MOV BX,0300h
                      0xf0, 0x87, 0x07,       // LOCK XCHG [BX],AX
                      0xf0, 0xa1, 0x00, 0x03, // LOCK MOV AX,[0300h]
                      0xf0, 0xa3, 0x00, 0x03, // LOCK MOV [0300h],AX
                      0xf0, 0xd1, 0x07,       // LOCK ROL word [BX],1
                      0xf0, 0xa1, 0x00, 0x03, // read the rotate result
                      0xa1, 0x00, 0x03,       // unlocked MOV AX,[0300h]
                      0xb8, 0x78, 0x56,       // MOV AX,5678h
                      0x87, 0x07,             // implicit-lock XCHG [BX],AX
                      0xbe, 0x00, 0x04,       // MOV SI,0400h
                      0xbf, 0x00, 0x05,       // MOV DI,0500h
                      0xb9, 0x02, 0x00,       // MOV CX,2
                      0xf3, 0xf0, 0xa4,       // REP LOCK MOVSB
                      0xba, 0x70, 0x00,       // MOV DX,0070h
                      0xbf, 0x10, 0x06,       // MOV DI,0610h
                      0xb9, 0x02, 0x00,       // MOV CX,2
                      0xf3, 0xf0, 0x6c,       // REP LOCK INSB
                      0xbe, 0x10, 0x04,       // MOV SI,0410h
                      0xba, 0x71, 0x00,       // MOV DX,0071h
                      0xb9, 0x02, 0x00,       // MOV CX,2
                      0xf3, 0xf0, 0x6e,       // REP LOCK OUTSB
                      0xa3, 0x01, 0x02,       // odd word store
                      0xa1, 0x01, 0x02,       // odd word load
                      0xbc, 0x00, 0x80,       // MOV SP,8000h
                      0xfb,                   // STI
                      0x90,                   // NOP (interrupt shadow)
                      0xf4, 0xf4});            // HLT, then HLT after IRET
        put(0x0080, {0x80, 0x01, 0x00, 0xf0}); // IRQ vector 20h -> F000:0180
        put(0xf0180, {0xcf});                  // IRET
        put(0x0400, {0x11, 0x22});
        put(0x0410, {0x5a, 0xc3});

        dut.clk_i = 0;
        dut.clk_2x_i = 0;
        request_reset(true);
        dut.ready_n_i = 1;
        dut.cenl_i = 1;
        dut.cen_i = 1;
        dut.cmdly_i = 0;
        dut.hold_i = 0;
        dut.intr_i = 0;
        dut.nmi_i = 0;
        dut.busy_i = 0;
        dut.error_n_i = 1;
        dut.data_i = 0;
        dut.eval();
        unsigned ale_observations = 0;
        unsigned mrdc_observations = 0, mwtc_observations = 0;
        unsigned iorc_observations = 0, iowc_observations = 0;
        unsigned inta_observations = 0, mce_observations = 0, den_observations = 0;
        unsigned reset_processor_clocks = 0;
        auto check_reset_quiet = [&]() {
            if (dut.address_oe_o || dut.data_oe_o || dut.status_oe_o ||
                dut.cycle_active_o || !dut.lock_n_o || dut.ale_o || dut.den_o ||
                !dut.mrdc_n_o || !dut.mwtc_n_o || !dut.iorc_n_o ||
                !dut.iowc_n_o || !dut.inta_n_o || dut.mce_o) {
                std::cerr << "RESET clocks=" << reset_processor_clocks
                          << " clk=" << unsigned(dut.clk_i)
                          << " clk_2x=" << unsigned(dut.clk_2x_i)
                          << " reset=" << unsigned(dut.cpu_reset_o)
                          << " reset_i=" << unsigned(dut.reset_i)
                          << " res_n=" << unsigned(dut.res_n_i)
                          << " outputs: address_oe=" << unsigned(dut.address_oe_o)
                          << " data_oe=" << unsigned(dut.data_oe_o)
                          << " status_oe=" << unsigned(dut.status_oe_o)
                          << " cycle=" << unsigned(dut.cycle_active_o)
                          << " lock_n=" << unsigned(dut.lock_n_o)
                          << " ale=" << unsigned(dut.ale_o)
                          << " den=" << unsigned(dut.den_o)
                          << " mrdc_n=" << unsigned(dut.mrdc_n_o)
                          << " mwtc_n=" << unsigned(dut.mwtc_n_o)
                          << " iorc_n=" << unsigned(dut.iorc_n_o)
                          << " iowc_n=" << unsigned(dut.iowc_n_o)
                          << " inta_n=" << unsigned(dut.inta_n_o)
                          << " mce=" << unsigned(dut.mce_o) << '\n';
                throw std::runtime_error(
                    "native bus or 82288 drove an active cycle during RESET");
            }
        };
        auto one_processor_clock = [&]() {
            for (int n = 0; n != 2; ++n) {
                dut.clk_2x_i = 1;
                // The external CLK runs at twice the processor rate. Drive
                // one full processor-clock period across two system periods.
                dut.clk_i = (n == 0) ? 1 : 0;
                dut.eval();
                if (dut.cpu_reset_o) check_reset_quiet();
                dut.clk_2x_i = 0;
                dut.eval();
                if (dut.cpu_reset_o) check_reset_quiet();
                ale_observations += dut.ale_o;
                mrdc_observations += !dut.mrdc_n_o;
                mwtc_observations += !dut.mwtc_n_o;
                iorc_observations += !dut.iorc_n_o;
                iowc_observations += !dut.iowc_n_o;
                inta_observations += !dut.inta_n_o;
                mce_observations += dut.mce_o;
                den_observations += dut.den_o;
            }
        };
        for (unsigned wait_cycles = 0; reset_processor_clocks < 16;
             ++wait_cycles) {
            check(wait_cycles < 20,
                  "CPU RESET did not assert within two processor clocks");
            one_processor_clock();
            if (dut.cpu_reset_o) ++reset_processor_clocks;
        }
        check(reset_processor_clocks == 16,
              "native CPU RESET was not held for 16 processor clocks");
        request_reset(false);
        dut.ready_n_i = 0;
        dut.hold_i = 1;
        dut.clk_i = 0;
        dut.eval();
        for (unsigned wait_cycles = 0; wait_cycles < 4 && !dut.hlda_o;
             ++wait_cycles) {
            one_processor_clock();
        }
        check(dut.hlda_o && !dut.address_oe_o && !dut.data_oe_o &&
              !dut.lock_oe_o && !dut.cycle_active_o,
              "native CPU wrapper did not release the bus during HOLD");
        dut.hold_i = 0;
        dut.eval();
        one_processor_clock();
        check(!dut.hlda_o, "native CPU wrapper did not release HLDA after HOLD");

        unsigned cycles = 0;
        unsigned inta_ts_count = 0;
        unsigned halt_cycles = 0;
        unsigned even_write_wait_cycles = 0;
        unsigned odd_write_wait_cycles = 0;
        unsigned locked_read_wait_cycles = 0;
        unsigned locked_0300_reads = 0, locked_0300_writes = 0;
        unsigned unlocked_0300_reads = 0, locked_idle_cycles = 0;
        unsigned locked_string_reads = 0, locked_string_writes = 0;
        unsigned locked_string_idle_cycles = 0;
        unsigned locked_0300_1234_writes = 0, locked_0300_2468_writes = 0;
        unsigned locked_0300_5678_writes = 0, locked_0300_2468_reads = 0;
        unsigned locked_io_reads = 0, locked_io_writes = 0;
        unsigned locked_io_5a_writes = 0, locked_io_c3_writes = 0;
        unsigned locked_ins_memory_writes = 0, locked_outs_memory_reads = 0;
        unsigned locked_io_read_wait_cycles = 0, locked_io_write_wait_cycles = 0;
        uint32_t held_wait_address = 0;
        uint16_t held_wait_data = 0;
        uint8_t held_wait_bhe_n = 0;
        bool inta_pair_pending = false;
        bool saw_second_inta_tc = false;
        bool reset_fetch_status_seen = false;
        bool wait_snapshot_valid = false;
        bool locked_hold_requested = false, hold_released_after_lock = false;
        bool string_hold_requested = false, string_hold_released = false;
        bool last_status_io = false;
        uint32_t last_status_address = 0;
        std::vector<bool> inta_lock;
        while (halt_cycles < 2 && cycles < 5000) {
            dut.clk_i = 0;
            dut.ready_n_i = 0;
            dut.eval();

            const uint8_t status = (uint8_t(dut.cod_inta_o) << 3) |
                                   (uint8_t(dut.m_io_o) << 2) |
                                   (uint8_t(dut.s1_o) << 1) |
                                   uint8_t(dut.s0_o);
            if (dut.status_oe_o && status == 0x0d && !reset_fetch_status_seen) {
                check(dut.address_oe_o && dut.address_o == 0x00fffff0u,
                      "first reset fetch was not at physical FFFFF0h");
                reset_fetch_status_seen = true;
            }
            if (dut.status_oe_o) {
                last_status_address = dut.address_o;
                last_status_io = status == 0x09 || status == 0x0a;
            }
            if (dut.status_oe_o && status == 0x0d && !dut.lock_n_o)
                throw std::runtime_error("LOCK# was asserted during instruction fetch");
            if (dut.status_oe_o && status == 0) {
                ++inta_ts_count;
                inta_pair_pending = true;
                inta_lock.push_back(!dut.lock_n_o);
            }
            const bool halt_status = dut.status_oe_o && status == 0x4 &&
                                     dut.address_oe_o && (dut.address_o & 2u);
            if (halt_status) {
                ++halt_cycles;
                if (halt_cycles == 1) dut.intr_i = 1;
            }

            // The interrupt controller presents its vector on the second
            // INTA perform phase. The CPU pin controller captures it at READY.
            const bool second_inta_tc = inta_pair_pending && inta_ts_count == 2 &&
                                        dut.cycle_active_o && !dut.status_oe_o;
            if (second_inta_tc) {
                dut.data_i = 0x0020;
                saw_second_inta_tc = true;
            } else if (dut.address_oe_o) {
                if (last_status_io && last_status_address == dut.address_o) {
                    dut.data_i = dut.address_o == 0x0070 ? 0x00ab : 0;
                } else {
                    const uint32_t address = dut.address_o & 0x00fffffeu;
                    dut.data_i = uint16_t(read_byte(address)) |
                                 (uint16_t(read_byte(address + 1)) << 8);
                }
            } else {
                dut.data_i = 0;
            }

            bool wait_this_cycle = false;
            if (dut.cycle_active_o && !dut.status_oe_o && dut.address_o == 0x0300 &&
                !dut.data_oe_o && !dut.lock_n_o && locked_read_wait_cycles < 2) {
                wait_this_cycle = true;
                ++locked_read_wait_cycles;
            } else if (dut.cycle_active_o && !dut.status_oe_o && dut.data_oe_o &&
                       last_status_io && last_status_address == dut.address_o &&
                       dut.address_o == 0x0071 && locked_io_write_wait_cycles < 1) {
                wait_this_cycle = true;
                ++locked_io_write_wait_cycles;
            } else if (dut.cycle_active_o && !dut.status_oe_o &&
                       last_status_io && last_status_address == dut.address_o &&
                       dut.address_o == 0x0070 && !dut.data_oe_o &&
                       locked_io_read_wait_cycles < 1) {
                wait_this_cycle = true;
                ++locked_io_read_wait_cycles;
            } else if (dut.cycle_active_o && !dut.status_oe_o && dut.data_oe_o &&
                dut.address_o == 0x0200 && even_write_wait_cycles < 3) {
                wait_this_cycle = true;
                ++even_write_wait_cycles;
            } else if (dut.cycle_active_o && !dut.status_oe_o && dut.data_oe_o &&
                       dut.address_o == 0x0201 && odd_write_wait_cycles < 2) {
                wait_this_cycle = true;
                ++odd_write_wait_cycles;
            }
            if (wait_this_cycle) {
                dut.ready_n_i = 1;
                if (dut.address_o == 0x0300 && (dut.lock_n_o || dut.data_oe_o))
                    throw std::runtime_error("LOCK# was not held through a READY wait");
                if (last_status_io && (dut.address_o == 0x0070 ||
                                       dut.address_o == 0x0071) && dut.lock_n_o)
                    throw std::runtime_error("LOCK# was not held through an I/O READY wait");
                if (dut.data_oe_o) {
                    if (!wait_snapshot_valid) {
                        held_wait_address = dut.address_o;
                        held_wait_data = dut.data_o;
                        held_wait_bhe_n = dut.bhe_n_o;
                        wait_snapshot_valid = true;
                    } else if (held_wait_address != dut.address_o ||
                               held_wait_data != dut.data_o ||
                               held_wait_bhe_n != dut.bhe_n_o) {
                        throw std::runtime_error("native write pins changed during READY wait");
                    }
                }
            } else if (wait_snapshot_valid && dut.cycle_active_o &&
                       !dut.status_oe_o && dut.address_o == held_wait_address &&
                       dut.data_oe_o) {
                if (held_wait_address == 0x0200 && even_write_wait_cycles == 3 &&
                    (dut.data_o != held_wait_data || dut.bhe_n_o != held_wait_bhe_n))
                    throw std::runtime_error("even-word write pins changed before READY");
                if (held_wait_address == 0x0201 && odd_write_wait_cycles == 2 &&
                    (dut.data_o != held_wait_data || dut.bhe_n_o != held_wait_bhe_n))
                    throw std::runtime_error("odd-byte write pins changed before READY");
            }
            if (wait_this_cycle) dut.ready_n_i = 1;
            else dut.ready_n_i = 0;
            dut.eval();
            if (!wait_this_cycle && wait_snapshot_valid &&
                dut.completed_bytes_o != 0 && dut.address_o == held_wait_address)
                wait_snapshot_valid = false;

            if (dut.protocol_error_o)
                throw std::runtime_error("native CPU wrapper reported a protocol error");
            if (locked_hold_requested && dut.hold_i && !dut.lock_n_o &&
                !dut.cycle_active_o) {
                ++locked_idle_cycles;
                if (dut.hlda_o)
                    throw std::runtime_error("HOLD was granted between locked operand cycles");
            }
            if (string_hold_requested && dut.hold_i && !dut.lock_n_o &&
                !dut.cycle_active_o) {
                ++locked_string_idle_cycles;
                if (dut.hlda_o)
                    throw std::runtime_error("HOLD was granted inside REP LOCK MOVSB");
            }
            if (dut.completed_bytes_o != 0) {
                const uint32_t address = dut.address_o;
                const uint8_t bytes = dut.completed_bytes_o;
                const bool write = dut.data_oe_o;
                const uint16_t value = write ? dut.data_o :
                    (bytes == 1 ? ((address & 1) ? (dut.data_i & 0xff00) :
                                                    (dut.data_i & 0x00ff)) : dut.data_i);
                const bool io_transfer = last_status_io && last_status_address == address;
                transfers.push_back({address, bytes, value, write, io_transfer});
                if (address == 0x0300) {
                    if (!dut.lock_n_o) {
                        if (write) {
                            ++locked_0300_writes;
                            if (value == 0x1234) ++locked_0300_1234_writes;
                            if (value == 0x2468) ++locked_0300_2468_writes;
                            if (value == 0x5678) ++locked_0300_5678_writes;
                        } else {
                            ++locked_0300_reads;
                            if (value == 0x2468) ++locked_0300_2468_reads;
                        }
                    } else if (write) {
                        throw std::runtime_error("memory XCHG write completed without LOCK#");
                    } else {
                        ++unlocked_0300_reads;
                    }
                    if (!write && !dut.lock_n_o && !locked_hold_requested) {
                        dut.hold_i = 1;
                        locked_hold_requested = true;
                    }
                }
                if (address >= 0x0400 && address <= 0x0401) {
                    if (dut.lock_n_o)
                        throw std::runtime_error("REP LOCK MOVSB source read completed without LOCK#");
                    if (!write) ++locked_string_reads;
                } else if (address >= 0x0500 && address <= 0x0501) {
                    if (dut.lock_n_o)
                        throw std::runtime_error("REP LOCK MOVSB destination write completed without LOCK#");
                    if (write) ++locked_string_writes;
                }
                if (address >= 0x0410 && address <= 0x0411 && !io_transfer && !write) {
                    if (dut.lock_n_o)
                        throw std::runtime_error("REP LOCK OUTSB source read completed without LOCK#");
                    ++locked_outs_memory_reads;
                }
                if (address >= 0x0610 && address <= 0x0611 && !io_transfer && write) {
                    if (dut.lock_n_o)
                        throw std::runtime_error("REP LOCK INSB destination write completed without LOCK#");
                    ++locked_ins_memory_writes;
                }
                if (io_transfer && address == 0x0070 && !write) {
                    if (dut.lock_n_o || value != 0x00ab)
                        throw std::runtime_error("REP LOCK INSB port read lacked LOCK# or returned wrong data");
                    ++locked_io_reads;
                } else if (io_transfer && address == 0x0071 && write) {
                    if (dut.lock_n_o || (value != 0x5a00 && value != 0xc300) ||
                        dut.bhe_n_o)
                        throw std::runtime_error("REP LOCK OUTSB port write lacked LOCK# or wrong lane/data");
                    ++locked_io_writes;
                    if (value == 0x5a00) ++locked_io_5a_writes;
                    if (value == 0xc300) ++locked_io_c3_writes;
                }
                if (address == 0x0400 && !write && !string_hold_requested) {
                    dut.hold_i = 1;
                    string_hold_requested = true;
                }
                if (write && !io_transfer) {
                    if (bytes == 2) {
                        memory[address] = uint8_t(value);
                        memory[address + 1] = uint8_t(value >> 8);
                    } else if (address & 1) {
                        memory[address] = uint8_t(value >> 8);
                    } else {
                        memory[address] = uint8_t(value);
                    }
                }
            }

            if (dut.hlda_o && locked_hold_requested) {
                hold_released_after_lock = true;
                dut.hold_i = 0;
            }
            if (dut.hlda_o && string_hold_requested) {
                string_hold_released = true;
                dut.hold_i = 0;
            }

            one_processor_clock();
            if (saw_second_inta_tc) {
                dut.intr_i = 0;
                inta_pair_pending = false;
                saw_second_inta_tc = false;
            }
            ++cycles;
        }

        check(halt_cycles == 2, "CPU did not wake for INTR and return to HLT");
        check(reset_fetch_status_seen,
              "native CPU did not present its first reset-fetch status cycle");
        check(ale_observations != 0 && mrdc_observations != 0 &&
              mwtc_observations != 0 && iorc_observations != 0 &&
              iowc_observations != 0 && inta_observations != 0 &&
              mce_observations != 0 && den_observations != 0,
              "connected 82288 did not emit every exercised local-bus control signal");
        check(inta_ts_count == 2, "external INTR did not issue two INTA cycles");
        check(inta_lock.size() == 2 && inta_lock[0] && inta_lock[1],
              "LOCK# was not asserted across both INTA status phases");
        check(even_write_wait_cycles == 3 && odd_write_wait_cycles == 2,
              "native core writes did not survive the directed READY waits");
        check(locked_read_wait_cycles == 2 && locked_0300_reads == 5 &&
              locked_0300_writes == 4 && unlocked_0300_reads == 1,
              "LOCK MOV/ROL, explicit/implicit XCHG or unlocked MOV read mismatch");
        check(locked_0300_1234_writes == 2 && locked_0300_2468_writes == 1 &&
              locked_0300_5678_writes == 1 && locked_0300_2468_reads >= 2,
              "LOCK MOV store or rotate-memory result/data was incorrect");
        check(locked_io_reads == 2 && locked_io_writes == 2 &&
              locked_io_5a_writes == 1 && locked_io_c3_writes == 1 &&
              locked_ins_memory_writes == 2 && locked_outs_memory_reads == 2 &&
              locked_io_read_wait_cycles == 1 && locked_io_write_wait_cycles == 1,
              "REP LOCK INS/OUTS did not lock I/O and memory beats through READY waits");
        check(locked_idle_cycles != 0 && hold_released_after_lock,
              "HOLD did not remain blocked through the locked read/write gap and release afterward");
        check(locked_string_reads == 2 && locked_string_writes == 2 &&
              locked_string_idle_cycles != 0 && string_hold_released,
              "REP LOCK MOVSB did not retain LOCK across both iterations and HOLD gaps");
        check(!dut.protocol_error_o, "native CPU wrapper rejected a core beat");
        check(dut.halted_o && !dut.shutdown_o,
              "CPU did not finish in ordinary HLT after interrupt return");
        check(read_byte(0x0200) == 0x34 && read_byte(0x0201) == 0x68 &&
              read_byte(0x0202) == 0x24 && word_at(0x0300) == 0x5678 &&
              read_byte(0x0500) == 0x11 && read_byte(0x0501) == 0x22 &&
              read_byte(0x0610) == 0xab && read_byte(0x0611) == 0xab,
              "pin-level word stores/XCHG wrote wrong bytes");
        check(word_at(0x7ffa) == 0x0158 && word_at(0x7ffc) == 0xf000 &&
              (word_at(0x7ffe) & 0x0202) == 0x0202,
              "hardware interrupt frame has the wrong IP, CS or IF");

        bool even_write = false, even_read = false;
        bool odd_low_write = false, odd_high_write = false;
        bool odd_low_read = false, odd_high_read = false;
        unsigned ivt_word_reads = 0, frame_word_writes = 0, frame_word_reads = 0;
        std::vector<Transfer> esc_writes;
        for (const Transfer& transfer : transfers) {
            if (transfer.io && transfer.write &&
                (transfer.address == 0xf8 || transfer.address == 0xfc))
                esc_writes.push_back(transfer);
            if (transfer.address == 0x0200 && transfer.bytes == 2) {
                if (transfer.write) even_write = transfer.data == 0x1234;
                else even_read = transfer.data == 0x1234;
            }
            if (transfer.address == 0x0201 && transfer.bytes == 1) {
                if (transfer.write) odd_low_write = transfer.data == 0x6800;
                else odd_low_read = transfer.data == 0x6800;
            }
            if (transfer.address == 0x0202 && transfer.bytes == 1) {
                if (transfer.write) odd_high_write = transfer.data == 0x0024;
                else odd_high_read = transfer.data == 0x0024;
            }
            if ((transfer.address == 0x0080 || transfer.address == 0x0082) &&
                !transfer.write && transfer.bytes == 2)
                ++ivt_word_reads;
            if (transfer.address >= 0x7ffa && transfer.address <= 0x7ffe &&
                !(transfer.address & 1) && transfer.bytes == 2) {
                if (transfer.write) ++frame_word_writes;
                else ++frame_word_reads;
            }
        }
        check(even_write && even_read,
              "native CPU pins did not transfer an even word in one beat");
        check(odd_low_write && odd_high_write && odd_low_read && odd_high_read,
              "native CPU pins did not split the odd word onto correct lanes");
        check(ivt_word_reads == 2,
              "hardware event path did not read the IVT through native word beats");
        check(frame_word_writes == 3 && frame_word_reads == 3,
              "hardware event frame and IRET did not use three word beats each");
        check(esc_writes.size() == 3 && esc_writes[0].address == 0xf8 &&
              esc_writes[0].bytes == 2 && esc_writes[0].data == 0xf8d8 &&
              esc_writes[1].address == 0xfc && esc_writes[1].bytes == 2 &&
              esc_writes[1].data == 0x0100 && esc_writes[2].address == 0xfc &&
              esc_writes[2].bytes == 2 && esc_writes[2].data == 0xf000,
              "D8 register command and pointers did not use native word I/O beats");

        std::cout << "PASS: connected native CPU pins, HOLD/HLDA, even/odd words, "
                     "LOCK MOV/ROL/XCHG and REP MOVS/INS/OUTS, READY waits, two-cycle INTA, "
                     "interrupt frame and IRET\n";
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
    return 0;
}
