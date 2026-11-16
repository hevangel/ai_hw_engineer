// Minimal VPI module for the Icarus plugin path.
//
// Loaded with `vvp -M<dir> -m<basename>`, so the entry point must be named
// `vlog_startup_routines`. The callback runs at start of simulation and proves
// the packaged helper built a loadable module.
#include <vpi_user.h>

static PLI_INT32 hello_start(p_cb_data data) {
    (void)data;
    vpi_printf("VPI HELLO PASS\n");
    return 0;
}

static void register_hello(void) {
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = hello_start;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_hello, 0 };