// Verilator runner for a bounded, operation-driven FST capture.
// The simulator keeps running for the live panel. Each key/paper operation
// replaces the FST and closes it when the hardware becomes idle, so Surfer
// always reads a finalized file.
#include "Vtb_top.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include <cstdlib>
#include <cstdio>
#include <memory>

extern "C" int dpi_trace_active(void);

int main(int argc, char** argv) {
    const char* path = std::getenv("BUSICOM_FST_PATH");
    if (!path || !*path) return 2;

    const std::unique_ptr<VerilatedContext> context{new VerilatedContext};
    context->traceEverOn(true);
    context->threads(1);
    context->commandArgs(argc, argv);
    const std::unique_ptr<Vtb_top> top{new Vtb_top{context.get(), ""}};

    std::unique_ptr<VerilatedFstC> trace;
    std::remove(path);
    bool recording = false;
    vluint64_t capture_start = 0;
    while (!context->gotFinish()) {
        top->eval();
        const bool active = dpi_trace_active() != 0;
        if (active && !recording) {
            capture_start = context->time();
            trace.reset(new VerilatedFstC);
            top->trace(trace.get(), 3);
            trace->open(path);
        }
        if (active) trace->dump(context->time() - capture_start);
        if (recording && !active) {
            trace->close();
            trace.reset();
        }
        recording = active;
        if (!top->eventsPending()) break;
        context->time(top->nextTimeSlot());
    }
    if (recording) trace->close();
    top->final();
    return 0;
}
