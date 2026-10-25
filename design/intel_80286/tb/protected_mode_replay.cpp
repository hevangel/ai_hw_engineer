// Source-audited ring-0 protected-mode regression for the fixture in
// protected_mode_fixture.h. The fixture expectations are based on Intel
// 210498-005 and pinned 86Box 286 protected interrupt/IRET paths.
#include "Vintel_80286.h"
#include "protected_mode_fixture.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

namespace fixture = protected_mode_fixture;

struct Transfer {
    uint32_t address;
    uint8_t value;
    bool write;
};

struct BusSnapshot {
    bool request;
    uint32_t address;
    bool fetch;
    bool write;
    bool io;
    bool segmented;
    uint8_t segment;
    uint8_t kind;
    uint16_t offset;
    uint8_t size;
    uint8_t write_data;

    bool operator==(const BusSnapshot& other) const {
        return request == other.request && address == other.address &&
               fetch == other.fetch && write == other.write && io == other.io &&
               segmented == other.segmented && segment == other.segment &&
               kind == other.kind && offset == other.offset && size == other.size &&
               write_data == other.write_data;
    }
};

struct ResetCut {
    const char* label;
    uint32_t address;
    bool write;
    bool require_fault_packet;
    bool require_handler_entry;
    uint8_t value;
};

[[noreturn]] void fail(const std::string& message) {
    throw std::runtime_error(message);
}

uint16_t reg(const Vintel_80286& dut, unsigned index) {
    return static_cast<uint16_t>((dut.regs_o[index / 2] >> ((index % 2) * 16)) & 0xffffu);
}

uint16_t visible_cs(const Vintel_80286& dut) {
    return static_cast<uint16_t>((dut.segs_o >> 16) & 0xffffu);
}

uint16_t visible_ss(const Vintel_80286& dut) {
    return static_cast<uint16_t>((dut.segs_o >> 32) & 0xffffu);
}

uint16_t visible_ds(const Vintel_80286& dut) {
    return static_cast<uint16_t>((dut.segs_o >> 48) & 0xffffu);
}

uint16_t visible_es(const Vintel_80286& dut) {
    return static_cast<uint16_t>(dut.segs_o & 0xffffu);
}

uint32_t physical_pc(uint16_t cs, uint16_t ip) {
    if (cs == 0xf000 && ip == 0xfff0) return fixture::kResetVector;
    uint32_t base = 0;
    if (cs == 0xf000) base = fixture::kRealCodeBase;
    else if (cs == fixture::kCodeSelector) base = fixture::kCodeBase;
    else if (cs == fixture::kHandlerSelector) base = fixture::kHandlerBase;
    else fail("unexpected CS in expected PC trace");
    return (base + ip) & 0x00ffffffu;
}

template <size_t N>
void place(std::vector<uint8_t>& memory, uint32_t address, const uint8_t (&bytes)[N]) {
    if (address + N > memory.size()) fail("fixture image exceeds physical memory");
    std::copy(bytes, bytes + N, memory.begin() + address);
}

std::vector<uint8_t> initial_memory() {
    std::vector<uint8_t> memory(1u << 24, 0);
    place(memory, fixture::kResetVector, fixture::kResetJump);
    place(memory, fixture::kRealCodeBase + 0x0100, fixture::kRealModeProgram);
    place(memory, 0x00000040, fixture::kGdtrImage);
    place(memory, 0x00000046, fixture::kIdtrImage);
    place(memory, fixture::kGdtBase, fixture::kGdtImage);
    place(memory, fixture::kIdtBase + fixture::kFaultVector * 8, fixture::kVector13Gate);
    place(memory, fixture::kCodeBase + 0x0200, fixture::kProtectedProgram);
    place(memory, fixture::kHandlerBase + fixture::kHandlerIp, fixture::kVector13Handler);
    place(memory, fixture::kNarrowDataBase + 2, fixture::kNarrowDataSeed);
    place(memory, fixture::kWideDataBase + 0x000f, fixture::kWideRetryWord);
    return memory;
}

