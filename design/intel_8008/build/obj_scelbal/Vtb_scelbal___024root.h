// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_scelbal.h for the primary calling header

#ifndef VERILATED_VTB_SCELBAL___024ROOT_H_
#define VERILATED_VTB_SCELBAL___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_scelbal__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_scelbal___024root final {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb_scelbal__DOT__clk;
    CData/*0:0*/ tb_scelbal__DOT__rst_n;
    CData/*0:0*/ tb_scelbal__DOT__mem_write;
    CData/*0:0*/ tb_scelbal__DOT__retire;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT____VlemCall_1__flag_selected;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT____VlemCall_0__flag_selected;
    CData/*3:0*/ tb_scelbal__DOT__dut__DOT__state;
    CData/*2:0*/ tb_scelbal__DOT__dut__DOT__sp;
    CData/*7:0*/ tb_scelbal__DOT__dut__DOT__op;
    CData/*7:0*/ tb_scelbal__DOT__dut__DOT__addr_low;
    CData/*7:0*/ tb_scelbal__DOT__dut__DOT__immediate;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT__carry;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT__zero;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT__sign;
    CData/*0:0*/ tb_scelbal__DOT__dut__DOT__parity;
    CData/*7:0*/ tb_scelbal__DOT__dut__DOT__sequencer__DOT__code;
    CData/*7:0*/ tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8;
    CData/*0:0*/ __Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0;
    SData/*13:0*/ tb_scelbal__DOT__mem_addr;
    SData/*13:0*/ tb_scelbal__DOT__dut__DOT__pc;
    IData/*31:0*/ tb_scelbal__DOT__cycles;
    IData/*31:0*/ tb_scelbal__DOT__reads;
    IData/*31:0*/ tb_scelbal__DOT__writes;
    IData/*31:0*/ tb_scelbal__DOT__inputs;
    IData/*31:0*/ tb_scelbal__DOT__outputs;
    IData/*31:0*/ __Vi;
    VlUnpacked<CData/*7:0*/, 16384> tb_scelbal__DOT__mem;
    VlUnpacked<CData/*7:0*/, 16384> tb_scelbal__DOT__final_mem;
    VlUnpacked<VlWide<3>/*76:0*/, 200000> tb_scelbal__DOT__expected;
    VlUnpacked<CData/*7:0*/, 7> tb_scelbal__DOT__dut__DOT__r;
    VlUnpacked<SData/*13:0*/, 8> tb_scelbal__DOT__dut__DOT__stack;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggeredAcc;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    VlDelayScheduler __VdlySched;
    VlTriggerScheduler __VtrigSched_hebcb83c2__0;

    // INTERNAL VARIABLES
    Vtb_scelbal__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vtb_scelbal___024root(Vtb_scelbal__Syms* symsp, const char* namep);
    ~Vtb_scelbal___024root();
    VL_UNCOPYABLE(Vtb_scelbal___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
