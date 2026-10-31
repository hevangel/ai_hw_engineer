#include "Vintel_80286_bus_owner.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

static void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

struct Bench {
    Vintel_80286_bus_owner d;

    Bench() {
        d.cpu_req_i=0; d.cpu_addr_i=0; d.cpu_write_i=0; d.cpu_wdata_i=0; d.cpu_context_i=0;
        d.descriptor_claim_i=0; d.descriptor_release_i=0; d.descriptor_req_i=0;
        d.descriptor_addr_i=0; d.descriptor_write_i=0; d.descriptor_wdata_i=0; d.descriptor_context_i=0;
        d.event_claim_i=0; d.event_release_i=0; d.event_req_i=0;
        d.event_addr_i=0; d.event_write_i=0; d.event_wdata_i=0; d.event_context_i=0;
        d.pedc_claim_i=0; d.pedc_release_i=0; d.pedc_req_i=0;
        d.pedc_addr_i=0; d.pedc_write_i=0; d.pedc_wdata_i=0; d.pedc_context_i=0;
        d.bus_ready_i=0; d.bus_rdata_i=0; d.clk=0; d.rst_n=0;
        d.eval(); cycle();
        check(d.owner_o==0 && d.cpu_grant_o && !d.descriptor_grant_o && !d.event_grant_o,
              "reset owner was not CPU");
        d.rst_n=1; d.eval();
    }

    void cycle() {
        d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval();
    }