void compare_transfers(const std::vector<Transfer>& actual,
                       const fixture::ExpectedDataTransfer* expected,
                       size_t expected_count, const char* label) {
    if (actual.size() != expected_count) {
        std::ostringstream out;
        out << label << ": expected " << expected_count << " transfers, observed "
            << actual.size();
        fail(out.str());
    }
    for (size_t i = 0; i < expected_count; ++i) {
        if (actual[i].address != expected[i].address ||
            actual[i].value != expected[i].value ||
            actual[i].write != expected[i].write) {
            std::ostringstream out;
            out << label << ": transfer " << i << " was 0x" << std::hex
                << actual[i].address << (actual[i].write ? " write " : " read ")
                << static_cast<unsigned>(actual[i].value) << ", expected 0x"
                << expected[i].address << (expected[i].write ? " write " : " read ")
                << static_cast<unsigned>(expected[i].value);
            fail(out.str());
        }
    }
}

void compare_access_writes(const std::vector<Transfer>& actual) {
    const size_t count = sizeof(fixture::kAccessWrites) / sizeof(fixture::kAccessWrites[0]);
    if (actual.size() != count) fail("descriptor accessed-byte write count mismatch");
    for (size_t i = 0; i < count; ++i) {
        if (!actual[i].write || actual[i].address != fixture::kAccessWrites[i].address ||
            actual[i].value != fixture::kAccessWrites[i].value) {
            std::ostringstream out;
            out << "descriptor accessed-byte write " << i << " did not match fixture";
            fail(out.str());
        }
    }
}

void compare_frame_writes(const std::vector<Transfer>& actual) {
    const size_t count = sizeof(fixture::kFaultFrameWrites) /
                         sizeof(fixture::kFaultFrameWrites[0]);
    if (actual.size() < count) fail("protected exception frame is incomplete");
    for (size_t i = 0; i < count; ++i) {
        if (!actual[i].write ||
            actual[i].address != fixture::kFaultFrameWrites[i].address ||
            actual[i].value != fixture::kFaultFrameWrites[i].value) {
            std::ostringstream out;
            out << "protected exception frame byte " << i << " is out of order or wrong";
            fail(out.str());
        }
    }
}

std::vector<uint32_t> expected_descriptor_byte_reads() {
    std::vector<uint32_t> expected;
    const size_t count = sizeof(fixture::kDescriptorReads) /
                         sizeof(fixture::kDescriptorReads[0]);
    for (size_t i = 0; i < count; ++i) {
        for (unsigned byte = 0; byte < fixture::kDescriptorReads[i].length; ++byte)
            expected.push_back(fixture::kDescriptorReads[i].address + byte);
    }
    return expected;
}

