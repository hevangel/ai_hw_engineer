#include "Vintel_80286.h"
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
    uint16_t size;
    uint8_t beat_bytes;
    uint16_t data;
    bool write;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        Vintel_80286 dut;
        std::unordered_map<uint32_t, uint8_t> memory;
        std::vector<Transfer> transfers;
        auto put = [&](uint32_t address, std::initializer_list<uint8_t> bytes) {
            for (uint8_t byte : bytes) memory[address++] = byte;
        };
        auto read_byte = [&](uint32_t address) -> uint8_t {
            const auto found = memory.find(address);
            return found == memory.end() ? 0 : found->second;
        };

        // Reset far-jumps to a small authentic 8086 encoding sequence. It
        // stores and reloads words at both even and odd physical addresses.
        put(0xfffff0, {0xea, 0x00, 0x01, 0x00, 0xf0});
        put(0xf0100, {0xb8, 0x34, 0x12,       // MOV AX,1234h
                      0xa3, 0x00, 0x02,       // MOV [0200h],AX (one even word beat)
                      0xa1, 0x00, 0x02,       // MOV AX,[0200h]
                      0xa3, 0x01, 0x02,       // MOV [0201h],AX (two byte beats)
                      0xa1, 0x01, 0x02,       // MOV AX,[0201h]
                      0xbc, 0x00, 0x80,       // MOV SP,8000h
                      0xcd, 0x30,             // INT 30h: event owner pushes a frame
                      0xf4});                 // HLT
        put(0x00c0, {0x50, 0x01, 0x00, 0xf0}); // IVT vector 30h -> F000:0150
        put(0xf0150, {0xcf});                  // IRET returns to the exact HLT

        dut.clk = 0;
        dut.rst_n = 0;
        dut.bus_ready_i = 0;
        dut.bus_rdata_i = 0;
        dut.intr_i = 0;
        dut.nmi_i = 0;
        dut.busy_i = 0;
        dut.error_n_i = 1;
        dut.inta_ready_i = 0;
        dut.inta_vector_i = 0;
        dut.eval();
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
        dut.clk = 1; dut.eval();
        dut.rst_n = 1;

        unsigned cycles = 0;
        while (!dut.halted_o && cycles < 2000) {
            dut.clk = 0;
            dut.bus_ready_i = 0;
            dut.bus_rdata_i = 0;
            dut.eval();

            if (dut.bus_req_o) {
                const uint32_t address = dut.bus_addr_o;
                const uint16_t size = dut.bus_size_o;
                const uint8_t beat = dut.bus_beat_bytes_o;
                const bool write = dut.bus_write_o;
                check(beat == 1 || beat == 2, "core emitted an invalid beat size");
                check(!dut.bus_fetch_o || beat == 1, "instruction fetch was combined into a word beat");
                check(beat != 2 || ((address & 1) == 0 && size >= 2),
                      "two-byte beat was not even-addressed or exceeded remaining bytes");

                uint16_t lanes = 0;
                if (!write) {
                    if (beat == 2) {
                        lanes = uint16_t(read_byte(address)) |
                                (uint16_t(read_byte(address + 1)) << 8);
                    } else if (address & 1) {
                        lanes = uint16_t(read_byte(address)) << 8;
                    } else {
                        lanes = read_byte(address);
                    }
                }
                dut.bus_rdata_i = lanes;
                dut.bus_ready_i = 1;
                dut.eval();

                if (!dut.bus_fetch_o) {
                    const uint16_t write_data = dut.bus_wdata_o;
                    transfers.push_back({address, size, beat,
                                         write ? write_data : lanes, write});
                    if (write) {
                        if (beat == 2) {
                            memory[address] = uint8_t(write_data);
                            memory[address + 1] = uint8_t(write_data >> 8);
                        } else if (address & 1) {
                            memory[address] = uint8_t(write_data >> 8);
                        } else {
                            memory[address] = uint8_t(write_data);
                        }
                    }
                }
            }

            dut.clk = 1;
            dut.eval();
            ++cycles;
        }

        check(dut.halted_o, "core did not reach HLT");
        check((dut.regs_o[0] & 0xffff) == 0x1234, "word load returned the wrong AX value");
        check(read_byte(0x0200) == 0x34 && read_byte(0x0201) == 0x34 &&
              read_byte(0x0202) == 0x12, "word stores wrote incorrect byte order");
        auto word_at = [&](uint32_t address) -> uint16_t {
            return uint16_t(read_byte(address)) |
                   (uint16_t(read_byte(address + 1)) << 8);
        };
        check(word_at(0x7ffa) == 0x0114 && word_at(0x7ffc) == 0xf000 &&
              word_at(0x7ffe) == 0x0002, "event owner did not push the exact interrupt frame");

        bool even_write = false, even_read = false;
        bool odd_low_write = false, odd_high_write = false;
        bool odd_low_read = false, odd_high_read = false;
        bool event_vector_low = false, event_vector_high = false;
        bool event_frame_writes = true, event_frame_reads = true;
        unsigned event_frame_write_count = 0, event_frame_read_count = 0;
        for (const Transfer& transfer : transfers) {
            if (transfer.address == 0x0200 && transfer.beat_bytes == 2) {
                if (transfer.write) {
                    even_write = transfer.size == 2 && transfer.data == 0x1234;
                } else {
                    even_read = transfer.size == 2 && transfer.data == 0x1234;
                }
            }
            if (transfer.address == 0x0201 && transfer.beat_bytes == 1) {
                if (transfer.write) odd_low_write = transfer.size == 2 && transfer.data == 0x3400;
                else odd_low_read = transfer.size == 2 && transfer.data == 0x3400;
            }
            if (transfer.address == 0x0202 && transfer.beat_bytes == 1) {
                if (transfer.write) odd_high_write = transfer.size == 1 && transfer.data == 0x0012;
                else odd_high_read = transfer.size == 1 && transfer.data == 0x0012;
            }
            if (transfer.address == 0x00c0 && !transfer.write)
                event_vector_low = transfer.size == 4 && transfer.beat_bytes == 2 &&
                                   transfer.data == 0x0150;
            if (transfer.address == 0x00c2 && !transfer.write)
                event_vector_high = transfer.size == 2 && transfer.beat_bytes == 2 &&
                                    transfer.data == 0xf000;
            if (transfer.address >= 0x7ffa && transfer.address <= 0x7ffe &&
                !(transfer.address & 1)) {
                if (transfer.write) {
                    ++event_frame_write_count;
                    event_frame_writes &= transfer.size == 2 && transfer.beat_bytes == 2;
                } else {
                    ++event_frame_read_count;
                    const uint16_t remaining = static_cast<uint16_t>(0x8000 - transfer.address);
                    event_frame_reads &= transfer.size == remaining && transfer.beat_bytes == 2;
                }
            }
        }
        check(even_write && even_read, "even word did not use one two-byte beat");
        check(odd_low_write && odd_high_write && odd_low_read && odd_high_read,
              "odd word was not split into lane-correct one-byte beats");
        check(event_vector_low && event_vector_high,
              "event owner did not read the IVT as two even word beats");
        if (!(event_frame_writes && event_frame_reads && event_frame_write_count == 3 &&
              event_frame_read_count == 3)) {
            for (const Transfer& transfer : transfers) {
                if (transfer.address >= 0x7ff0 && transfer.address <= 0x8002) {
                    std::cerr << "frame transfer " << (transfer.write ? "W" : "R")
                              << " addr=" << std::hex << transfer.address
                              << " size=" << std::dec << transfer.size
                              << " beat=" << unsigned(transfer.beat_bytes)
                              << " data=" << std::hex << transfer.data << '\n';
                }
            }
        }
        check(event_frame_writes && event_frame_reads && event_frame_write_count == 3 &&
              event_frame_read_count == 3,
              "event owner did not push/read the interrupt frame as even word beats");

        std::cout << "PASS: native core CPU/event even-word beats, odd-word split, byte lanes, frame and exact data\n";
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
    return 0;
}