    void expect_bus(uint32_t address, bool write, uint16_t value, uint32_t context) {
        check(d.bus_req_o && d.bus_addr_o==address && bool(d.bus_write_o)==write &&
              d.bus_wdata_o==value && d.bus_context_o==context,
              "selected request fields did not match the owner");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Bench b;

        // A descriptor claim cannot preempt a held CPU request or consume its response.
        b.d.cpu_req_i=1; b.d.cpu_addr_i=0x123456; b.d.cpu_write_i=1;
        b.d.cpu_wdata_i=0xa55a; b.d.cpu_context_i=0x11223344;
        b.d.descriptor_claim_i=1; b.d.descriptor_req_i=1;
        b.d.descriptor_addr_i=0x654321; b.d.descriptor_write_i=1;
        b.d.descriptor_wdata_i=0x5ac3; b.d.descriptor_context_i=0x55667788;
        b.d.bus_ready_i=0; b.d.eval();
        b.expect_bus(0x123456,true,0xa55a,0x11223344);
        check(b.d.cpu_grant_o && !b.d.descriptor_grant_o && !b.d.cpu_ready_o && !b.d.descriptor_ready_o,
              "held CPU request leaked grant/response");
        b.cycle();
        b.expect_bus(0x123456,true,0xa55a,0x11223344);

        b.d.bus_ready_i=1; b.d.bus_rdata_i=0xbeef; b.d.eval();
        check(b.d.cpu_ready_o && !b.d.descriptor_ready_o && b.d.bus_rdata_o==0xbeef,
              "CPU response was not exclusive");
        b.cycle();
        b.d.cpu_req_i=0; b.d.bus_ready_i=0; b.d.eval(); b.cycle();
        check(b.d.owner_o==1 && b.d.descriptor_grant_o,"idle descriptor claim was not granted");
        b.expect_bus(0x654321,true,0x5ac3,0x55667788);

        // Release cannot abandon an unaccepted descriptor byte; CPU waits behind the lock.
        b.d.cpu_req_i=1; b.d.cpu_addr_i=0x010203; b.d.cpu_context_i=0xdeadbeef;
        b.d.descriptor_release_i=1; b.d.bus_ready_i=0; b.d.eval();
        check(!b.d.cpu_ready_o && !b.d.event_ready_o && !b.d.descriptor_ready_o,
              "non-owner consumed a stalled descriptor response");
        b.cycle();
        check(b.d.owner_o==1,"descriptor release dropped a held request");
        b.expect_bus(0x654321,true,0x5ac3,0x55667788);
        b.d.descriptor_addr_i=0x111111; b.d.descriptor_wdata_i=0xee;
        b.d.descriptor_context_i=0x01020304; b.d.eval();
        b.expect_bus(0x654321,true,0x5ac3,0x55667788);
        b.d.bus_ready_i=1; b.d.bus_rdata_i=0x12c7; b.d.eval();
        check(b.d.descriptor_ready_o && !b.d.cpu_ready_o && !b.d.event_ready_o && b.d.bus_rdata_o==0x12c7,
              "descriptor response was not exclusive");
        b.cycle();
        check(b.d.owner_o==0 && b.d.cpu_grant_o,"descriptor release did not return ownership");
        b.expect_bus(0x010203,true,0xa55a,0xdeadbeef);

        // Event claims win simultaneous idle claims and own the bus through quiet cycles.
        b.d.cpu_req_i=0; b.d.event_claim_i=1; b.d.event_req_i=1;
        b.d.event_addr_i=0x00f100; b.d.event_write_i=0; b.d.event_wdata_i=0;
        b.d.event_context_i=0xabcdef01; b.d.descriptor_claim_i=1;
        b.d.bus_ready_i=0; b.d.eval(); b.cycle();
        check(b.d.owner_o==2 && b.d.event_grant_o && !b.d.descriptor_grant_o,
              "event claim did not win idle arbitration");
        b.expect_bus(0x00f100,false,0,0xabcdef01);
        b.d.event_release_i=1; b.d.eval(); b.cycle();
        check(b.d.owner_o==2,"event release abandoned a stalled read");
        b.d.event_req_i=0; b.d.event_addr_i=0x222222; b.d.event_context_i=0x04030201; b.d.eval();
        b.expect_bus(0x00f100,false,0,0xabcdef01);
        b.d.bus_ready_i=1; b.d.bus_rdata_i=0xab91; b.d.eval();
        check(b.d.event_ready_o && !b.d.cpu_ready_o && !b.d.descriptor_ready_o && b.d.bus_rdata_o==0xab91,
              "event response was not exclusive");
        b.cycle();
        check(b.d.owner_o==0,"event release did not return ownership");
        b.d.event_release_i=0; b.d.event_claim_i=0; b.d.event_req_i=0;
        b.d.descriptor_req_i=0; b.d.eval(); b.cycle();
        check(b.d.owner_o==1 && b.d.descriptor_grant_o,
              "waiting descriptor claim was lost behind the event owner");
        b.d.descriptor_claim_i=0; b.d.descriptor_release_i=1; b.d.eval(); b.cycle();
        check(b.d.owner_o==0,"quiet descriptor release did not return ownership");

        // PEDC owns an entire multi-beat word, including the quiet gap, and
        // a competing event cannot steal either beat or its READY response.
        b.d.descriptor_release_i=0; b.d.descriptor_claim_i=0;
        b.d.pedc_claim_i=1; b.d.pedc_req_i=1; b.d.pedc_addr_i=0x1001;
        b.d.pedc_write_i=0; b.d.pedc_wdata_i=0; b.d.pedc_context_i=0x31;
        b.d.bus_ready_i=0; b.d.eval(); b.cycle();
        check(b.d.pedc_grant_o && b.d.owner_o==3,"PEDC claim was not granted");
        b.expect_bus(0x1001,false,0,0x31);
        b.d.event_claim_i=1; b.d.event_req_i=1; b.d.pedc_release_i=1;
        b.d.eval(); b.cycle();
        check(b.d.pedc_grant_o && !b.d.event_grant_o,"PEDC released stalled beat");
        b.d.pedc_release_i=0; b.d.bus_ready_i=1; b.d.eval();
        check(b.d.pedc_ready_o && !b.d.event_ready_o,"PEDC response was not exclusive");
        b.cycle();
        b.d.pedc_req_i=0; b.d.bus_ready_i=0; b.d.eval(); b.cycle();
        check(b.d.pedc_grant_o && !b.d.event_grant_o,"PEDC lost quiet word gap");
        b.d.pedc_req_i=1; b.d.pedc_addr_i=0x00fa; b.d.pedc_write_i=1;
        b.d.pedc_wdata_i=0x1234; b.d.pedc_context_i=0x32; b.d.eval();
        b.expect_bus(0x00fa,true,0x1234,0x32);
        b.d.bus_ready_i=1; b.d.pedc_release_i=1; b.d.eval(); b.cycle();
        check(b.d.cpu_grant_o && !b.d.pedc_grant_o,"PEDC did not release completed word");
        b.d.pedc_claim_i=0; b.d.pedc_req_i=0; b.d.pedc_release_i=0;
        b.d.event_claim_i=0; b.d.event_req_i=0; b.d.eval();

        // Reset cancels a pending special owner and suppresses the external request.
        b.d.descriptor_release_i=0; b.d.event_claim_i=1; b.d.event_req_i=1;
        b.d.bus_ready_i=0; b.d.eval(); b.cycle();
        check(b.d.event_grant_o && b.d.bus_req_o,"event owner was not active before reset");
        b.d.rst_n=0; b.d.eval();
        check(!b.d.bus_req_o && !b.d.cpu_ready_o && !b.d.descriptor_ready_o && !b.d.event_ready_o,
              "reset did not suppress a pending bus request");
        b.d.event_req_i=0; b.d.event_claim_i=0; b.cycle();
        b.d.rst_n=1; b.d.eval();
        check(b.d.owner_o==0 && b.d.cpu_grant_o && !b.d.bus_req_o,
              "reset did not cancel the special owner");

        std::cout << "PASS: bus-owner idle claims, held waits, exclusive responses and reset cancellation\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
