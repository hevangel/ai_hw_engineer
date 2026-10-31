#include "Vintel_80286_native_bus.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

static void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

struct Bench {
    Vintel_80286_native_bus d;

    Bench() {
        d.clk_i=0; d.reset_i=1; d.req_i=0; d.fetch_i=0; d.write_i=0; d.io_i=0;
        d.address_i=0; d.beat_bytes_i=0; d.write_data_i=0;
        d.ready_n_i=1; d.hold_i=0; d.lock_i=0; d.inta_req_i=0;
        d.halt_i=0; d.shutdown_i=0; d.data_i=0;
        d.eval(); cycle(); d.reset_i=0; d.eval();
        check(!d.cycle_active_o && !d.hlda_o && !d.core_ready_o,
              "reset did not leave bus in Ti");
    }

    void cycle() {
        d.clk_i=0; d.eval(); d.clk_i=1; d.eval(); d.clk_i=0; d.eval();
    }

    void start(bool fetch, bool write, bool io, uint32_t address,
               unsigned bytes, uint16_t data=0) {
        d.req_i=1; d.fetch_i=fetch; d.write_i=write; d.io_i=io;
        d.address_i=address; d.beat_bytes_i=bytes; d.write_data_i=data;
        d.eval();
        check(!d.protocol_error_o, "valid beat raised protocol error");
        cycle();
        check(d.status_valid_o && d.address_oe_o && d.cycle_active_o,
              "request did not enter Ts");
        check(d.address_o==address, "Ts address mismatch");
    }

    void enter_tc() {
        cycle();
        check(!d.status_valid_o && d.address_oe_o && d.cycle_active_o,
              "Ts did not transition to Tc");
    }

    void finish_read(uint16_t pins, uint16_t expected, unsigned bytes) {
        d.data_i=pins; d.ready_n_i=0; d.eval();
        check(d.core_ready_o && d.completed_bytes_o==bytes,
              "READY# did not complete the expected byte beat");
        check(d.read_data_o==expected, "read lanes were not routed correctly");
        cycle();
        check(!d.cycle_active_o && !d.core_ready_o,
              "completed beat did not return to Ti");
        d.req_i=0; d.ready_n_i=1; d.eval(); cycle();
    }