void run_fixture(bool insert_waits, const ResetCut* reset_cut = nullptr) {
    auto memory = initial_memory();
    VerilatedContext context;
    Vintel_80286 dut(&context);
    dut.clk = 0;
    dut.rst_n = 0;
    dut.bus_ready_i = 1;
    dut.bus_rdata_i = 0;
    dut.intr_i = 0;
    dut.nmi_i = 0;
    dut.inta_ready_i = 1;
    dut.inta_vector_i = 0;

    for (unsigned i = 0; i < 3; ++i) {
        dut.clk = 0;
        dut.eval();
        dut.clk = 1;
        dut.eval();
        context.timeInc(1);
    }
    dut.clk = 0;
    dut.rst_n = 1;

    std::vector<fixture::ExpectedPc> expected_pc;
    const size_t pc_count = sizeof(fixture::kPcTrace) / sizeof(fixture::kPcTrace[0]);
    for (size_t i = 0; i < pc_count; ++i) {
        const auto& item = fixture::kPcTrace[i];
        const bool fault_entry = item.cs == fixture::kCodeSelector &&
            item.ip == fixture::kFaultIp && item.next_cs == fixture::kHandlerSelector;
        if (!fault_entry) expected_pc.push_back(item);
    }

    std::vector<uint32_t> descriptor_reads;
    std::vector<Transfer> access_writes;
    std::vector<Transfer> frame_writes;
    std::vector<Transfer> ordinary_before_fault;
    std::vector<Transfer> retry_reads;
    std::vector<uint32_t> actual_retire_pc;
    bool saw_fault_packet = false;
    bool saw_handler_entry = false;
    bool saw_expected_packet = false;
    bool saw_stalled_request = false;
    bool reset_cut_taken = false;
    bool reset_pending = false;
    BusSnapshot stalled_snapshot{};

    constexpr unsigned kCycleLimit = 50000;
    unsigned cycles = 0;
    for (; cycles < kCycleLimit && !dut.halted_o; ++cycles) {
        if (reset_pending) {
            for (unsigned edge = 0; edge < 2; ++edge) {
                dut.clk = 0;
                dut.rst_n = 0;
                dut.bus_ready_i = 1;
                dut.bus_rdata_i = 0;
                dut.eval();
                dut.clk = 1;
                dut.eval();
                context.timeInc(1);
            }
            dut.clk = 0;
            dut.rst_n = 1;
            dut.eval();

            descriptor_reads.clear();
            access_writes.clear();
            frame_writes.clear();
            ordinary_before_fault.clear();
            retry_reads.clear();
            actual_retire_pc.clear();
            saw_fault_packet = false;
            saw_handler_entry = false;
            saw_expected_packet = false;
            saw_stalled_request = false;
            reset_pending = false;
            continue;
        }

        dut.clk = 0;
        dut.eval();

        const bool request = dut.bus_req_o != 0;
        const uint32_t address = dut.bus_addr_o & 0x00ffffffu;
        const bool write = dut.bus_write_o != 0;
        const bool ready = !request || !insert_waits || ((cycles % 4) != 1);
        dut.bus_ready_i = ready;
        dut.bus_rdata_i = request && !write ? memory[address] : 0;
        dut.eval();

        BusSnapshot bus{
            dut.bus_req_o != 0,
            static_cast<uint32_t>(dut.bus_addr_o & 0x00ffffffu),
            dut.bus_fetch_o != 0,
            dut.bus_write_o != 0,
            dut.bus_io_o != 0,
            dut.bus_segmented_o != 0,
            static_cast<uint8_t>(dut.bus_segment_o),
            static_cast<uint8_t>(dut.bus_kind_o),
            static_cast<uint16_t>(dut.bus_offset_o),
            static_cast<uint8_t>(dut.bus_size_o),
            static_cast<uint8_t>(dut.bus_wdata_o)
        };

        if (saw_stalled_request && (!(bus == stalled_snapshot) || !bus.request))
            fail("bus request fields changed while READY was stalled");

        const bool accepted = bus.request && ready;
        const uint8_t accepted_data = bus.write_data;
        bool cut_this_transfer = false;
        if (accepted) {
            if (!bus.write && ((bus.address >= fixture::kGdtBase &&
                                bus.address < fixture::kGdtBase + sizeof(fixture::kGdtImage)) ||
                               (bus.address >= fixture::kIdtBase + fixture::kFaultVector * 8 &&
                                bus.address < fixture::kIdtBase + fixture::kFaultVector * 8 + 8)))
                descriptor_reads.push_back(bus.address);

            if (bus.write && bus.address >= fixture::kGdtBase &&
                bus.address < fixture::kGdtBase + sizeof(fixture::kGdtImage))
                access_writes.push_back({bus.address, accepted_data, true});

            if (bus.write && saw_fault_packet && !saw_handler_entry &&
                bus.address >= fixture::kStackBase + 0x0078 &&
                bus.address <= fixture::kStackBase + 0x007f)
                frame_writes.push_back({bus.address, accepted_data, true});

            if (!saw_fault_packet &&
                ((bus.address >= fixture::kNarrowDataBase + 2 &&
                  bus.address <= fixture::kNarrowDataBase + 5) ||
                 (bus.address >= fixture::kEsDataBase + 6 &&
                  bus.address <= fixture::kEsDataBase + 7) ||
                 (bus.address >= fixture::kStackBase + 0x007e &&
                  bus.address <= fixture::kStackBase + 0x007f)))
                ordinary_before_fault.push_back({bus.address,
                    bus.write ? accepted_data : dut.bus_rdata_i, bus.write});

            if (saw_fault_packet && !bus.write &&
                (bus.address == fixture::kRetryReadFirst ||
                 bus.address == fixture::kRetryReadLast))
                retry_reads.push_back({bus.address, dut.bus_rdata_i, false});

            if (reset_cut && !reset_cut_taken && bus.address == reset_cut->address &&
                bus.write == reset_cut->write &&
                (!reset_cut->require_fault_packet || saw_fault_packet) &&
                (!reset_cut->require_handler_entry || saw_handler_entry) &&
                (!reset_cut->write || reset_cut->value == 0xff ||
                 accepted_data == reset_cut->value)) {
                reset_cut_taken = true;
                cut_this_transfer = true;
            }
        }

        if (bus.request && !ready) {
            saw_stalled_request = true;
            stalled_snapshot = bus;
        } else {
            saw_stalled_request = false;
        }

        dut.clk = 1;
        dut.eval();
        if (accepted && bus.write) memory[bus.address] = accepted_data;
        if (cut_this_transfer) {
            if (bus.write && memory[bus.address] != accepted_data)
                fail("reset cut rolled back an accepted external write");
            reset_pending = true;
        }

        if (accepted && (bus.address == fixture::kDeniedReadFirst ||
                         bus.address == fixture::kDeniedReadLast))
            fail("denied DS limit read issued an operand transaction");

        if (dut.event_packet_valid_o && dut.event_packet_protected_o &&
            !saw_expected_packet) {
            saw_fault_packet = true;
            saw_expected_packet = true;
            if (dut.event_vector_o != fixture::kFaultVector ||
                !dut.event_packet_error_valid_o ||
                dut.event_packet_error_code_o != fixture::kFaultError ||
                !dut.event_packet_restartable_o ||
                dut.event_packet_saved_cs_o != fixture::kCodeSelector ||
                dut.event_packet_saved_ip_o != fixture::kFaultIp ||
                dut.event_packet_saved_flags_o != fixture::kSavedFlags ||
                dut.event_packet_saved_sp_o != fixture::kInitialSp)
                fail("protected #GP packet differs from Intel-backed fixture");
            if (reg(dut, 0) != fixture::kAxAtHandler)
                fail("AX changed before protected fault delivery");
        }

        if (dut.event_o) {
            saw_handler_entry = true;
            if (visible_cs(dut) != fixture::kHandlerSelector ||
                dut.ip_o != fixture::kHandlerIp || reg(dut, 4) != 0x0078 ||
                dut.flags_o != fixture::kLiveFlagsAtHandler ||
                reg(dut, 0) != fixture::kAxAtHandler)
                fail("protected event did not publish the expected handler state");
        }

        if (dut.retire_o) {
            const size_t index = actual_retire_pc.size();
            if (index >= expected_pc.size()) fail("unexpected extra instruction retirement");
            const auto& item = expected_pc[index];
            const uint32_t expected_physical = physical_pc(item.cs, item.ip);
            if (dut.retire_pc_o != expected_physical) {
                std::ostringstream out;
                out << "retirement " << index << " landed at 0x" << std::hex
                    << dut.retire_pc_o << ", expected 0x" << expected_physical;
                fail(out.str());
            }
            if (visible_cs(dut) != item.next_cs || dut.ip_o != item.next_ip) {
                std::ostringstream out;
                out << "retirement " << index << " has wrong successor CS:IP ("
                    << std::hex << visible_cs(dut) << ':' << dut.ip_o << ")";
                fail(out.str());
            }
            actual_retire_pc.push_back(dut.retire_pc_o);
        }

        context.timeInc(1);
    }

    if (cycles == kCycleLimit) fail("protected fixture did not reach HLT");
    if (reset_cut && !reset_cut_taken) fail("requested protected reset cut was not reached");
    if (dut.fault_o) fail("CPU stopped instead of completing protected recovery");
    if (!saw_fault_packet || !saw_expected_packet || !saw_handler_entry)
        fail("protected vector-13 event path was not observed");
    if (actual_retire_pc.size() != expected_pc.size())
        fail("instruction retirement trace ended before the exact HLT successor");
    if (!dut.halted_o || visible_cs(dut) != fixture::kCodeSelector ||
        dut.ip_o != 0x0227 || reg(dut, 0) != fixture::kAxAfterRetry ||
        reg(dut, 3) != fixture::kBxAfterStackRoundTrip ||
        reg(dut, 4) != fixture::kInitialSp || reg(dut, 5) != fixture::kBpAfterSuccessor ||
        visible_ds(dut) != fixture::kWideDataSelector ||
        visible_es(dut) != fixture::kEsSelector || visible_ss(dut) != fixture::kSsSelector ||
        !(dut.msw_o & 1))
        fail("final protected retry/checkpoint state differs from fixture");

    compare_transfers(ordinary_before_fault, fixture::kDataTransfersBeforeFault,
        sizeof(fixture::kDataTransfersBeforeFault) / sizeof(fixture::kDataTransfersBeforeFault[0]),
        "pre-fault ordinary data");
    compare_transfers(retry_reads, fixture::kDataTransfersOnRetry,
        sizeof(fixture::kDataTransfersOnRetry) / sizeof(fixture::kDataTransfersOnRetry[0]),
        "faulting-instruction retry data");
    compare_access_writes(access_writes);
    compare_frame_writes(frame_writes);

    const auto expected_reads = expected_descriptor_byte_reads();
    if (descriptor_reads != expected_reads)
        fail("descriptor/gate byte-read order differs from fixture");

    if (reset_cut) {
        std::printf("PASS: reset cut after %s, then exact protected recovery%s\n",
            reset_cut->label, insert_waits ? " with READY stalls" : " without stalls");
    } else {
        std::printf("PASS: protected #GP, exact PC trace, descriptor/frame transactions, IRET retry%s\n",
            insert_waits ? " with READY stalls" : " without stalls");
    }
}

