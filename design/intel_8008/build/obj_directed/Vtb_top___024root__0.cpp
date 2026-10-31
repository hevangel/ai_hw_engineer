// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_top.h for the primary calling header

#include "Vtb_top__pch.h"

VlCoroutine Vtb_top___024root___eval_initial__TOP__Vtiming__0(Vtb_top___024root* vlSelf);
VlCoroutine Vtb_top___024root___eval_initial__TOP__Vtiming__1(Vtb_top___024root* vlSelf);

void Vtb_top___024root___eval_initial(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_initial\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_top___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_top___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vtb_top___024root___eval_sample(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_sample\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_top___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtb_top___024root___eval_ico(Vtb_top___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_ico\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_top___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vtb_top___024root___timing_ready(Vtb_top___024root* vlSelf);
void Vtb_top___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_top___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vtb_top___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);
void Vtb_top___024root___timing_resume(Vtb_top___024root* vlSelf);

bool Vtb_top___024root___eval_act(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_act\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 2U) 
                                                         | ((((~ (IData)(vlSelfRef.tb_top__DOT__clk)) 
                                                              & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_top__DOT__clk__0)) 
                                                             << 1U) 
                                                            | ((IData)(vlSelfRef.tb_top__DOT__clk) 
                                                               & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_top__DOT__clk__0)))))));
        vlSelfRef.__Vtrigprevexpr___TOP__tb_top__DOT__clk__0 
            = vlSelfRef.tb_top__DOT__clk;
    }
    Vtb_top___024root___timing_ready(vlSelf);
    Vtb_top___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_top___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtb_top___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vtb_top___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        Vtb_top___024root___timing_resume(vlSelf);
    }
    return (__VactExecute);
}

bool Vtb_top___024root___eval_inact(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_inact\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 1, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vtb_top___024root___nba_sequent__TOP__0(Vtb_top___024root* vlSelf);
void Vtb_top___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out);