    void finish_write(unsigned bytes) {
        d.ready_n_i=0; d.eval();
        check(d.core_ready_o && d.completed_bytes_o==bytes,
              "READY# did not complete the write beat");
        cycle();
        check(!d.cycle_active_o && !d.core_ready_o,
              "completed write did not return to Ti");
        d.req_i=0; d.ready_n_i=1; d.eval(); cycle();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Bench b;

        // An even word uses both lanes in one physical beat and holds the
        // address/status class through arbitrary READY# wait states.
        b.start(false,false,false,0x001200,2);
        check(b.d.cod_inta_o==0 && b.d.m_io_o==1 && b.d.s1_o==0 && b.d.s0_o==1,
              "memory-read status tuple mismatch");
        check(b.d.bhe_n_o==0, "even word did not select both lanes");
        b.enter_tc();
        b.cycle();
        check(!b.d.core_ready_o && b.d.address_o==0x001200 && b.d.bhe_n_o==0,
              "READY# wait changed the active read beat");
        b.finish_read(0xbeef,0xbeef,2);

        // Instruction, I/O, and data status tuples are distinct.
        b.start(true,false,false,0x00ffff,1);
        check(b.d.cod_inta_o==1 && b.d.m_io_o==1 && b.d.s1_o==0 && b.d.s0_o==1,
              "instruction-fetch status tuple mismatch");
        check(b.d.bhe_n_o==0, "odd-address byte did not select the upper lane");
        b.enter_tc();
        b.finish_read(0x5a00,0x5a00,1);

        b.start(false,false,true,0x000020,1);
        check(b.d.cod_inta_o==1 && b.d.m_io_o==0 && b.d.s1_o==0 && b.d.s0_o==1,
              "I/O-read status tuple mismatch");
        check(b.d.bhe_n_o==1, "even byte read did not select the lower lane");
        b.enter_tc();
        b.finish_read(0x003c,0x003c,1);

        // A byte write on an odd address drives D15:D8; a word write drives
        // both data lanes and remains stable until READY# terminates Tc.
        b.start(false,true,false,0x000101,1,0xa700);
        check(b.d.cod_inta_o==0 && b.d.m_io_o==1 && b.d.s1_o==1 && b.d.s0_o==0,
              "memory-write status tuple mismatch");
        check(b.d.bhe_n_o==0, "odd byte write selected the wrong lane");
        b.enter_tc();
        check(b.d.data_oe_o && b.d.data_o==0xa700,
              "odd byte write data was not driven on D15:D8");
        b.cycle();
        check(b.d.data_oe_o && b.d.data_o==0xa700,
              "write data changed during READY# wait");
        b.finish_write(1);

        b.start(false,true,false,0x002000,2,0xcafe);
        check(b.d.bhe_n_o==0, "word write did not select both lanes");
        b.enter_tc();
        check(b.d.data_oe_o && b.d.data_o==0xcafe,
              "word write did not drive both data lanes");
        b.finish_write(2);

        b.start(false,true,true,0x000021,1,0x0055);
        check(b.d.cod_inta_o==1 && b.d.m_io_o==0 && b.d.s1_o==1 && b.d.s0_o==0,
              "I/O-write status tuple mismatch");
        check(b.d.bhe_n_o==0, "odd I/O byte write did not select the upper lane");
        b.enter_tc();
        b.finish_write(1);

        // HOLD is acknowledged only in Th, and all CPU bus drivers release.
        b.d.hold_i=1; b.d.eval(); b.cycle();
        check(b.d.hlda_o && !b.d.address_oe_o && !b.d.status_oe_o &&
              !b.d.data_oe_o && !b.d.lock_oe_o,
              "Th did not release the local bus");
        b.d.req_i=1; b.d.address_i=0x004000; b.d.beat_bytes_i=1;
        b.d.write_i=0; b.d.fetch_i=0; b.d.io_i=0; b.d.eval(); b.cycle();
        check(b.d.hlda_o && !b.d.cycle_active_o && !b.d.core_ready_o,
              "CPU started a cycle while HLDA was asserted");
        b.d.hold_i=0; b.d.eval(); b.cycle();
        check(!b.d.hlda_o && !b.d.cycle_active_o,
              "bus ownership return skipped Ti");
        b.cycle();
        check(b.d.status_valid_o && b.d.address_o==0x004000,
              "pending request did not resume after HOLD");
        b.enter_tc();
        b.finish_read(0x0066,0x0066,1);

        // LOCK prevents HOLD grant. INTA runs as two locked acknowledge cycles
        // and samples the vector only at the end of the second Tc.
        b.d.lock_i=1; b.d.hold_i=1; b.d.eval(); b.cycle();
        check(!b.d.hlda_o && !b.d.lock_n_o,
              "HOLD was granted while the resource was locked");
        b.d.hold_i=0; b.d.lock_i=0; b.d.inta_req_i=1; b.d.eval(); b.cycle();
        check(b.d.status_valid_o && b.d.cod_inta_o==0 && b.d.m_io_o==0 &&
              b.d.s1_o==0 && b.d.s0_o==0 && !b.d.lock_n_o,
              "first INTA status or LOCK# mismatch");
        b.enter_tc();
        b.d.ready_n_i=0; b.d.eval(); b.cycle();
        check(b.d.status_valid_o && !b.d.lock_n_o && !b.d.inta_ready_o,
              "first INTA did not continue directly to the second cycle");
        b.enter_tc();
        b.d.ready_n_i=1; b.d.eval(); b.cycle();
        check(!b.d.inta_ready_o && !b.d.lock_n_o,
              "second INTA ignored READY# wait");
        b.d.data_i=0x0021; b.d.ready_n_i=0; b.d.eval(); b.cycle();
        check(b.d.inta_ready_o && b.d.inta_vector_o==0x21 && b.d.lock_n_o,
              "second INTA did not capture the vector");
        b.d.ready_n_i=1; b.d.eval(); b.cycle();
        check(!b.d.cycle_active_o && !b.d.inta_ready_o,
              "INTA did not return to Ti after its completion pulse");
        b.d.inta_req_i=0; b.d.eval(); b.cycle(); b.cycle();
        check(!b.d.cycle_active_o, "completed INTA request was replayed");

        // HLT and shutdown share status but A1 distinguishes them; a held
        // indication emits one status cycle until the indication drops.
        b.d.halt_i=1; b.d.eval(); b.cycle();
        check(b.d.status_valid_o && b.d.address_o==2 &&
              b.d.cod_inta_o==0 && b.d.m_io_o==1 && b.d.s1_o==0 && b.d.s0_o==0,
              "HALT status/address did not identify A1=1");
        b.cycle(); b.cycle();
        check(!b.d.status_valid_o, "held HALT indication repeated its status cycle");
        b.d.halt_i=0; b.d.eval(); b.cycle();
        b.d.shutdown_i=1; b.d.eval(); b.cycle();
        check(b.d.status_valid_o && b.d.address_o==0 &&
              b.d.cod_inta_o==0 && b.d.m_io_o==1 && b.d.s1_o==0 && b.d.s0_o==0,
              "shutdown status/address did not identify A1=0");

        // An odd-address two-byte beat is malformed; the core must split it.
        b.d.shutdown_i=0; b.d.req_i=0; b.d.eval(); b.cycle();
        b.d.req_i=1; b.d.address_i=0x000101; b.d.beat_bytes_i=2; b.d.eval();
        check(b.d.protocol_error_o && !b.d.core_ready_o,
              "odd-address word beat was not rejected");
        b.cycle();
        check(!b.d.cycle_active_o, "malformed beat entered a bus cycle");
        b.d.req_i=0; b.d.eval(); b.cycle();

        // The physical form of an odd logical word is two byte beats: the
        // low byte at the odd address uses D15:D8, then the high byte at the
        // next even address uses D7:D0.
        b.start(false,true,false,0x000301,1,0x3400);
        check(b.d.bhe_n_o==0, "odd-word first byte did not use the upper lane");
        b.enter_tc();
        check(b.d.data_oe_o && b.d.data_o==0x3400,
              "odd-word first byte was not driven on D15:D8");
        b.finish_write(1);
        b.start(false,true,false,0x000302,1,0x0056);
        check(b.d.bhe_n_o==1, "odd-word second byte did not use the lower lane");
        b.enter_tc();
        check(b.d.data_oe_o && b.d.data_o==0x0056,
              "odd-word second byte was not driven on D7:D0");
        b.finish_write(1);

        std::cout << "PASS: native bus status, byte lanes, word beats, waits, HOLD, LOCK, INTA and halt/shutdown\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
