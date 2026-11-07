/* Minimal VHPI plugin: registers a start-of-simulation callback that prints a marker. */
#include <vhpi_user.h>

static void started(const vhpiCbDataT *cb)
{
   (void)cb;
   vhpi_printf("VHPI STARTUP PASS\n");
}

static void startup(void)
{
   vhpiCbDataT cb;
   cb.reason = vhpiCbStartOfSimulation;
   cb.cb_rtn = started;
   cb.obj = NULL;
   cb.time = NULL;
   cb.value = NULL;
   cb.user_data = NULL;
   vhpi_register_cb(&cb, 0);
}

void (*vhpi_startup_routines[])(void) = { startup, NULL };
