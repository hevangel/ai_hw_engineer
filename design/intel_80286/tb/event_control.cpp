#include "Vintel_80286_event_control.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

// Transaction contracts sourced from Intel 210498-005 9.2/9.5 and A8.
// No instruction semantics or RTL state-machine model is reproduced here.
struct Test {
    Vintel_80286_event_control d;
    unsigned checks=0;
    uint32_t random=0x802862a;
    void require(bool value, const char* message) {
        ++checks;
        if (!value) throw std::runtime_error(message);
    }
    void tick() { d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); }
    unsigned next() { random^=random<<13; random^=random>>17; random^=random<<5; return random; }
    void idle() { require(!d.ack_req_o && !d.event_valid_o,"unexpected transaction"); }
    void reset() {
        d.boundary_i=0; d.inhibit_i=0; d.step_i=0; d.if_i=0; d.intr_i=0;
        d.nmi_i=0; d.iret_i=0; d.shutdown_i=0; d.shutdown_nmi_enable_i=0;
        d.ack_ready_i=0; d.event_ready_i=0;
        d.ack_vector_i=0; d.rst_n=0; d.eval(); idle(); tick();
        require(!d.nmi_pending_o && !d.nmi_blocked_o,"reset NMI state");
        d.rst_n=1; d.eval();
    }
    void delivery(unsigned vector) {
        require(d.event_valid_o && !d.ack_req_o && d.event_vector_o==vector,"wrong delivery");
    }
    void consume(unsigned vector) {
        delivery(vector); d.event_ready_i=1; tick(); d.event_ready_i=0; idle();
    }
    void run() {
        reset(); d.boundary_i=1; d.intr_i=1;
        for (unsigned i=0;i<8;++i) { tick(); idle(); }
        d.if_i=1; d.inhibit_i=1; d.nmi_i=1; d.step_i=1;
        tick(); idle(); require(d.nmi_pending_o,"inhibited NMI not remembered");
        d.inhibit_i=0; tick(); delivery(1);
        require(d.nmi_pending_o && !d.nmi_blocked_o,"step consumed NMI");
        d.step_i=0; consume(1); tick(); delivery(2);
        require(!d.nmi_pending_o && d.nmi_blocked_o,"NMI selection state");
        consume(2); d.intr_i=0;
        for (unsigned i=0;i<8;++i) { tick(); idle(); require(!d.nmi_pending_o,"held NMI repeated"); }
        // One more edge during NMI service is held until a completed IRET.
        d.nmi_i=0; tick(); d.nmi_i=1; tick();
        require(d.nmi_pending_o,"second NMI lost"); idle();
        d.nmi_i=0; tick(); d.nmi_i=1; tick(); idle();
        d.iret_i=1; tick(); d.iret_i=0; delivery(2); consume(2);
        require(!d.nmi_pending_o && d.nmi_blocked_o,"NMI queue did not coalesce");
        d.iret_i=1; tick(); d.iret_i=0; idle(); tick(); idle();
        require(!d.nmi_blocked_o,"IRET failed to unblock NMI");

        // Shutdown ignores INTR and accepts one NMI even while NMI is
        // otherwise blocked. A failed recovery disables further NMI wakeups
        // until RESET.
        reset(); d.shutdown_i=1; d.shutdown_nmi_enable_i=1;
        d.if_i=1; d.intr_i=1; d.nmi_i=1; tick(); delivery(2);
        require(d.nmi_blocked_o && !d.nmi_pending_o && !d.ack_req_o,
                "shutdown NMI selection or INTR suppression");
        d.event_ready_i=0;
        for (unsigned i=0;i<8;++i) { tick(); delivery(2); }
        d.shutdown_i=0; d.shutdown_nmi_enable_i=0;
        consume(2);
        d.shutdown_i=1; d.shutdown_nmi_enable_i=0;
        d.nmi_i=0; tick(); d.nmi_i=1; tick(); idle();
        require(!d.nmi_pending_o && !d.ack_req_o,
                "failed shutdown NMI left another wake pending");

        // Every possible INTR vector, with independent, changing inputs while
        // both phases stall. New NMI must wait behind the claimed transaction.
        for (unsigned vector=0;vector<256;++vector) {
            reset(); d.boundary_i=1; d.if_i=1; d.intr_i=1; tick();
            require(d.ack_req_o && !d.event_valid_o,"INTR missing acknowledgement");
            d.if_i=0; d.intr_i=0; d.step_i=1; d.nmi_i=1;
            const unsigned ack_stalls=1+next()%17;
            for (unsigned i=0;i<ack_stalls;++i) {
                d.ack_vector_i=next()&255; tick();
                require(d.ack_req_o && !d.event_valid_o,"acknowledgement did not hold");
            }
            d.ack_vector_i=vector; d.ack_ready_i=1; tick(); delivery(vector);
            d.ack_ready_i=0;
            const unsigned delivery_stalls=1+next()%17;
            for (unsigned i=0;i<delivery_stalls;++i) {
                d.ack_vector_i=next()&255; d.inhibit_i=next()&1; tick(); delivery(vector);
            }
            require(d.nmi_pending_o,"NMI lost behind claimed INTR");
            d.boundary_i=0; consume(vector); d.step_i=0; d.inhibit_i=0;
            tick(); idle(); require(d.nmi_pending_o,"pending NMI consumed outside boundary");
            d.boundary_i=1; tick(); delivery(2); consume(2);
        }
        // Reset cancellation at each held phase, including combinational
        // output suppression before the active reset clock edge.
        for (unsigned phase=0;phase<2;++phase) {
            reset(); d.boundary_i=1; d.if_i=1; d.intr_i=1; tick();
            if (phase) { d.ack_ready_i=1; d.ack_vector_i=0xff; tick(); delivery(0xff); }
            d.nmi_i=1; d.rst_n=0; d.eval(); idle(); tick();
            require(!d.nmi_pending_o && !d.nmi_blocked_o,"reset retained NMI");
            d.boundary_i=0; d.rst_n=1; tick(); idle();
            require(d.nmi_pending_o,"high NMI after reset not sampled");
            d.boundary_i=1; tick(); delivery(2); consume(2);
        }
        // Fresh edge and completed IRET together consume exactly one NMI.
        reset(); d.boundary_i=1; d.nmi_i=1; tick(); consume(2);
        d.nmi_i=0; tick(); d.nmi_i=1; d.iret_i=1; tick();
        d.iret_i=0; consume(2);
        require(!d.nmi_pending_o && d.nmi_blocked_o,"simultaneous IRET/edge duplicated NMI");
        std::cout<<"PASS event-controller transaction contracts: "<<checks<<" checks\n";
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try { Test test; test.run(); }
    catch (const std::exception& error) { std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1; }
    return 0;
}
