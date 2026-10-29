/* Independent pin oracle adapter; external sources retain their licenses.
 * No authored CPU semantics occur here. Follow perfect6502.c's clock/memory
 * schedule, and expose observed physical pins and registers. */
#include <stdint.h>
#include "netlist_6502.h"
#include "netlist_sim.h"
static state_t *chip;
static uint8_t *memory;
static nodenum_t ab[]={ab0,ab1,ab2,ab3,ab4,ab5,ab6,ab7,ab8,ab9,ab10,ab11,ab12,ab13,ab14,ab15};
static nodenum_t db[]={db0,db1,db2,db3,db4,db5,db6,db7};
static void memory_phase(void) {
    unsigned address=readNodes(chip,16,ab);
    if(isNodeHigh(chip,rw)) writeNodes(chip,8,db,memory[address]);
    else memory[address]=readNodes(chip,8,db);
}
void oracle_cycle(void) {
    setNode(chip,clk0,0); setNode(chip,clk0,1); memory_phase();
}
/* Some architectural latches (for example DEX) commit on phi1 of the
 * following opcode. Bus pins are compared first, then architectural state
 * is observed at this settled boundary before the next phi2 memory phase. */
void oracle_settle_registers(void) { setNode(chip,clk0,0); }
void oracle_init(uint8_t *external_memory) {
    if(chip) destroyNodesAndTransistors(chip);
    memory=external_memory;
    chip=setupNodesAndTransistors(netlist_6502_transdefs,netlist_6502_node_is_pullup,
        sizeof(netlist_6502_node_is_pullup)/sizeof(*netlist_6502_node_is_pullup),
        sizeof(netlist_6502_transdefs)/sizeof(*netlist_6502_transdefs),vss,vcc);
    setNode(chip,res,0); setNode(chip,clk0,1); setNode(chip,rdy,1);
    setNode(chip,so,0); setNode(chip,irq,1); setNode(chip,nmi,1); stabilizeChip(chip);
    for(int i=0;i<16;i++) oracle_cycle();
    setNode(chip,res,1);
}
void oracle_pins(int reset,int irq_value,int nmi_value,int ready,int so_value) {
    if(isNodeHigh(chip,res)!=reset) setNode(chip,res,reset);
    if(isNodeHigh(chip,irq)!=irq_value) setNode(chip,irq,irq_value);
    if(isNodeHigh(chip,nmi)!=nmi_value) setNode(chip,nmi,nmi_value);
    if(isNodeHigh(chip,rdy)!=ready) setNode(chip,rdy,ready);
    if(isNodeHigh(chip,so)!=so_value) setNode(chip,so,so_value);
}
unsigned oracle_address(void) { return readNodes(chip,16,ab); }
unsigned oracle_data(void) { return readNodes(chip,8,db); }
unsigned oracle_rw(void) { return isNodeHigh(chip,rw); }
unsigned oracle_sync(void) { return isNodeHigh(chip,539); }
unsigned oracle_a(void) { nodenum_t ns[]={a0,a1,a2,a3,a4,a5,a6,a7}; return readNodes(chip,8,ns); }
unsigned oracle_x(void) { nodenum_t ns[]={x0,x1,x2,x3,x4,x5,x6,x7}; return readNodes(chip,8,ns); }
unsigned oracle_y(void) { nodenum_t ns[]={y0,y1,y2,y3,y4,y5,y6,y7}; return readNodes(chip,8,ns); }
unsigned oracle_sp(void) { nodenum_t ns[]={s0,s1,s2,s3,s4,s5,s6,s7}; return readNodes(chip,8,ns); }
unsigned oracle_p(void) { nodenum_t ns[]={p0,p1,p2,p3,p4,p5,p6,p7}; return readNodes(chip,8,ns); }
