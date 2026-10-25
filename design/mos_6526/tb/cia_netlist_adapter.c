/* Test-only late-settling I/O adapter; recovered transistor sources unchanged. */
#include "../../mos_6502/tb/native_netlist_adapter.c"
void oracle_read_data(void *state, unsigned char data) {
    writeDataBus(state, data);
    recalcNodeList(state);
}
