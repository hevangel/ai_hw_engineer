/* Simulation-only adapter. External solver/netlist retain their own licenses.
 * No memory model is hidden here: every bus access goes through the SV board.
 */
#include <stdlib.h>
#include "vpi_user.h"
#include "netlist_6502.h"
#include "netlist_sim.h"

static state_t *cpu;
static nodenum_t address_nodes[] = {ab0,ab1,ab2,ab3,ab4,ab5,ab6,ab7,
                                   ab8,ab9,ab10,ab11,ab12,ab13,ab14,ab15};
static nodenum_t data_nodes[] = {db0,db1,db2,db3,db4,db5,db6,db7};

static PLI_INT32 step_call(PLI_BYTE8 *unused)
{
    (void)unused;
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle args = vpi_iterate(vpiArgument, call);
    int in[7];
    for (int i=0;i<7;i++) {
        vpiHandle arg=vpi_scan(args);
        if (!arg) { vpi_printf("6502 adapter needs seven pin arguments\n"); vpi_control(vpiFinish,1); return 0; }
        s_vpi_value value={.format=vpiIntVal};
        vpi_get_value(arg,&value);
        in[i]=value.value.integer;
    }
    vpi_free_object(args);
    if (!cpu) {
        cpu=setupNodesAndTransistors(netlist_6502_transdefs,
            netlist_6502_node_is_pullup,
            sizeof(netlist_6502_node_is_pullup)/sizeof(*netlist_6502_node_is_pullup),
            sizeof(netlist_6502_transdefs)/sizeof(*netlist_6502_transdefs),vss,vcc);
        if (!cpu) abort();
        setNode(cpu,res,0); setNode(cpu,clk0,1); setNode(cpu,rdy,1);
        setNode(cpu,so,0); setNode(cpu,irq,1); setNode(cpu,nmi,1);
        stabilizeChip(cpu);
    }
    /* Data is captured immediately before the falling clock. Unlike the
     * reference standalone emulator, read data comes from external pin nets. */
    if (isNodeHigh(cpu,clk0) && !in[0] && isNodeHigh(cpu,rw)) {
        writeNodes(cpu,8,data_nodes,in[6]);
        recalcNodeList(cpu);
    }
    setNode(cpu,res,in[1]); setNode(cpu,irq,in[2]); setNode(cpu,nmi,in[3]);
    setNode(cpu,rdy,in[4]); setNode(cpu,so,in[5]);
    setNode(cpu,clk0,in[0]); recalcNodeList(cpu);
    /* Node numbers 539/1163/421 are sync_/clk1out/clk2out in the pinned
     * Visual6502 artifact (commented names, so use the documented numbers). */
    unsigned result=readNodes(cpu,16,address_nodes) |
        (readNodes(cpu,8,data_nodes)<<16) | (isNodeHigh(cpu,rw)<<24) |
        (isNodeHigh(cpu,539)<<25) | (isNodeHigh(cpu,1163)<<26) |
        (isNodeHigh(cpu,421)<<27);
    s_vpi_value value={.format=vpiIntVal};
    value.value.integer=(PLI_INT32)result;
    vpi_put_value(call,&value,NULL,vpiNoDelay);
    return 0;
}

static void register_cpu(void)
{
    s_vpi_systf_data tf={0};
    tf.type=vpiSysFunc; tf.sysfunctype=vpiIntFunc;
    tf.tfname="$apple_ii_cpu_step"; tf.calltf=step_call;
    vpi_register_systf(&tf);
}
void (*vlog_startup_routines[])(void)={register_cpu,0};
