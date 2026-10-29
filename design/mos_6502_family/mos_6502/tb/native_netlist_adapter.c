/* Test-only adapter to the unmodified, pinned perfect6502 sources.
 * Including the original translation unit keeps its netlist node identifiers
 * private to this adapter; no transistor tables are copied into the RTL. */
#include "perfect6502.c"

void oracle_pins(void *state, int ready, int irq_high, int nmi_high) {
    setNode(state, rdy, ready);
    setNode(state, irq, irq_high);
    setNode(state, nmi, nmi_high);
    recalcNodeList(state);
}
int oracle_sync(void *state) { return isNodeHigh(state, 539); }
void oracle_cycle(void *state) { step(state); step(state); }