bool Vtb_top___024root___eval_nba(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_nba\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtb_top___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                Vtb_top___024root___nba_sequent__TOP__0(vlSelf);
            }
        }
        Vtb_top___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vtb_top___024root___eval_obs(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_obs\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vtb_top___024root___eval_react(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_react\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vtb_top___024root___eval_postponed(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_postponed\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

void Vtb_top___024root____VbeforeTrig_h71ae4e14__0(Vtb_top___024root* vlSelf, const char* __VeventDescription);

VlCoroutine Vtb_top___024root___eval_initial__TOP__Vtiming__0(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ tb_top__DOT__unnamedblk1__DOT__i;
    tb_top__DOT__unnamedblk1__DOT__i = 0;
    IData/*31:0*/ tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0;
    tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0 = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__0__expected_pc;
    __Vtask_tb_top__DOT__step__0__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__0__expected_a;
    __Vtask_tb_top__DOT__step__0__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__0__cycles;
    __Vtask_tb_top__DOT__step__0__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__1__expected_pc;
    __Vtask_tb_top__DOT__step__1__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__1__expected_a;
    __Vtask_tb_top__DOT__step__1__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__1__cycles;
    __Vtask_tb_top__DOT__step__1__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__2__expected_pc;
    __Vtask_tb_top__DOT__step__2__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__2__expected_a;
    __Vtask_tb_top__DOT__step__2__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__2__cycles;
    __Vtask_tb_top__DOT__step__2__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__3__expected_pc;
    __Vtask_tb_top__DOT__step__3__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__3__expected_a;
    __Vtask_tb_top__DOT__step__3__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__3__cycles;
    __Vtask_tb_top__DOT__step__3__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__4__expected_pc;
    __Vtask_tb_top__DOT__step__4__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__4__expected_a;
    __Vtask_tb_top__DOT__step__4__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__4__cycles;
    __Vtask_tb_top__DOT__step__4__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__5__expected_pc;
    __Vtask_tb_top__DOT__step__5__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__5__expected_a;
    __Vtask_tb_top__DOT__step__5__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__5__cycles;
    __Vtask_tb_top__DOT__step__5__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__6__expected_pc;
    __Vtask_tb_top__DOT__step__6__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__6__expected_a;
    __Vtask_tb_top__DOT__step__6__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__6__cycles;
    __Vtask_tb_top__DOT__step__6__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__7__expected_pc;
    __Vtask_tb_top__DOT__step__7__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__7__expected_a;
    __Vtask_tb_top__DOT__step__7__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__7__cycles;
    __Vtask_tb_top__DOT__step__7__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__8__expected_pc;
    __Vtask_tb_top__DOT__step__8__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__8__expected_a;
    __Vtask_tb_top__DOT__step__8__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__8__cycles;
    __Vtask_tb_top__DOT__step__8__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__9__expected_pc;
    __Vtask_tb_top__DOT__step__9__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__9__expected_a;
    __Vtask_tb_top__DOT__step__9__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__9__cycles;
    __Vtask_tb_top__DOT__step__9__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__10__expected_pc;
    __Vtask_tb_top__DOT__step__10__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__10__expected_a;
    __Vtask_tb_top__DOT__step__10__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__10__cycles;
    __Vtask_tb_top__DOT__step__10__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__11__expected_pc;
    __Vtask_tb_top__DOT__step__11__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__11__expected_a;
    __Vtask_tb_top__DOT__step__11__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__11__cycles;
    __Vtask_tb_top__DOT__step__11__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__12__expected_pc;
    __Vtask_tb_top__DOT__step__12__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__12__expected_a;
    __Vtask_tb_top__DOT__step__12__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__12__cycles;
    __Vtask_tb_top__DOT__step__12__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__13__expected_pc;
    __Vtask_tb_top__DOT__step__13__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__13__expected_a;
    __Vtask_tb_top__DOT__step__13__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__13__cycles;
    __Vtask_tb_top__DOT__step__13__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__14__expected_pc;
    __Vtask_tb_top__DOT__step__14__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__14__expected_a;
    __Vtask_tb_top__DOT__step__14__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__14__cycles;
    __Vtask_tb_top__DOT__step__14__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__15__expected_pc;
    __Vtask_tb_top__DOT__step__15__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__15__expected_a;
    __Vtask_tb_top__DOT__step__15__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__15__cycles;
    __Vtask_tb_top__DOT__step__15__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__16__expected_pc;
    __Vtask_tb_top__DOT__step__16__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__16__expected_a;
    __Vtask_tb_top__DOT__step__16__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__16__cycles;
    __Vtask_tb_top__DOT__step__16__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__17__expected_pc;
    __Vtask_tb_top__DOT__step__17__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__17__expected_a;
    __Vtask_tb_top__DOT__step__17__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__17__cycles;
    __Vtask_tb_top__DOT__step__17__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__18__expected_pc;
    __Vtask_tb_top__DOT__step__18__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__18__expected_a;
    __Vtask_tb_top__DOT__step__18__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__18__cycles;
    __Vtask_tb_top__DOT__step__18__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__19__expected_pc;
    __Vtask_tb_top__DOT__step__19__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__19__expected_a;
    __Vtask_tb_top__DOT__step__19__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__19__cycles;
    __Vtask_tb_top__DOT__step__19__cycles = 0;
    SData/*13:0*/ __Vtask_tb_top__DOT__step__20__expected_pc;
    __Vtask_tb_top__DOT__step__20__expected_pc = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__step__20__expected_a;
    __Vtask_tb_top__DOT__step__20__expected_a = 0;
    IData/*31:0*/ __Vtask_tb_top__DOT__step__20__cycles;
    __Vtask_tb_top__DOT__step__20__cycles = 0;
    // Body
    tb_top__DOT__unnamedblk1__DOT__i = 0U;
    while (VL_GTS_III(32, 0x00004000U, tb_top__DOT__unnamedblk1__DOT__i)) {
        vlSelfRef.tb_top__DOT__mem[(0x00003fffU & tb_top__DOT__unnamedblk1__DOT__i)] = 0U;
        tb_top__DOT__unnamedblk1__DOT__i = ((IData)(1U) 
                                            + tb_top__DOT__unnamedblk1__DOT__i);
    }
    vlSelfRef.tb_top__DOT__mem[0U] = 6U;
    vlSelfRef.tb_top__DOT__mem[1U] = 0x7fU;
    vlSelfRef.tb_top__DOT__mem[2U] = 4U;
    vlSelfRef.tb_top__DOT__mem[3U] = 1U;
    vlSelfRef.tb_top__DOT__mem[4U] = 0x0eU;
    vlSelfRef.tb_top__DOT__mem[5U] = 5U;
    vlSelfRef.tb_top__DOT__mem[6U] = 0xc1U;
    vlSelfRef.tb_top__DOT__mem[7U] = 8U;
    vlSelfRef.tb_top__DOT__mem[8U] = 0x2eU;
    vlSelfRef.tb_top__DOT__mem[9U] = 0x20U;
    vlSelfRef.tb_top__DOT__mem[10U] = 0x36U;
    vlSelfRef.tb_top__DOT__mem[11U] = 0U;
    vlSelfRef.tb_top__DOT__mem[12U] = 0x3eU;
    vlSelfRef.tb_top__DOT__mem[13U] = 0xaaU;
    vlSelfRef.tb_top__DOT__mem[14U] = 0xc7U;
    vlSelfRef.tb_top__DOT__mem[15U] = 0x3cU;
    vlSelfRef.tb_top__DOT__mem[16U] = 0xaaU;
    vlSelfRef.tb_top__DOT__mem[17U] = 0x68U;
    vlSelfRef.tb_top__DOT__mem[18U] = 0x20U;
    vlSelfRef.tb_top__DOT__mem[19U] = 0U;
    vlSelfRef.tb_top__DOT__mem[32U] = 0x46U;
    vlSelfRef.tb_top__DOT__mem[33U] = 0x28U;
    vlSelfRef.tb_top__DOT__mem[34U] = 0U;
    vlSelfRef.tb_top__DOT__mem[35U] = 6U;
    vlSelfRef.tb_top__DOT__mem[36U] = 0x55U;
    vlSelfRef.tb_top__DOT__mem[37U] = 0x51U;
    vlSelfRef.tb_top__DOT__mem[38U] = 0U;
    vlSelfRef.tb_top__DOT__mem[40U] = 2U;
    vlSelfRef.tb_top__DOT__mem[41U] = 3U;
    vlSelfRef.tb_top__DOT__mem[42U] = 0x2bU;
    vlSelfRef.tb_top__DOT__mem[56U] = 7U;
    tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0 = 2U;
    while (VL_LTS_III(32, 0U, tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0)) {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             71);
        tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0 
            = (tb_top__DOT__unnamedblk1_1__DOT____Vrepeat0 
               - (IData)(1U));
    }
    vlSelfRef.tb_top__DOT__rst_n = 1U;
    __Vtask_tb_top__DOT__step__0__expected_a = 0x7fU;
    __Vtask_tb_top__DOT__step__0__expected_pc = 2U;
    __Vtask_tb_top__DOT__step__0__cycles = 0;
    __Vtask_tb_top__DOT__step__0__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__0__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__0__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__0__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__0__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__0__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__0__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__0__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__1__expected_a = 0x80U;
    __Vtask_tb_top__DOT__step__1__expected_pc = 4U;
    __Vtask_tb_top__DOT__step__1__cycles = 0;
    __Vtask_tb_top__DOT__step__1__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__1__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__1__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__1__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__1__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__1__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__1__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__1__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    if (VL_UNLIKELY(((1U & (~ (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sign)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:75: Assertion failed in %m: ADI sign\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 75, "", false);
    }
    __Vtask_tb_top__DOT__step__2__expected_a = 0x80U;
    __Vtask_tb_top__DOT__step__2__expected_pc = 6U;
    __Vtask_tb_top__DOT__step__2__cycles = 0;
    __Vtask_tb_top__DOT__step__2__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__2__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__2__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__2__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__2__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__2__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__2__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__2__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__3__expected_a = 5U;
    __Vtask_tb_top__DOT__step__3__expected_pc = 7U;
    __Vtask_tb_top__DOT__step__3__cycles = 0;
    __Vtask_tb_top__DOT__step__3__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__3__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__3__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__3__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__3__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__3__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__3__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__3__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__4__expected_a = 5U;
    __Vtask_tb_top__DOT__step__4__expected_pc = 8U;
    __Vtask_tb_top__DOT__step__4__cycles = 0;
    __Vtask_tb_top__DOT__step__4__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__4__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__4__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__4__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__4__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__4__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__4__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__4__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__5__expected_a = 5U;
    __Vtask_tb_top__DOT__step__5__expected_pc = 0x000aU;
    __Vtask_tb_top__DOT__step__5__cycles = 0;
    __Vtask_tb_top__DOT__step__5__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__5__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__5__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__5__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__5__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__5__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__5__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__5__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__6__expected_a = 5U;
    __Vtask_tb_top__DOT__step__6__expected_pc = 0x000cU;
    __Vtask_tb_top__DOT__step__6__cycles = 0;
    __Vtask_tb_top__DOT__step__6__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__6__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__6__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__6__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__6__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__6__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__6__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__6__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__7__expected_a = 5U;
    __Vtask_tb_top__DOT__step__7__expected_pc = 0x000eU;
    __Vtask_tb_top__DOT__step__7__cycles = 0;
    __Vtask_tb_top__DOT__step__7__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__7__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__7__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__7__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__7__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__7__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__7__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__7__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    if (VL_UNLIKELY((((0xaaU != vlSelfRef.tb_top__DOT__mem[8192U]) 
                      | (1U != vlSelfRef.tb_top__DOT__writes))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:82: Assertion failed in %m: LMI memory write\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 82, "", false);
    }
    __Vtask_tb_top__DOT__step__8__expected_a = 0xaaU;
    __Vtask_tb_top__DOT__step__8__expected_pc = 0x000fU;
    __Vtask_tb_top__DOT__step__8__cycles = 0;
    __Vtask_tb_top__DOT__step__8__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__8__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__8__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__8__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__8__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__8__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__8__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__8__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__9__expected_a = 0xaaU;
    __Vtask_tb_top__DOT__step__9__expected_pc = 0x0011U;
    __Vtask_tb_top__DOT__step__9__cycles = 0;
    __Vtask_tb_top__DOT__step__9__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__9__cycles = ((IData)(1U) 
                                                + __Vtask_tb_top__DOT__step__9__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__9__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__9__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__9__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__9__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__9__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    if (VL_UNLIKELY(((1U & (~ (IData)(vlSelfRef.tb_top__DOT__dut__DOT__zero)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:85: Assertion failed in %m: CPI zero\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 85, "", false);
    }
    __Vtask_tb_top__DOT__step__10__expected_a = 0xaaU;
    __Vtask_tb_top__DOT__step__10__expected_pc = 0x0020U;
    __Vtask_tb_top__DOT__step__10__cycles = 0;
    __Vtask_tb_top__DOT__step__10__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__10__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__10__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__10__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__10__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__10__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__10__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__10__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__11__expected_a = 0xaaU;
    __Vtask_tb_top__DOT__step__11__expected_pc = 0x0028U;
    __Vtask_tb_top__DOT__step__11__cycles = 0;
    __Vtask_tb_top__DOT__step__11__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__11__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__11__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__11__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__11__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__11__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__11__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__11__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__12__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__12__expected_pc = 0x0029U;
    __Vtask_tb_top__DOT__step__12__cycles = 0;
    __Vtask_tb_top__DOT__step__12__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__12__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__12__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__12__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__12__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__12__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__12__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__12__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__13__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__13__expected_pc = 0x002aU;
    __Vtask_tb_top__DOT__step__13__cycles = 0;
    __Vtask_tb_top__DOT__step__13__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__13__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__13__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__13__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__13__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__13__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__13__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__13__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__14__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__14__expected_pc = 0x0023U;
    __Vtask_tb_top__DOT__step__14__cycles = 0;
    __Vtask_tb_top__DOT__step__14__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__14__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__14__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__14__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__14__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__14__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__14__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__14__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__15__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__15__expected_pc = 0x0025U;
    __Vtask_tb_top__DOT__step__15__cycles = 0;
    __Vtask_tb_top__DOT__step__15__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__15__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__15__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__15__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__15__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__15__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__15__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__15__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__16__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__16__expected_pc = 0x0026U;
    __Vtask_tb_top__DOT__step__16__cycles = 0;
    __Vtask_tb_top__DOT__step__16__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__16__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__16__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__16__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__16__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__16__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__16__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__16__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    if (VL_UNLIKELY(((1U != vlSelfRef.tb_top__DOT__outs)))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:93: Assertion failed in %m: OUT missing\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 93, "", false);
    }
    __Vtask_tb_top__DOT__step__17__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__17__expected_pc = 0x0027U;
    __Vtask_tb_top__DOT__step__17__cycles = 0;
    __Vtask_tb_top__DOT__step__17__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__17__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__17__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__17__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__17__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__17__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__17__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__17__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    vlSelfRef.tb_top__DOT__interrupt_opcode = 0x3dU;
    vlSelfRef.tb_top__DOT__interrupt_i = 1U;
    __Vtask_tb_top__DOT__step__18__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__18__expected_pc = 0x0038U;
    __Vtask_tb_top__DOT__step__18__cycles = 0;
    __Vtask_tb_top__DOT__step__18__cycles = 0U;
    if (VL_UNLIKELY(((8U != (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:95: Assertion failed in %m: HLT missing\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 95, "", false);
    }
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__18__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__18__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__18__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__18__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__18__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__18__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__18__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    vlSelfRef.tb_top__DOT__interrupt_i = 0U;
    __Vtask_tb_top__DOT__step__19__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__19__expected_pc = 0x0027U;
    __Vtask_tb_top__DOT__step__19__cycles = 0;
    __Vtask_tb_top__DOT__step__19__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__19__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__19__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__19__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__19__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__19__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__19__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__19__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    __Vtask_tb_top__DOT__step__20__expected_a = 0x55U;
    __Vtask_tb_top__DOT__step__20__expected_pc = 0x0028U;
    __Vtask_tb_top__DOT__step__20__cycles = 0;
    __Vtask_tb_top__DOT__step__20__cycles = 0U;
    do {
        Vtb_top___024root____VbeforeTrig_h71ae4e14__0(vlSelf, 
                                                      "@(negedge tb_top.clk)");
        co_await vlSelfRef.__VtrigSched_h71ae4e14__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_top.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                                             40);
        __Vtask_tb_top__DOT__step__20__cycles = ((IData)(1U) 
                                                 + __Vtask_tb_top__DOT__step__20__cycles);
        if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, __Vtask_tb_top__DOT__step__20__cycles)))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:42: Assertion failed in %m: instruction timeout at PC %04x\n",4, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc));
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 42, "", false);
        }
    } while ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__retire))));
    if (VL_UNLIKELY(((((IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc) 
                       != (IData)(__Vtask_tb_top__DOT__step__20__expected_pc)) 
                      | (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                         != (IData)(__Vtask_tb_top__DOT__step__20__expected_a)))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:45: Assertion failed in %m: PC/A expected %04x/%02x got %04x/%02x\n",7, 'M',vlSymsp->name(),"tb_top.step", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1), '#',14,(IData)(__Vtask_tb_top__DOT__step__20__expected_pc)
                     , '#',8,__Vtask_tb_top__DOT__step__20__expected_a
                     , '#',14,(IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                     , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 45, "", false);
    }
    if (VL_UNLIKELY(((8U != (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:102: Assertion failed in %m: second HLT missing\n",3, 'M',vlSymsp->name(),"tb_top", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 102, "", false);
    }
    VL_WRITEF_NX("PASS: exact PC, ALU, memory, branch, call, conditional return, I/O, HLT, interrupt\n",0);
    VL_FINISH_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 104, "");
    co_return;
}

VlCoroutine Vtb_top___024root___eval_initial__TOP__Vtiming__1(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(5ULL, 
                                             nullptr, 
                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 
                                             3);
        vlSelfRef.tb_top__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb_top__DOT__clk)));
    }
    co_return;
}

bool Vtb_top___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

bool Vtb_top___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vtb_top___024root___nba_sequent__TOP__0(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___nba_sequent__TOP__0\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*2:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value = 0;
    SData/*8:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__22__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__22__value = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__23__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__23__value = 0;
    CData/*1:0*/ __Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which;
    __Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which = 0;
    CData/*2:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value = 0;
    SData/*8:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__26__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__26__value = 0;
    CData/*1:0*/ __Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which;
    __Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which = 0;
    CData/*2:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value = 0;
    SData/*8:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__29__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__29__value = 0;
    CData/*2:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value = 0;
    SData/*8:0*/ __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp;
    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__31__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__31__value = 0;
    CData/*7:0*/ __Vtask_tb_top__DOT__dut__DOT__set_szp__32__value;
    __Vtask_tb_top__DOT__dut__DOT__set_szp__32__value = 0;
    CData/*1:0*/ __Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which;
    __Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which = 0;
    CData/*3:0*/ __Vdly__tb_top__DOT__dut__DOT__state;
    __Vdly__tb_top__DOT__dut__DOT__state = 0;
    CData/*7:0*/ __Vdly__tb_top__DOT__dut__DOT__op;
    __Vdly__tb_top__DOT__dut__DOT__op = 0;
    SData/*13:0*/ __Vdly__tb_top__DOT__dut__DOT__pc;
    __Vdly__tb_top__DOT__dut__DOT__pc = 0;
    CData/*0:0*/ __Vdly__tb_top__DOT__dut__DOT__carry;
    __Vdly__tb_top__DOT__dut__DOT__carry = 0;
    CData/*0:0*/ __Vdly__tb_top__DOT__dut__DOT__zero;
    __Vdly__tb_top__DOT__dut__DOT__zero = 0;
    CData/*0:0*/ __Vdly__tb_top__DOT__dut__DOT__sign;
    __Vdly__tb_top__DOT__dut__DOT__sign = 0;
    CData/*0:0*/ __Vdly__tb_top__DOT__dut__DOT__parity;
    __Vdly__tb_top__DOT__dut__DOT__parity = 0;
    CData/*2:0*/ __Vdly__tb_top__DOT__dut__DOT__sp;
    __Vdly__tb_top__DOT__dut__DOT__sp = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__mem__v0;
    __VdlyVal__tb_top__DOT__mem__v0 = 0;
    SData/*13:0*/ __VdlyDim0__tb_top__DOT__mem__v0;
    __VdlyDim0__tb_top__DOT__mem__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__mem__v0;
    __VdlySet__tb_top__DOT__mem__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v0;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v0 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v0;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v0;
    __VdlySet__tb_top__DOT__dut__DOT__r__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v1;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v1 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v1;
    __VdlySet__tb_top__DOT__dut__DOT__r__v1 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v2;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v2 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v2;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v2 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v2;
    __VdlySet__tb_top__DOT__dut__DOT__r__v2 = 0;
    SData/*13:0*/ __VdlyVal__tb_top__DOT__dut__DOT__stack__v0;
    __VdlyVal__tb_top__DOT__dut__DOT__stack__v0 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__stack__v0;
    __VdlyDim0__tb_top__DOT__dut__DOT__stack__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__stack__v0;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v3;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v3 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v3;
    __VdlySet__tb_top__DOT__dut__DOT__r__v3 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v4;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v4 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v4;
    __VdlySet__tb_top__DOT__dut__DOT__r__v4 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v5;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v5 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v5;
    __VdlySet__tb_top__DOT__dut__DOT__r__v5 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v6;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v6 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v6;
    __VdlySet__tb_top__DOT__dut__DOT__r__v6 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v7;
    __VdlySet__tb_top__DOT__dut__DOT__r__v7 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v8;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v8 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v8;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v8 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v8;
    __VdlySet__tb_top__DOT__dut__DOT__r__v8 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v9;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v9 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v9;
    __VdlySet__tb_top__DOT__dut__DOT__r__v9 = 0;
    SData/*13:0*/ __VdlyVal__tb_top__DOT__dut__DOT__stack__v1;
    __VdlyVal__tb_top__DOT__dut__DOT__stack__v1 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__stack__v1;
    __VdlyDim0__tb_top__DOT__dut__DOT__stack__v1 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__stack__v1;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v1 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v10;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v10 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v10;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v10 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v10;
    __VdlySet__tb_top__DOT__dut__DOT__r__v10 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v11;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v11 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v11;
    __VdlySet__tb_top__DOT__dut__DOT__r__v11 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v12;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v12 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v12;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v12 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v12;
    __VdlySet__tb_top__DOT__dut__DOT__r__v12 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v13;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v13 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v13;
    __VdlySet__tb_top__DOT__dut__DOT__r__v13 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v14;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v14 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__r__v14;
    __VdlyDim0__tb_top__DOT__dut__DOT__r__v14 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v14;
    __VdlySet__tb_top__DOT__dut__DOT__r__v14 = 0;
    SData/*13:0*/ __VdlyVal__tb_top__DOT__dut__DOT__stack__v2;
    __VdlyVal__tb_top__DOT__dut__DOT__stack__v2 = 0;
    CData/*2:0*/ __VdlyDim0__tb_top__DOT__dut__DOT__stack__v2;
    __VdlyDim0__tb_top__DOT__dut__DOT__stack__v2 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__stack__v2;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v2 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v15;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v15 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v15;
    __VdlySet__tb_top__DOT__dut__DOT__r__v15 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v16;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v16 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v16;
    __VdlySet__tb_top__DOT__dut__DOT__r__v16 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v17;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v17 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v17;
    __VdlySet__tb_top__DOT__dut__DOT__r__v17 = 0;
    CData/*7:0*/ __VdlyVal__tb_top__DOT__dut__DOT__r__v18;
    __VdlyVal__tb_top__DOT__dut__DOT__r__v18 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v18;
    __VdlySet__tb_top__DOT__dut__DOT__r__v18 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v19;
    __VdlySet__tb_top__DOT__dut__DOT__r__v19 = 0;
    CData/*0:0*/ __VdlySet__tb_top__DOT__dut__DOT__r__v20;
    __VdlySet__tb_top__DOT__dut__DOT__r__v20 = 0;
    // Body
    __Vdly__tb_top__DOT__dut__DOT__op = vlSelfRef.tb_top__DOT__dut__DOT__op;
    __Vdly__tb_top__DOT__dut__DOT__carry = vlSelfRef.tb_top__DOT__dut__DOT__carry;
    __Vdly__tb_top__DOT__dut__DOT__zero = vlSelfRef.tb_top__DOT__dut__DOT__zero;
    __Vdly__tb_top__DOT__dut__DOT__sign = vlSelfRef.tb_top__DOT__dut__DOT__sign;
    __Vdly__tb_top__DOT__dut__DOT__parity = vlSelfRef.tb_top__DOT__dut__DOT__parity;
    __Vdly__tb_top__DOT__dut__DOT__sp = vlSelfRef.tb_top__DOT__dut__DOT__sp;
    __Vdly__tb_top__DOT__dut__DOT__pc = vlSelfRef.tb_top__DOT__dut__DOT__pc;
    __Vdly__tb_top__DOT__dut__DOT__state = vlSelfRef.tb_top__DOT__dut__DOT__state;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v0 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v1 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__stack__v2 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v0 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v1 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v2 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v3 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v4 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v5 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v6 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v7 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v8 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v9 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v10 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v11 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v12 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v13 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v14 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v15 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v16 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v17 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v18 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v19 = 0U;
    __VdlySet__tb_top__DOT__dut__DOT__r__v20 = 0U;
    __VdlySet__tb_top__DOT__mem__v0 = 0U;
    if (vlSelfRef.tb_top__DOT__mem_write) {
        vlSelfRef.tb_top__DOT__writes = ((IData)(1U) 
                                         + vlSelfRef.tb_top__DOT__writes);
        __VdlyVal__tb_top__DOT__mem__v0 = ((8U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                            ? vlSelfRef.tb_top__DOT__dut__DOT__r[0U]
                                            : ((4U 
                                                & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                                ? (
                                                   (2U 
                                                    & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                                    ? vlSelfRef.tb_top__DOT__dut__DOT__r[0U]
                                                    : 
                                                   ((1U 
                                                     & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                                     ? 
                                                    ((0x3eU 
                                                      == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op))
                                                      ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__immediate)
                                                      : 
                                                     ((6U 
                                                       >= 
                                                       (7U 
                                                        & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op)))
                                                       ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                                      [
                                                      (7U 
                                                       & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op))]
                                                       : 0U))
                                                     : vlSelfRef.tb_top__DOT__dut__DOT__r[0U]))
                                                : vlSelfRef.tb_top__DOT__dut__DOT__r[0U]));
        __VdlyDim0__tb_top__DOT__mem__v0 = vlSelfRef.tb_top__DOT__mem_addr;
        __VdlySet__tb_top__DOT__mem__v0 = 1U;
    }
    if ((IData)((7U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)))) {
        if (VL_UNLIKELY(((IData)(((0x10U != (0x3eU 
                                             & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op))) 
                                  | (0x55U != vlSelfRef.tb_top__DOT__dut__DOT__r[0U])))))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_top.sv:29: Assertion failed in %m: OUT mismatch port=%0d data=%02x\n",5, 'M',vlSymsp->name(),"tb_top", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '#',5,(0x0000001fU & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                                 >> 1U))
                         , '#',8,vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_top.sv", 29, "", false);
        }
        vlSelfRef.tb_top__DOT__outs = ((IData)(1U) 
                                       + vlSelfRef.tb_top__DOT__outs);
    }
    if (vlSelfRef.tb_top__DOT__rst_n) {
        vlSelfRef.tb_top__DOT__retire = 0U;
        if ((8U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
            if ((4U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            } else if ((2U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            } else if ((1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            } else if (((0U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)) 
                        | (IData)(vlSelfRef.tb_top__DOT__interrupt_i))) {
                vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code 
                    = ((IData)(vlSelfRef.tb_top__DOT__interrupt_i)
                        ? (IData)(vlSelfRef.tb_top__DOT__interrupt_opcode)
                        : vlSelfRef.tb_top__DOT__mem
                       [vlSelfRef.tb_top__DOT__mem_addr]);
                __Vdly__tb_top__DOT__dut__DOT__op = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code;
                if ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__interrupt_i)))) {
                    __Vdly__tb_top__DOT__dut__DOT__pc 
                        = (0x00003fffU & ((IData)(1U) 
                                          + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
                }
                if ((((0xffU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)) 
                      | (0U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                     | (1U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 8U;
                    vlSelfRef.tb_top__DOT__retire = 1U;
                } else if ((3U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 6U)))) {
                    if ((7U == (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __Vdly__tb_top__DOT__dut__DOT__state = 5U;
                    } else if ((7U == (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                        __Vdly__tb_top__DOT__dut__DOT__state = 4U;
                    } else {
                        if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                          >> 3U)))) {
                            __VdlyVal__tb_top__DOT__dut__DOT__r__v0 
                                = ((6U >= (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))
                                    ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                   [(7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))]
                                    : 0U);
                            __VdlyDim0__tb_top__DOT__dut__DOT__r__v0 
                                = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 3U));
                            __VdlySet__tb_top__DOT__dut__DOT__r__v0 = 1U;
                        }
                        vlSelfRef.tb_top__DOT__retire = 1U;
                        __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                    }
                } else if ((2U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 6U)))) {
                    if ((7U == (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                        __Vdly__tb_top__DOT__dut__DOT__state = 4U;
                    } else {
                        __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value 
                            = ((6U >= (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))
                                ? vlSelfRef.tb_top__DOT__dut__DOT__r
                               [(7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))]
                                : 0U);
                        __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp 
                            = (0x000001ffU & ((4U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                               ? ((2U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                   ? 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                    ? 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value))
                                                    : 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    | (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value)))
                                                   : 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                    ? 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    ^ (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value))
                                                    : 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value))))
                                               : ((2U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                   ? 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                    ? 
                                                   ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                     - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value)) 
                                                    - (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                    : 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value)))
                                                   : 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))
                                                    ? 
                                                   ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                     + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value)) 
                                                    + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                    : 
                                                   (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__value))))));
                        vlSelfRef.tb_top__DOT__retire = 1U;
                        __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                        __Vdly__tb_top__DOT__dut__DOT__carry 
                            = (IData)((((IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp) 
                                        >> 8U) & (~ 
                                                  ((4U 
                                                    <= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind)) 
                                                   & (6U 
                                                      >= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))))));
                        __Vtask_tb_top__DOT__dut__DOT__set_szp__22__value 
                            = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp));
                        __Vdly__tb_top__DOT__dut__DOT__zero 
                            = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__22__value));
                        __Vdly__tb_top__DOT__dut__DOT__sign 
                            = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__22__value) 
                                     >> 7U));
                        __Vdly__tb_top__DOT__dut__DOT__parity 
                            = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__22__value)));
                        if ((7U != (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__kind))) {
                            __VdlyVal__tb_top__DOT__dut__DOT__r__v1 
                                = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__21__tmp));
                            __VdlySet__tb_top__DOT__dut__DOT__r__v1 = 1U;
                        }
                    }
                } else if (((6U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                            | (4U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 1U;
                } else if (((0U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                            | (1U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                    vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8 
                        = (0x000000ffU & ((1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))
                                           ? (((6U 
                                                >= 
                                                (7U 
                                                 & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                    >> 3U)))
                                                ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                               [(7U 
                                                 & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                    >> 3U))]
                                                : 0U) 
                                              - (IData)(1U))
                                           : ((IData)(1U) 
                                              + ((6U 
                                                  >= 
                                                  (7U 
                                                   & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U)))
                                                  ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                                 [(7U 
                                                   & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U))]
                                                  : 0U))));
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v2 
                            = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8;
                        __VdlyDim0__tb_top__DOT__dut__DOT__r__v2 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v2 = 1U;
                    }
                    __Vtask_tb_top__DOT__dut__DOT__set_szp__23__value 
                        = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8;
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_top__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__23__value));
                    __Vdly__tb_top__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__23__value) 
                                 >> 7U));
                    __Vdly__tb_top__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__23__value)));
                } else if ((IData)((0x40U == (0xc1U 
                                              & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 2U;
                } else if ((7U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_top__DOT__dut__DOT__sp 
                        = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                 - (IData)(1U)));
                    __Vdly__tb_top__DOT__dut__DOT__pc 
                        = vlSelfRef.tb_top__DOT__dut__DOT__stack
                        [(7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                - (IData)(1U)))];
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                } else if ((3U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which 
                        = (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_0__flag_selected 
                        = ((0U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which))
                            ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry)
                            : ((1U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which))
                                ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__zero)
                                : ((2U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__24__which))
                                    ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sign)
                                    : (IData)(vlSelfRef.tb_top__DOT__dut__DOT__parity))));
                    if (((1U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                >> 5U)) == (IData)(vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_0__flag_selected))) {
                        __Vdly__tb_top__DOT__dut__DOT__sp 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                     - (IData)(1U)));
                        __Vdly__tb_top__DOT__dut__DOT__pc 
                            = vlSelfRef.tb_top__DOT__dut__DOT__stack
                            [(7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                    - (IData)(1U)))];
                    }
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                } else if ((5U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __VdlyVal__tb_top__DOT__dut__DOT__stack__v0 
                        = (0x00003fffU & ((IData)(vlSelfRef.tb_top__DOT__interrupt_i)
                                           ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                                           : ((IData)(1U) 
                                              + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc))));
                    __VdlyDim0__tb_top__DOT__dut__DOT__stack__v0 
                        = vlSelfRef.tb_top__DOT__dut__DOT__sp;
                    __VdlySet__tb_top__DOT__dut__DOT__stack__v0 = 1U;
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_top__DOT__dut__DOT__sp 
                        = (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp)));
                    __Vdly__tb_top__DOT__dut__DOT__pc 
                        = (0x00000038U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code));
                } else if ((0x41U == (0xc1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_top__DOT__dut__DOT__state 
                        = ((0U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 4U))) ? 6U
                            : 7U);
                } else {
                    if ((2U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_top__DOT__dut__DOT__carry 
                            = (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                     >> 7U));
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v3 
                            = ((0x000000feU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                               << 1U)) 
                               | (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                        >> 7U)));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v3 = 1U;
                    } else if ((0x0aU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_top__DOT__dut__DOT__carry 
                            = (1U & vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v4 
                            = ((0x00000080U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                               << 7U)) 
                               | (0x0000007fU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                 >> 1U)));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v4 = 1U;
                    } else if ((0x12U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_top__DOT__dut__DOT__carry 
                            = (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                     >> 7U));
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v5 
                            = ((0x000000feU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                               << 1U)) 
                               | (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v5 = 1U;
                    } else if ((0x1aU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_top__DOT__dut__DOT__carry 
                            = (1U & vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v6 
                            = (((IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry) 
                                << 7U) | (0x0000007fU 
                                          & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                             >> 1U)));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v6 = 1U;
                    }
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                }
            }
        } else if ((4U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
            if ((2U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
                if ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)))) {
                    __VdlySet__tb_top__DOT__dut__DOT__r__v7 = 1U;
                }
            } else if ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)))) {
                if ((3U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                  >> 6U)))) {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                      >> 3U)))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v8 
                            = vlSelfRef.tb_top__DOT__mem
                            [vlSelfRef.tb_top__DOT__mem_addr];
                        __VdlyDim0__tb_top__DOT__dut__DOT__r__v8 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                     >> 3U));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v8 = 1U;
                    }
                } else {
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value 
                        = vlSelfRef.tb_top__DOT__mem
                        [vlSelfRef.tb_top__DOT__mem_addr];
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind 
                        = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                 >> 3U));
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp 
                        = (0x000001ffU & ((4U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                           ? ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                                   ? 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   | (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                                   ? 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   ^ (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value))))
                                           : ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value)) 
                                                   - (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value)) 
                                                   + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__value))))));
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (IData)((((IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp) 
                                    >> 8U) & (~ ((4U 
                                                  <= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind)) 
                                                 & (6U 
                                                    >= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))))));
                    __Vtask_tb_top__DOT__dut__DOT__set_szp__26__value 
                        = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp));
                    __Vdly__tb_top__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__26__value));
                    __Vdly__tb_top__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__26__value) 
                                 >> 7U));
                    __Vdly__tb_top__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__26__value)));
                    if ((7U != (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__kind))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v9 
                            = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__25__tmp));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v9 = 1U;
                    }
                }
            }
            vlSelfRef.tb_top__DOT__retire = 1U;
            __Vdly__tb_top__DOT__dut__DOT__state = 0U;
        } else if ((2U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
            if ((1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
                __Vdly__tb_top__DOT__dut__DOT__pc = 
                    (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which 
                    = (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                             >> 3U));
                vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_1__flag_selected 
                    = ((0U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which))
                        ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry)
                        : ((1U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which))
                            ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__zero)
                            : ((2U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__27__which))
                                ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sign)
                                : (IData)(vlSelfRef.tb_top__DOT__dut__DOT__parity))));
                if ((1U & (((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                            >> 2U) | ((1U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                             >> 5U)) 
                                      == (IData)(vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_1__flag_selected))))) {
                    if ((2U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__stack__v1 
                            = (0x00003fffU & ((IData)(1U) 
                                              + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
                        __VdlyDim0__tb_top__DOT__dut__DOT__stack__v1 
                            = vlSelfRef.tb_top__DOT__dut__DOT__sp;
                        __VdlySet__tb_top__DOT__dut__DOT__stack__v1 = 1U;
                        __Vdly__tb_top__DOT__dut__DOT__sp 
                            = (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp)));
                    }
                    __Vdly__tb_top__DOT__dut__DOT__pc 
                        = ((0x00003f00U & (vlSelfRef.tb_top__DOT__mem
                                           [vlSelfRef.tb_top__DOT__mem_addr] 
                                           << 8U)) 
                           | (IData)(vlSelfRef.tb_top__DOT__dut__DOT__addr_low));
                }
            } else {
                __Vdly__tb_top__DOT__dut__DOT__pc = 
                    (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
                vlSelfRef.tb_top__DOT__dut__DOT__addr_low 
                    = vlSelfRef.tb_top__DOT__mem[vlSelfRef.tb_top__DOT__mem_addr];
                __Vdly__tb_top__DOT__dut__DOT__state = 3U;
            }
        } else if ((1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))) {
            __Vdly__tb_top__DOT__dut__DOT__pc = (0x00003fffU 
                                                 & ((IData)(1U) 
                                                    + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
            if ((6U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__op)))) {
                if ((7U == (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                  >> 3U)))) {
                    vlSelfRef.tb_top__DOT__dut__DOT__immediate 
                        = vlSelfRef.tb_top__DOT__mem
                        [vlSelfRef.tb_top__DOT__mem_addr];
                    __Vdly__tb_top__DOT__dut__DOT__state = 5U;
                } else {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                      >> 3U)))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v10 
                            = vlSelfRef.tb_top__DOT__mem
                            [vlSelfRef.tb_top__DOT__mem_addr];
                        __VdlyDim0__tb_top__DOT__dut__DOT__r__v10 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                                     >> 3U));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v10 = 1U;
                    }
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                    vlSelfRef.tb_top__DOT__retire = 1U;
                }
            } else {
                __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value 
                    = vlSelfRef.tb_top__DOT__mem[vlSelfRef.tb_top__DOT__mem_addr];
                __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind 
                    = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__op) 
                             >> 3U));
                __Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp 
                    = (0x000001ffU & ((4U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                       ? ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                           ? ((1U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                               ? (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value))
                                               : (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  | (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value)))
                                           : ((1U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                               ? (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  ^ (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value))
                                               : (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value))))
                                       : ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                           ? ((1U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                               ? ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value)) 
                                                  - (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                               : (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value)))
                                           : ((1U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))
                                               ? ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value)) 
                                                  + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                               : (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                  + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__value))))));
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__carry 
                    = (IData)((((IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp) 
                                >> 8U) & (~ ((4U <= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind)) 
                                             & (6U 
                                                >= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))))));
                __Vtask_tb_top__DOT__dut__DOT__set_szp__29__value 
                    = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp));
                __Vdly__tb_top__DOT__dut__DOT__zero 
                    = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__29__value));
                __Vdly__tb_top__DOT__dut__DOT__sign 
                    = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__29__value) 
                             >> 7U));
                __Vdly__tb_top__DOT__dut__DOT__parity 
                    = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__29__value)));
                if ((7U != (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__kind))) {
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v11 
                        = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__28__tmp));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v11 = 1U;
                }
            }
        } else if (((0U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)) 
                    | (IData)(vlSelfRef.tb_top__DOT__interrupt_i))) {
            vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code 
                = ((IData)(vlSelfRef.tb_top__DOT__interrupt_i)
                    ? (IData)(vlSelfRef.tb_top__DOT__interrupt_opcode)
                    : vlSelfRef.tb_top__DOT__mem[vlSelfRef.tb_top__DOT__mem_addr]);
            __Vdly__tb_top__DOT__dut__DOT__op = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code;
            if ((1U & (~ (IData)(vlSelfRef.tb_top__DOT__interrupt_i)))) {
                __Vdly__tb_top__DOT__dut__DOT__pc = 
                    (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
            }
            if ((((0xffU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)) 
                  | (0U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                 | (1U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 8U;
                vlSelfRef.tb_top__DOT__retire = 1U;
            } else if ((3U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 6U)))) {
                if ((7U == (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                  >> 3U)))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 5U;
                } else if ((7U == (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 4U;
                } else {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v12 
                            = ((6U >= (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))
                                ? vlSelfRef.tb_top__DOT__dut__DOT__r
                               [(7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))]
                                : 0U);
                        __VdlyDim0__tb_top__DOT__dut__DOT__r__v12 
                            = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v12 = 1U;
                    }
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                }
            } else if ((2U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 6U)))) {
                if ((7U == (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_top__DOT__dut__DOT__state = 4U;
                } else {
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value 
                        = ((6U >= (7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))
                            ? vlSelfRef.tb_top__DOT__dut__DOT__r
                           [(7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))]
                            : 0U);
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind 
                        = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    __Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp 
                        = (0x000001ffU & ((4U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                           ? ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                                   ? 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   | (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                                   ? 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   ^ (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value))))
                                           : ((2U & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value)) 
                                                   - (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value)) 
                                                   + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__value))))));
                    vlSelfRef.tb_top__DOT__retire = 1U;
                    __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (IData)((((IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp) 
                                    >> 8U) & (~ ((4U 
                                                  <= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind)) 
                                                 & (6U 
                                                    >= (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))))));
                    __Vtask_tb_top__DOT__dut__DOT__set_szp__31__value 
                        = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp));
                    __Vdly__tb_top__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__31__value));
                    __Vdly__tb_top__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__31__value) 
                                 >> 7U));
                    __Vdly__tb_top__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__31__value)));
                    if ((7U != (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__kind))) {
                        __VdlyVal__tb_top__DOT__dut__DOT__r__v13 
                            = (0x000000ffU & (IData)(__Vtask_tb_top__DOT__dut__DOT__execute_alu__30__tmp));
                        __VdlySet__tb_top__DOT__dut__DOT__r__v13 = 1U;
                    }
                }
            } else if (((6U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                        | (4U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 1U;
            } else if (((0U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) 
                        | (1U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8 
                    = (0x000000ffU & ((1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))
                                       ? (((6U >= (7U 
                                                   & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U)))
                                            ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                           [(7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                   >> 3U))]
                                            : 0U) - (IData)(1U))
                                       : ((IData)(1U) 
                                          + ((6U >= 
                                              (7U & 
                                               ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                >> 3U)))
                                              ? vlSelfRef.tb_top__DOT__dut__DOT__r
                                             [(7U & 
                                               ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                                >> 3U))]
                                              : 0U))));
                if ((6U >= (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                  >> 3U)))) {
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v14 
                        = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8;
                    __VdlyDim0__tb_top__DOT__dut__DOT__r__v14 
                        = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v14 = 1U;
                }
                __Vtask_tb_top__DOT__dut__DOT__set_szp__32__value 
                    = vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__tmp8;
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                __Vdly__tb_top__DOT__dut__DOT__zero 
                    = (0U == (IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__32__value));
                __Vdly__tb_top__DOT__dut__DOT__sign 
                    = (1U & ((IData)(__Vtask_tb_top__DOT__dut__DOT__set_szp__32__value) 
                             >> 7U));
                __Vdly__tb_top__DOT__dut__DOT__parity 
                    = (1U & (~ VL_REDXOR_8(__Vtask_tb_top__DOT__dut__DOT__set_szp__32__value)));
            } else if ((IData)((0x40U == (0xc1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))))) {
                __Vdly__tb_top__DOT__dut__DOT__state = 2U;
            } else if ((7U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_top__DOT__dut__DOT__sp = 
                    (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                           - (IData)(1U)));
                __Vdly__tb_top__DOT__dut__DOT__pc = vlSelfRef.tb_top__DOT__dut__DOT__stack
                    [(7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                            - (IData)(1U)))];
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            } else if ((3U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which 
                    = (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                             >> 3U));
                vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_0__flag_selected 
                    = ((0U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which))
                        ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry)
                        : ((1U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which))
                            ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__zero)
                            : ((2U == (IData)(__Vfunc_tb_top__DOT__dut__DOT__flag_selected__33__which))
                                ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sign)
                                : (IData)(vlSelfRef.tb_top__DOT__dut__DOT__parity))));
                if (((1U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                            >> 5U)) == (IData)(vlSelfRef.tb_top__DOT__dut__DOT____VlemCall_0__flag_selected))) {
                    __Vdly__tb_top__DOT__dut__DOT__sp 
                        = (7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                 - (IData)(1U)));
                    __Vdly__tb_top__DOT__dut__DOT__pc 
                        = vlSelfRef.tb_top__DOT__dut__DOT__stack
                        [(7U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp) 
                                - (IData)(1U)))];
                }
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            } else if ((5U == (0xc7U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                __VdlyVal__tb_top__DOT__dut__DOT__stack__v2 
                    = (0x00003fffU & ((IData)(vlSelfRef.tb_top__DOT__interrupt_i)
                                       ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                                       : ((IData)(1U) 
                                          + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc))));
                __VdlyDim0__tb_top__DOT__dut__DOT__stack__v2 
                    = vlSelfRef.tb_top__DOT__dut__DOT__sp;
                __VdlySet__tb_top__DOT__dut__DOT__stack__v2 = 1U;
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
                __Vdly__tb_top__DOT__dut__DOT__sp = 
                    (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sp)));
                __Vdly__tb_top__DOT__dut__DOT__pc = 
                    (0x00000038U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code));
            } else if ((0x41U == (0xc1U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_top__DOT__dut__DOT__state 
                    = ((0U == (3U & ((IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 4U))) ? 6U : 7U);
            } else {
                if ((2U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                 >> 7U));
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v15 
                        = ((0x000000feU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                           << 1U)) 
                           | (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                    >> 7U)));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v15 = 1U;
                } else if ((0x0aU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (1U & vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v16 
                        = ((0x00000080U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                           << 7U)) 
                           | (0x0000007fU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                             >> 1U)));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v16 = 1U;
                } else if ((0x12U == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (1U & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                 >> 7U));
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v17 
                        = ((0x000000feU & (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                           << 1U)) 
                           | (IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v17 = 1U;
                } else if ((0x1aU == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_top__DOT__dut__DOT__carry 
                        = (1U & vlSelfRef.tb_top__DOT__dut__DOT__r[0U]);
                    __VdlyVal__tb_top__DOT__dut__DOT__r__v18 
                        = (((IData)(vlSelfRef.tb_top__DOT__dut__DOT__carry) 
                            << 7U) | (0x0000007fU & 
                                      (vlSelfRef.tb_top__DOT__dut__DOT__r[0U] 
                                       >> 1U)));
                    __VdlySet__tb_top__DOT__dut__DOT__r__v18 = 1U;
                }
                vlSelfRef.tb_top__DOT__retire = 1U;
                __Vdly__tb_top__DOT__dut__DOT__state = 0U;
            }
        }
    } else {
        __VdlySet__tb_top__DOT__dut__DOT__r__v19 = 1U;
        __Vdly__tb_top__DOT__dut__DOT__state = 0U;
        __Vdly__tb_top__DOT__dut__DOT__pc = 0U;
        __Vdly__tb_top__DOT__dut__DOT__sp = 0U;
        __Vdly__tb_top__DOT__dut__DOT__op = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__addr_low = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__immediate = 0U;
        __Vdly__tb_top__DOT__dut__DOT__carry = 0U;
        __Vdly__tb_top__DOT__dut__DOT__zero = 0U;
        __Vdly__tb_top__DOT__dut__DOT__sign = 0U;
        __Vdly__tb_top__DOT__dut__DOT__parity = 0U;
        vlSelfRef.tb_top__DOT__retire = 0U;
        __VdlySet__tb_top__DOT__dut__DOT__r__v20 = 1U;
    }
    vlSelfRef.tb_top__DOT__dut__DOT__carry = __Vdly__tb_top__DOT__dut__DOT__carry;
    vlSelfRef.tb_top__DOT__dut__DOT__zero = __Vdly__tb_top__DOT__dut__DOT__zero;
    vlSelfRef.tb_top__DOT__dut__DOT__sign = __Vdly__tb_top__DOT__dut__DOT__sign;
    vlSelfRef.tb_top__DOT__dut__DOT__parity = __Vdly__tb_top__DOT__dut__DOT__parity;
    vlSelfRef.tb_top__DOT__dut__DOT__sp = __Vdly__tb_top__DOT__dut__DOT__sp;
    if (__VdlySet__tb_top__DOT__mem__v0) {
        vlSelfRef.tb_top__DOT__mem[__VdlyDim0__tb_top__DOT__mem__v0] 
            = __VdlyVal__tb_top__DOT__mem__v0;
    }
    vlSelfRef.tb_top__DOT__dut__DOT__op = __Vdly__tb_top__DOT__dut__DOT__op;
    vlSelfRef.tb_top__DOT__dut__DOT__pc = __Vdly__tb_top__DOT__dut__DOT__pc;
    vlSelfRef.tb_top__DOT__dut__DOT__state = __Vdly__tb_top__DOT__dut__DOT__state;
    if (__VdlySet__tb_top__DOT__dut__DOT__stack__v0) {
        vlSelfRef.tb_top__DOT__dut__DOT__stack[__VdlyDim0__tb_top__DOT__dut__DOT__stack__v0] 
            = __VdlyVal__tb_top__DOT__dut__DOT__stack__v0;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__stack__v1) {
        vlSelfRef.tb_top__DOT__dut__DOT__stack[__VdlyDim0__tb_top__DOT__dut__DOT__stack__v1] 
            = __VdlyVal__tb_top__DOT__dut__DOT__stack__v1;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__stack__v2) {
        vlSelfRef.tb_top__DOT__dut__DOT__stack[__VdlyDim0__tb_top__DOT__dut__DOT__stack__v2] 
            = __VdlyVal__tb_top__DOT__dut__DOT__stack__v2;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v0) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v0] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v0;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v1) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v1;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v2) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v2] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v2;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v3) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v3;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v4) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v4;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v5) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v5;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v6) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v6;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v7) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = 0x37U;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v8) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v8] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v8;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v9) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v9;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v10) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v10] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v10;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v11) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v11;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v12) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v12] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v12;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v13) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v13;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v14) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[__VdlyDim0__tb_top__DOT__dut__DOT__r__v14] 
            = __VdlyVal__tb_top__DOT__dut__DOT__r__v14;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v15) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v15;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v16) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v16;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v17) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v17;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v18) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = __VdlyVal__tb_top__DOT__dut__DOT__r__v18;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v19) {
        vlSelfRef.tb_top__DOT__dut__DOT__r[0U] = 0U;
    }
    if (__VdlySet__tb_top__DOT__dut__DOT__r__v20) {
        vlSelfRef.tb_top__DOT__dut__DOT__stack[0U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[1U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[2U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[3U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[4U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[5U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[6U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__stack[7U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[1U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[2U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[3U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[4U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[5U] = 0U;
        vlSelfRef.tb_top__DOT__dut__DOT__r[6U] = 0U;
    }
    vlSelfRef.tb_top__DOT__mem_write = (IData)((5U 
                                                == (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state)));
    vlSelfRef.tb_top__DOT__mem_addr = ((8U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                        ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                                        : ((4U & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                            ? ((2U 
                                                & (IData)(vlSelfRef.tb_top__DOT__dut__DOT__state))
                                                ? (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)
                                                : (
                                                   (0x00003f00U 
                                                    & (vlSelfRef.tb_top__DOT__dut__DOT__r[5U] 
                                                       << 8U)) 
                                                   | vlSelfRef.tb_top__DOT__dut__DOT__r[6U]))
                                            : (IData)(vlSelfRef.tb_top__DOT__dut__DOT__pc)));
}

void Vtb_top___024root___timing_ready(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___timing_ready\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((2ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready("@(negedge tb_top.clk)");
    }
}

void Vtb_top___024root___timing_resume(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___timing_resume\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VtrigSched_h71ae4e14__0.moveToResumeQueue(
                                                          "@(negedge tb_top.clk)");
    vlSelfRef.__VtrigSched_h71ae4e14__0.resume("@(negedge tb_top.clk)");
    if ((4ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VdlySched.resume();
    }
}

void Vtb_top___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

void Vtb_top___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

void Vtb_top___024root____VbeforeTrig_h71ae4e14__0(Vtb_top___024root* vlSelf, const char* __VeventDescription) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root____VbeforeTrig_h71ae4e14__0\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    VlUnpacked<QData/*63:0*/, 1> __VTmp;
    // Body
    __VTmp[0U] = (QData)((IData)((((~ (IData)(vlSelfRef.tb_top__DOT__clk)) 
                                   & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_top__DOT__clk__0)) 
                                  << 1U)));
    vlSelfRef.__Vtrigprevexpr___TOP__tb_top__DOT__clk__0 
        = vlSelfRef.tb_top__DOT__clk;
    if ((2ULL & __VTmp[0U])) {
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_h71ae4e14__0.ready(__VeventDescription);
    }
    vlSelfRef.__VactTriggeredAcc[0U] = (vlSelfRef.__VactTriggeredAcc[0U] 
                                        | __VTmp[0U]);
}

#ifdef VL_DEBUG
void Vtb_top___024root___eval_debug_assertions(Vtb_top___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_top___024root___eval_debug_assertions\n"); );
    Vtb_top__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