// Intel 210498-005 sections 4.1 and 7.4 define ES:DI, element updates and
// segment protection. Native fault-time DI/CX and handler repair follow Intel's
// LOADALL memo page 14 and its 1984-10-15 REP restartability correction:
// https://docs.pcjs.org/manuals/intel/80286/80286_LOADALL.pdf
// https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_REP-1984-10-15.pdf
// This fixture selects the corrected post-C2 count behavior, not C2 errata.
// A20's port-side-effect ordering remains a project assumption, not a claim
// that the manufacturer specifies the native bus-cycle order.
void run_ins_limit_fixture(bool word, bool repeat, bool insert_waits,
                           bool wrap=false, unsigned initial_count=2) {
    auto memory = initial_memory();
    memory[fixture::kRealCodeBase + 0x010b] = 0xfc; // CLD, saved FLAGS=0203.
    memory[fixture::kGdtBase + 0x20] = 0x0f;       // ES limit=000F.
    memory[fixture::kHandlerBase + 0x0308] = 0xc0; // Handler repairs ES, not DS.
    const uint16_t initial_di = wrap ? 0xffff : (repeat ? 0x000d : (word ? 0x000f : 0x0010));
    const unsigned width = word ? 2 : 1;
    const unsigned completed_before_fault = repeat ? 1 : 0;
    const uint16_t fault_di = repeat ? 0x000f : initial_di;
    const uint16_t retry_di = wrap ? 0x000f : fault_di;
    const unsigned remaining = repeat ? initial_count-1 : 1;
    const unsigned total_elements = completed_before_fault+remaining;
    constexpr uint16_t fault_ip = 0x0219;
    const uint16_t successor_ip = repeat ? 0x021c : 0x021b;
    const uint8_t setup[] = {
        0xb8,0x20,0x00, 0x8e,0xc0, // 0200 MOV AX,0020; MOV ES,AX
        0xb8,0x28,0x00, 0x8e,0xd0, // 0205 MOV AX,0028; MOV SS,AX
        0xbc,0x80,0x00,             // 020A MOV SP,0080
        0xbf,static_cast<uint8_t>(initial_di),static_cast<uint8_t>(initial_di>>8),
        0xba,0x34,0x12,             // 0210 MOV DX,1234
        0xb9,static_cast<uint8_t>(initial_count),0x00, // 0213 MOV CX,count
        0xb8,0xfe,0xca              // 0216 MOV AX,CAFE
    };
    const uint8_t handler_program[] = {
        0x83,0xc4,0x02, // 0300 discard error code
        0x50,           // 0303 preserve AX
        0xb8,0x10,0x00, // 0304 wider ES descriptor
        0x8e,0xc0,      // 0307 MOV ES,AX
        0x58,           // 0309 restore AX
        0x83,0xef,static_cast<uint8_t>(width) // 030A undo failed INS DI update
    };
    place(memory, fixture::kHandlerBase + 0x0300, handler_program);
    if (repeat) {
        const uint8_t repair_count[] = {0x83,0xc1,0x02,0xcf}; // 030D ADD CX,2; IRET
        place(memory, fixture::kHandlerBase + 0x030d, repair_count);
    } else if (wrap) {
        // A wrapping word cannot be retried at FFFF even with a wider ES.
        // Explicitly relocate DI after checking/undoing its native fault update.
        const uint8_t relocate[] = {0xbf,0x0f,0x00,0xcf};
        place(memory, fixture::kHandlerBase + 0x030d, relocate);
    } else memory[fixture::kHandlerBase + 0x030d] = 0xcf;
    place(memory, fixture::kCodeBase + 0x0200, setup);
    // DS override must not redirect the INS destination away from ES.
    std::vector<uint8_t> tail{0x3e};
    if (repeat) tail.push_back(0xf3);
    tail.push_back(word ? 0x6d : 0x6c);
    tail.push_back(0x45); // Exact successor INC BP.
    tail.push_back(0xf4);
    std::copy(tail.begin(), tail.end(), memory.begin() + fixture::kCodeBase + fault_ip);

    std::vector<fixture::ExpectedPc> trace(fixture::kPcTrace, fixture::kPcTrace + 10);
    const uint16_t setup_ips[] = {
        0x0200,0x0203,0x0205,0x0208,0x020a,0x020d,0x0210,0x0213,0x0216,0x0219
    };
    for (unsigned i=0; i<9; ++i)
        trace.push_back({fixture::kCodeSelector, setup_ips[i],
                         fixture::kCodeSelector, setup_ips[i+1]});
    const uint16_t handler_ips[] = {0x0300,0x0303,0x0304,0x0307,0x0309,0x030a};
    for (unsigned i=0; i<5; ++i)
        trace.push_back({fixture::kHandlerSelector, handler_ips[i],
                         fixture::kHandlerSelector, handler_ips[i+1]});
    trace.push_back({fixture::kHandlerSelector,0x030a,fixture::kHandlerSelector,0x030d});
    if (repeat || wrap) trace.push_back({fixture::kHandlerSelector,0x030d,fixture::kHandlerSelector,0x0310});
    trace.push_back({fixture::kHandlerSelector,static_cast<uint16_t>(repeat || wrap ? 0x0310 : 0x030d),
                     fixture::kCodeSelector,fault_ip});
    trace.push_back({fixture::kCodeSelector,fault_ip,fixture::kCodeSelector,successor_ip});
    trace.push_back({fixture::kCodeSelector,successor_ip,fixture::kCodeSelector,
                     static_cast<uint16_t>(successor_ip+1)});
    trace.push_back({fixture::kCodeSelector,static_cast<uint16_t>(successor_ip+1),
                     fixture::kCodeSelector,static_cast<uint16_t>(successor_ip+2)});

    VerilatedContext context;
    Vintel_80286 dut(&context);
    dut.clk=0; dut.rst_n=0; dut.bus_ready_i=1; dut.bus_rdata_i=0;
    dut.intr_i=0; dut.nmi_i=0; dut.inta_ready_i=1; dut.inta_vector_i=0;
    for (unsigned i=0; i<3; ++i) {
        dut.clk=0; dut.eval(); dut.clk=1; dut.eval(); context.timeInc(1);
    }
    dut.clk=0; dut.rst_n=1;
    bool packet=false, handler=false, stalled=false, io_stall=false, destination_stall=false;
    unsigned inputs=0, retired=0, elements=0;
    BusSnapshot previous{};
    std::vector<Transfer> writes;
    std::vector<Transfer> frame;
    unsigned cycles=0;
    for (; cycles<50000 && !dut.halted_o; ++cycles) {
        dut.clk=0; dut.eval();
        const uint32_t address=dut.bus_addr_o & 0xffffffu;
        // Stall the first cycle of every byte request, including I/O beats.
        const bool ready=!insert_waits || !dut.bus_req_o || stalled;
        dut.bus_ready_i=ready;
        dut.bus_rdata_i=dut.bus_io_o ? static_cast<uint8_t>(0x50+inputs) : memory[address];
        dut.eval();
        BusSnapshot bus{dut.bus_req_o!=0, address, dut.bus_fetch_o!=0,
            dut.bus_write_o!=0, dut.bus_io_o!=0, dut.bus_segmented_o!=0,
            static_cast<uint8_t>(dut.bus_segment_o),static_cast<uint8_t>(dut.bus_kind_o),
            static_cast<uint16_t>(dut.bus_offset_o),static_cast<uint8_t>(dut.bus_size_o),
            static_cast<uint8_t>(dut.bus_wdata_o)};
        if (stalled && !(bus==previous)) fail("INS bus changed during READY stall");
        const bool destination=(bus.address>=fixture::kEsDataBase &&
            bus.address<fixture::kEsDataBase+0x100) ||
            (bus.address>=fixture::kWideDataBase && bus.address<fixture::kWideDataBase+0x100);
        if (bus.request && !bus.io && destination && (!bus.write || bus.fetch))
            fail("INS issued an unexpected destination read");
        if (bus.request && !ready) {
            io_stall=io_stall || bus.io;
            destination_stall=destination_stall || (!bus.io && destination);
        }
        if (bus.request && bus.io) {
            if (bus.write || bus.fetch || bus.segmented || bus.size!=width ||
                bus.address!=0x1234+(inputs%width)) fail("INS input-port request malformed");
            if (!handler && inputs>=completed_before_fault*width)
                fail("denied INS consumed input before ES repair (A20)");
        }
        if (bus.request && ready) {
            if (bus.io) ++inputs;
            if (bus.write && !bus.io) {
                memory[bus.address]=bus.write_data;
                if (destination) {
                    if (!bus.segmented || bus.segment!=0 || bus.kind!=1 || bus.size!=width)
                        fail("INS write did not use the ES destination");
                    writes.push_back({bus.address,bus.write_data,true});
                }
                if (packet && !handler && bus.address>=fixture::kStackBase+0x78 &&
                    bus.address<=fixture::kStackBase+0x7f)
                    frame.push_back({bus.address,bus.write_data,true});
            }
        }
        stalled=bus.request && !ready; previous=bus;
        dut.clk=1; dut.eval(); context.timeInc(1);
        if (dut.fault_o) fail("INS recovery stopped the CPU");
        if (dut.element_o) ++elements;
        if (dut.event_packet_valid_o && !packet) {
            packet=true;
            if (!dut.event_packet_protected_o || dut.event_vector_o!=13 ||
                !dut.event_packet_error_valid_o || dut.event_packet_error_code_o!=0 ||
                !dut.event_packet_restartable_o || dut.event_packet_saved_cs_o!=8 ||
                dut.event_packet_saved_ip_o!=fault_ip || dut.event_packet_saved_flags_o!=0x0203 ||
                dut.event_packet_saved_sp_o!=0x80 || dut.event_packet_deferred_valid_o ||
                reg(dut,0)!=0xcafe || reg(dut,7)!=static_cast<uint16_t>(fault_di+width) ||
                reg(dut,1)!=(repeat ? static_cast<uint16_t>(initial_count-3) : initial_count) || reg(dut,5)!=0 ||
                inputs!=completed_before_fault*width || writes.size()!=inputs ||
                elements!=completed_before_fault)
                fail("INS fault packet or completed-element state is imprecise");
        }
        if (dut.event_o) {
            if (handler || !packet || visible_cs(dut)!=fixture::kHandlerSelector ||
                dut.ip_o!=0x0300 || reg(dut,4)!=0x78 || dut.flags_o!=0x0003 ||
                visible_es(dut)!=fixture::kEsSelector)
                fail("INS handler entry differs from the expected protected state");
            handler=true;
        }
        if (dut.retire_o) {
            if (retired>=trace.size()) fail("extra INS fixture retirement");
            const auto& expected=trace[retired++];
            if (dut.retire_pc_o!=physical_pc(expected.cs,expected.ip) ||
                visible_cs(dut)!=expected.next_cs || dut.ip_o!=expected.next_ip)
                fail("INS fixture retired PC or exact successor mismatch");
        }
    }
    if (cycles==50000 || !packet || !handler || retired!=trace.size() ||
        inputs!=total_elements*width || writes.size()!=inputs ||
        elements!=total_elements || reg(dut,7)!=retry_di+remaining*width ||
        reg(dut,1)!=(repeat ? 0 : initial_count) || reg(dut,0)!=0xcafe || reg(dut,5)!=1 ||
        reg(dut,4)!=0x80 || visible_es(dut)!=fixture::kWideDataSelector ||
        (insert_waits && (!io_stall || !destination_stall)))
        fail("INS final recovery checkpoint mismatch");
    for (unsigned i=0; i<writes.size(); ++i) {
        const bool before=i<completed_before_fault*width;
        const uint32_t expected_address=before ? fixture::kEsDataBase+initial_di+i :
            fixture::kWideDataBase+retry_di+i-completed_before_fault*width;
        if (writes[i].address!=expected_address || writes[i].value!=0x50+i)
            fail("INS destination bytes or consumed-input order mismatch");
    }
    const fixture::ExpectedDataTransfer expected_frame[] = {
        {fixture::kStackBase+0x7e,0x03,true},{fixture::kStackBase+0x7f,0x02,true},
        {fixture::kStackBase+0x7c,0x08,true},{fixture::kStackBase+0x7d,0x00,true},
        {fixture::kStackBase+0x7a,0x19,true},{fixture::kStackBase+0x7b,0x02,true},
        {fixture::kStackBase+0x78,0x00,true},{fixture::kStackBase+0x79,0x00,true}
    };
    compare_transfers(frame,expected_frame,8,"INS protected fault frame");
    std::printf("PASS: %s%s%s ES limit fault, native DI/CX, handler repair, exact IRET retry%s\n",
        repeat ? "REP " : "",word ? "INSW" : "INSB",
        wrap ? " 64K-wrap" : (repeat && initial_count==3 ? " nonfinal-element" : ""),
        insert_waits ? " with READY stalls" : " without stalls");
}

