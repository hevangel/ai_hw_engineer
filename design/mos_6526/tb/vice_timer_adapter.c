/* Original VICE ciatimer sources are compiled unchanged. This file only
 * supplies calls at documented update-before-register-write boundaries. */
#include "ciatimer.h"
static ciat_t reference;
static alarm_t scheduled;
static CLOCK current_clock;
void cia_oracle_reset(void) {
    ciat_init_table();
    current_clock=0;
    ciat_init(&reference,"external CIA timer",current_clock,&scheduled);
    ciat_reset(&reference,current_clock);
}
void cia_oracle_cycle(unsigned command,unsigned data,int pulse) {
    if (pulse) ciat_single_step(&reference,current_clock);
    ciat_update(&reference,++current_clock);
    if (command==1) ciat_set_latchlo(&reference,current_clock,data);
    else if (command==2) ciat_set_latchhi(&reference,current_clock,data);
    else if (command==3) ciat_set_ctrl(&reference,current_clock,data);
}
unsigned cia_oracle_count(void) { return ciat_read_timer(&reference,current_clock); }
unsigned cia_oracle_latch(void) { return ciat_read_latch(&reference,current_clock); }
unsigned cia_oracle_started(void) { return ciat_is_running(&reference,current_clock); }
unsigned cia_oracle_underflow(void) { return ciat_is_underflow_clk(&reference,current_clock); }
