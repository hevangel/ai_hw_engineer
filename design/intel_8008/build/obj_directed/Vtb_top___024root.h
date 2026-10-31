// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_top.h for the primary calling header

#ifndef VERILATED_VTB_TOP___024ROOT_H_
#define VERILATED_VTB_TOP___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_top__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_top___024root final {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb_top__DOT__clk;
    CData/*0:0*/ tb_top__DOT__rst_n;
    CData/*0:0*/ tb_top__DOT__mem_write;
    CData/*0:0*/ tb_top__DOT__interrupt_i;
    CData/*7:0*/ tb_top__DOT__interrupt_opcode;
    CData/*0:0*/ tb_top__DOT__retire;
    CData/*0:0*/ tb_top__DOT__dut__DOT____VlemCall_1__flag_selected;
    CData/*0:0*/ tb_top__DOT__dut__DOT____VlemCall_0__flag_selected;
    CData/*3:0*/ tb_top__DOT__dut__DOT__state;
    CData/*2:0*/ tb_top__DOT__dut__DOT__sp;
    CData/*7:0*/ tb_top__DOT__dut__DOT__op;
    CData/*7:0*/ tb_top__DOT__dut__DOT__addr_low;
    CData/*7:0*/ tb_top__DOT__dut__DOT__immediate;
    CData/*0:0*/ tb_top__DOT__dut__DOT__carry;
    CData/*0:0*/ tb_top__DOT__dut__DOT__zero;
    CData/*0:0*/ tb_top__DOT__dut__DOT__sign;
    CData/*0:0*/ tb_top__DOT__dut__DOT__parity;
    CData/*7:0*/ tb_top__DOT__dut__DOT__sequencer__DOT__code;
    CData/*7:0*/ tb_top__DOT__dut__DOT__sequencer__DOT__tmp8;
    CData/*0:0*/ __Vtrigprevexpr___TOP__tb_top__DOT__clk__0;
    SData/*13:0*/ tb_top__DOT__mem_addr;
    SData/*13:0*/ tb_top__DOT__dut__DOT__pc;
    IData/*31:0*/ tb_top__DOT__writes;
    IData/*31:0*/ tb_top__DOT__outs;
    IData/*31:0*/ __Vi;
    VlUnpacked<CData/*7:0*/, 16384> tb_top__DOT__mem;
    VlUnpacked<CData/*7:0*/, 7> tb_top__DOT__dut__DOT__r;
    VlUnpacked<SData/*13:0*/, 8> tb_top__DOT__dut__DOT__stack;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggeredAcc;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    VlDelayScheduler __VdlySched;
    VlTriggerScheduler __VtrigSched_h71ae4e14__0;

    // INTERNAL VARIABLES
    Vtb_top__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vtb_top___024root(Vtb_top__Syms* symsp, const char* namep);
    ~Vtb_top___024root();
    VL_UNCOPYABLE(Vtb_top___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