#include "protected_string_replay.h"

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        run_fixture(false);
        run_fixture(true);
        const ResetCut cuts[] = {
            {"handler code descriptor read", fixture::kGdtBase + 0x30,
             false, true, false, 0xff},
            {"first protected frame byte", fixture::kStackBase + 0x007e,
             true, true, false, 0x03},
            {"IRET CS accessed-byte write", fixture::kGdtBase + 0x0d,
             true, true, true, 0x9b},
        };
        run_fixture(true, &cuts[0]);
        run_fixture(false, &cuts[1]);
        run_fixture(true, &cuts[2]);
        for (bool waits : {false,true}) {
            run_ins_limit_fixture(false,false,waits);
            run_ins_limit_fixture(true,false,waits);
            run_ins_limit_fixture(true,true,waits);
            run_ins_limit_fixture(true,false,waits,true);
            run_ins_limit_fixture(true,true,waits,false,3);
            for (auto kind : {StringFaultKind::MoveSource,StringFaultKind::MoveDestination,
                              StringFaultKind::Store,StringFaultKind::Output}) {
                run_string_fault_fixture(kind,true,true,waits);
                run_string_fault_fixture(kind,true,true,waits,false,3);
                run_string_fault_fixture(kind,false,true,waits);
                run_string_fault_fixture(kind,true,false,waits,true);
                run_string_fault_fixture(kind,true,false,waits,false,2,true);
            }
        }
    } catch (const std::exception& error) {
        std::fprintf(stderr, "FAIL: %s\n", error.what());
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
