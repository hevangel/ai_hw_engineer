// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_scelbal.h for the primary calling header

#include "Vtb_scelbal__pch.h"

VlCoroutine Vtb_scelbal___024root___eval_initial__TOP__Vtiming__0(Vtb_scelbal___024root* vlSelf);
VlCoroutine Vtb_scelbal___024root___eval_initial__TOP__Vtiming__1(Vtb_scelbal___024root* vlSelf);

void Vtb_scelbal___024root___eval_initial(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_initial\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_scelbal___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_scelbal___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vtb_scelbal___024root___eval_sample(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_sample\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtb_scelbal___024root___eval_ico(Vtb_scelbal___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_ico\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_scelbal___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vtb_scelbal___024root___timing_ready(Vtb_scelbal___024root* vlSelf);
void Vtb_scelbal___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vtb_scelbal___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);
void Vtb_scelbal___024root___timing_resume(Vtb_scelbal___024root* vlSelf);

bool Vtb_scelbal___024root___eval_act(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_act\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 2U) 
                                                         | ((((~ (IData)(vlSelfRef.tb_scelbal__DOT__clk)) 
                                                              & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0)) 
                                                             << 1U) 
                                                            | ((IData)(vlSelfRef.tb_scelbal__DOT__clk) 
                                                               & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0)))))));
        vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0 
            = vlSelfRef.tb_scelbal__DOT__clk;
    }
    Vtb_scelbal___024root___timing_ready(vlSelf);
    Vtb_scelbal___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_scelbal___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtb_scelbal___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vtb_scelbal___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        Vtb_scelbal___024root___timing_resume(vlSelf);
    }
    return (__VactExecute);
}

bool Vtb_scelbal___024root___eval_inact(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_inact\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 1, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vtb_scelbal___024root___nba_sequent__TOP__0(Vtb_scelbal___024root* vlSelf);
void Vtb_scelbal___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out);

bool Vtb_scelbal___024root___eval_nba(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_nba\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtb_scelbal___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                Vtb_scelbal___024root___nba_sequent__TOP__0(vlSelf);
            }
        }
        Vtb_scelbal___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vtb_scelbal___024root___eval_obs(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_obs\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vtb_scelbal___024root___eval_react(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_react\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vtb_scelbal___024root___eval_postponed(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_postponed\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

void Vtb_scelbal___024root____VbeforeTrig_hebcb83c2__0(Vtb_scelbal___024root* vlSelf, const char* __VeventDescription);

VlCoroutine Vtb_scelbal___024root___eval_initial__TOP__Vtiming__0(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0;
    tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0 = 0;
    IData/*31:0*/ tb_scelbal__DOT__unnamedblk1__DOT__n;
    tb_scelbal__DOT__unnamedblk1__DOT__n = 0;
    IData/*31:0*/ tb_scelbal__DOT__unnamedblk2__DOT__i;
    tb_scelbal__DOT__unnamedblk2__DOT__i = 0;
    VlWide<3>/*95:0*/ __Vtemp_1;
    VlWide<3>/*95:0*/ __Vtemp_2;
    VlWide<3>/*95:0*/ __Vtemp_3;
    VlWide<3>/*95:0*/ __Vtemp_4;
    // Body
    VL_READMEM_N(true, 8, 16384, 0, "design/intel_8008/build/scelbal_mem.hex"s
                 ,  &(vlSelfRef.tb_scelbal__DOT__mem)
                 , 0, ~0ULL);
    VL_READMEM_N(true, 77, 200000, 0, "design/intel_8008/build/scelbal_expected.hex"s
                 ,  &(vlSelfRef.tb_scelbal__DOT__expected)
                 , 0, ~0ULL);
    VL_READMEM_N(true, 8, 16384, 0, "design/intel_8008/build/scelbal_final_mem.hex"s
                 ,  &(vlSelfRef.tb_scelbal__DOT__final_mem)
                 , 0, ~0ULL);
    tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0 = 2U;
    while (VL_LTS_III(32, 0U, tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0)) {
        Vtb_scelbal___024root____VbeforeTrig_hebcb83c2__0(vlSelf, 
                                                          "@(negedge tb_scelbal.clk)");
        co_await vlSelfRef.__VtrigSched_hebcb83c2__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_scelbal.clk)", 
                                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 
                                                             43);
        tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0 
            = (tb_scelbal__DOT__unnamedblk1_1__DOT____Vrepeat0 
               - (IData)(1U));
    }
    vlSelfRef.tb_scelbal__DOT__rst_n = 1U;
    tb_scelbal__DOT__unnamedblk1__DOT__n = 0U;
    while (VL_GTS_III(32, 0x00030d40U, tb_scelbal__DOT__unnamedblk1__DOT__n)) {
        vlSelfRef.tb_scelbal__DOT__cycles = 0U;
        do {
            Vtb_scelbal___024root____VbeforeTrig_hebcb83c2__0(vlSelf, 
                                                              "@(negedge tb_scelbal.clk)");
            co_await vlSelfRef.__VtrigSched_hebcb83c2__0.trigger(0U, 
                                                                 nullptr, 
                                                                 "@(negedge tb_scelbal.clk)", 
                                                                 "/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 
                                                                 48);
            vlSelfRef.tb_scelbal__DOT__cycles = ((IData)(1U) 
                                                 + vlSelfRef.tb_scelbal__DOT__cycles);
            if (VL_UNLIKELY((VL_LTS_III(32, 0x0000000aU, vlSelfRef.tb_scelbal__DOT__cycles)))) {
                VL_WRITEF_NX("[%0t] %%Fatal: tb_scelbal.sv:50: Assertion failed in %m: SCELBAL timeout at instruction %0d PC %04x\n",5, 'M',vlSymsp->name(),"tb_scelbal.unnamedblk1", 'T',-12
                             , '#',64,VL_TIME_UNITED_Q(1)
                             , '~',32,tb_scelbal__DOT__unnamedblk1__DOT__n
                             , '#',14,(IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc));
                VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 50, "", false);
            }
        } while ((1U & (~ (IData)(vlSelfRef.tb_scelbal__DOT__retire))));
        __Vtemp_1[1U] = (((IData)((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                    << 0x00000018U) 
                                   | (QData)((IData)(
                                                     (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                       << 0x00000010U) 
                                                      | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                          << 8U) 
                                                         | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U])))))) 
                          << 7U) | (IData)(((((QData)((IData)(
                                                              (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[3U]) 
                                                                << 8U) 
                                                               | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[4U]))) 
                                              << 0x00000017U) 
                                             | (QData)((IData)(
                                                               (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U]) 
                                                                 << 0x0000000fU) 
                                                                | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]) 
                                                                    << 7U) 
                                                                   | ((((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                                                                        << 6U) 
                                                                       | ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero) 
                                                                          << 5U)) 
                                                                      | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign) 
                                                                          << 4U) 
                                                                         | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity) 
                                                                             << 3U) 
                                                                            | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp))))))))) 
                                            >> 0x00000020U)));
        if ((0x00030d3fU >= (0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n))) {
            __Vtemp_2[0U] = vlSelfRef.tb_scelbal__DOT__expected
                [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][0U];
            __Vtemp_2[1U] = vlSelfRef.tb_scelbal__DOT__expected
                [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][1U];
            __Vtemp_2[2U] = vlSelfRef.tb_scelbal__DOT__expected
                [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][2U];
        } else {
            __Vtemp_2[0U] = 0U;
            __Vtemp_2[1U] = 0U;
            __Vtemp_2[2U] = 0U;
        }
        if (VL_UNLIKELY(((0U != ((((IData)((((QData)((IData)(
                                                             (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[3U]) 
                                                               << 8U) 
                                                              | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[4U]))) 
                                             << 0x00000017U) 
                                            | (QData)((IData)(
                                                              (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U]) 
                                                                << 0x0000000fU) 
                                                               | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]) 
                                                                   << 7U) 
                                                                  | ((((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                                                                       << 6U) 
                                                                      | ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero) 
                                                                         << 5U)) 
                                                                     | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign) 
                                                                         << 4U) 
                                                                        | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity) 
                                                                            << 3U) 
                                                                           | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp)))))))))) 
                                   ^ __Vtemp_2[0U]) 
                                  | (__Vtemp_1[1U] 
                                     ^ __Vtemp_2[1U])) 
                                 | ((((IData)((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                                << 0x00000018U) 
                                               | (QData)((IData)(
                                                                 (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                                   << 0x00000010U) 
                                                                  | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                                      << 8U) 
                                                                     | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U])))))) 
                                      >> 0x00000019U) 
                                     | ((IData)(((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                                   << 0x00000018U) 
                                                  | (QData)((IData)(
                                                                    (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                                      << 0x00000010U) 
                                                                     | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                                         << 8U) 
                                                                        | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U]))))) 
                                                 >> 0x00000020U)) 
                                        << 7U)) ^ __Vtemp_2[2U])))))) {
            if ((0x00030d3fU >= (0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n))) {
                __Vtemp_3[0U] = vlSelfRef.tb_scelbal__DOT__expected
                    [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][0U];
                __Vtemp_3[1U] = vlSelfRef.tb_scelbal__DOT__expected
                    [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][1U];
                __Vtemp_3[2U] = vlSelfRef.tb_scelbal__DOT__expected
                    [(0x0003ffffU & tb_scelbal__DOT__unnamedblk1__DOT__n)][2U];
            } else {
                __Vtemp_3[0U] = 0U;
                __Vtemp_3[1U] = 0U;
                __Vtemp_3[2U] = 0U;
            }
            __Vtemp_4[0U] = (IData)((((QData)((IData)(
                                                      (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[3U]) 
                                                        << 8U) 
                                                       | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[4U]))) 
                                      << 0x00000017U) 
                                     | (QData)((IData)(
                                                       (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U]) 
                                                         << 0x0000000fU) 
                                                        | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]) 
                                                            << 7U) 
                                                           | ((((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                                                                << 6U) 
                                                               | ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero) 
                                                                  << 5U)) 
                                                              | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign) 
                                                                  << 4U) 
                                                                 | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity) 
                                                                     << 3U) 
                                                                    | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp))))))))));
            __Vtemp_4[1U] = (((IData)((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                        << 0x00000018U) 
                                       | (QData)((IData)(
                                                         (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                           << 0x00000010U) 
                                                          | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                              << 8U) 
                                                             | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U])))))) 
                              << 7U) | (IData)(((((QData)((IData)(
                                                                  (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[3U]) 
                                                                    << 8U) 
                                                                   | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[4U]))) 
                                                  << 0x00000017U) 
                                                 | (QData)((IData)(
                                                                   (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U]) 
                                                                     << 0x0000000fU) 
                                                                    | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]) 
                                                                        << 7U) 
                                                                       | ((((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                                                                            << 6U) 
                                                                           | ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero) 
                                                                              << 5U)) 
                                                                          | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign) 
                                                                              << 4U) 
                                                                             | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity) 
                                                                                << 3U) 
                                                                                | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp))))))))) 
                                                >> 0x00000020U)));
            __Vtemp_4[2U] = (((IData)((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                        << 0x00000018U) 
                                       | (QData)((IData)(
                                                         (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                           << 0x00000010U) 
                                                          | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                              << 8U) 
                                                             | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U])))))) 
                              >> 0x00000019U) | ((IData)(
                                                         ((((QData)((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)) 
                                                            << 0x00000018U) 
                                                           | (QData)((IData)(
                                                                             (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]) 
                                                                               << 0x00000010U) 
                                                                              | (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U]) 
                                                                                << 8U) 
                                                                                | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U]))))) 
                                                          >> 0x00000020U)) 
                                                 << 7U));
            VL_WRITEF_NX("[%0t] %%Fatal: tb_scelbal.sv:53: Assertion failed in %m: SCELBAL mismatch at %0d expected %020x got %020x\n",6, 'M',vlSymsp->name(),"tb_scelbal.unnamedblk1", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '~',32,tb_scelbal__DOT__unnamedblk1__DOT__n
                         , '#',77,__Vtemp_3.data(), '#',77,__Vtemp_4.data());
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 53, "", false);
        }
        tb_scelbal__DOT__unnamedblk1__DOT__n = ((IData)(1U) 
                                                + tb_scelbal__DOT__unnamedblk1__DOT__n);
    }
    tb_scelbal__DOT__unnamedblk2__DOT__i = 0U;
    while (VL_GTS_III(32, 0x00004000U, tb_scelbal__DOT__unnamedblk2__DOT__i)) {
        if (VL_UNLIKELY(((vlSelfRef.tb_scelbal__DOT__mem
                          [(0x00003fffU & tb_scelbal__DOT__unnamedblk2__DOT__i)] 
                          != vlSelfRef.tb_scelbal__DOT__final_mem
                          [(0x00003fffU & tb_scelbal__DOT__unnamedblk2__DOT__i)])))) {
            VL_WRITEF_NX("[%0t] %%Fatal: tb_scelbal.sv:56: Assertion failed in %m: SCELBAL memory mismatch at %04x\n",4, 'M',vlSymsp->name(),"tb_scelbal.unnamedblk2", 'T',-12
                         , '#',64,VL_TIME_UNITED_Q(1)
                         , '~',32,tb_scelbal__DOT__unnamedblk2__DOT__i);
            VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 56, "", false);
        }
        tb_scelbal__DOT__unnamedblk2__DOT__i = ((IData)(1U) 
                                                + tb_scelbal__DOT__unnamedblk2__DOT__i);
    }
    if (VL_UNLIKELY(((8U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))))) {
        VL_WRITEF_NX("[%0t] %%Fatal: tb_scelbal.sv:57: Assertion failed in %m: SCELBAL unexpectedly halted\n",3, 'M',vlSymsp->name(),"tb_scelbal", 'T',-12
                     , '#',64,VL_TIME_UNITED_Q(1));
        VL_STOP_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 57, "", false);
    }
    VL_WRITEF_NX("PASS: 200000 authentic SCELBAL instructions; %0d reads, %0d writes, %0d inputs, %0d outputs\n",4
                 , '~',32,vlSelfRef.tb_scelbal__DOT__reads
                 , '~',32,vlSelfRef.tb_scelbal__DOT__writes
                 , '~',32,vlSelfRef.tb_scelbal__DOT__inputs
                 , '~',32,vlSelfRef.tb_scelbal__DOT__outputs);
    VL_FINISH_MT("/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 60, "");
    co_return;
}

VlCoroutine Vtb_scelbal___024root___eval_initial__TOP__Vtiming__1(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(5ULL, 
                                             nullptr, 
                                             "/work/ai_hw_engineer/design/intel_8008/tb/tb_scelbal.sv", 
                                             3);
        vlSelfRef.tb_scelbal__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb_scelbal__DOT__clk)));
    }
    co_return;
}

bool Vtb_scelbal___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___trigger_anySet__ico\n"); );
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

bool Vtb_scelbal___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___trigger_anySet__act\n"); );
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

void Vtb_scelbal___024root___nba_sequent__TOP__0(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___nba_sequent__TOP__0\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*2:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value = 0;
    SData/*8:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value = 0;
    CData/*1:0*/ __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which;
    __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which = 0;
    CData/*2:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value = 0;
    SData/*8:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value = 0;
    CData/*1:0*/ __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which;
    __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which = 0;
    CData/*2:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value = 0;
    SData/*8:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value = 0;
    CData/*2:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value = 0;
    SData/*8:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp;
    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value = 0;
    CData/*7:0*/ __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value;
    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value = 0;
    CData/*1:0*/ __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which;
    __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which = 0;
    CData/*3:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__state;
    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0;
    CData/*7:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__op;
    __Vdly__tb_scelbal__DOT__dut__DOT__op = 0;
    SData/*13:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__pc;
    __Vdly__tb_scelbal__DOT__dut__DOT__pc = 0;
    CData/*0:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__carry;
    __Vdly__tb_scelbal__DOT__dut__DOT__carry = 0;
    CData/*0:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__zero;
    __Vdly__tb_scelbal__DOT__dut__DOT__zero = 0;
    CData/*0:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__sign;
    __Vdly__tb_scelbal__DOT__dut__DOT__sign = 0;
    CData/*0:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__parity;
    __Vdly__tb_scelbal__DOT__dut__DOT__parity = 0;
    CData/*2:0*/ __Vdly__tb_scelbal__DOT__dut__DOT__sp;
    __Vdly__tb_scelbal__DOT__dut__DOT__sp = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__mem__v0;
    __VdlyVal__tb_scelbal__DOT__mem__v0 = 0;
    SData/*13:0*/ __VdlyDim0__tb_scelbal__DOT__mem__v0;
    __VdlyDim0__tb_scelbal__DOT__mem__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__mem__v0;
    __VdlySet__tb_scelbal__DOT__mem__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v0;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v0 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v0;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v0;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v1;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v1 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v1;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v1 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v2;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v2 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v2;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v2 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v2;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v2 = 0;
    SData/*13:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v0;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v0 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v0;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v0 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v0;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v0 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v3;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v3 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v3;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v3 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v4;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v4 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v4;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v4 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v5;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v5 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v5;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v5 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v6;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v6 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v6;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v6 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v7;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v7 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v8;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v8 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v8;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v8 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v8;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v8 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v9;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v9 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v9;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v9 = 0;
    SData/*13:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v1;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v1 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v1;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v1 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v1;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v1 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v10;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v10 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v10;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v10 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v10;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v10 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v11;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v11 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v11;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v11 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v12;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v12 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v12;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v12 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v12;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v12 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v13;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v13 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v13;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v13 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v14;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v14 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v14;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v14 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v14;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v14 = 0;
    SData/*13:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v2;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v2 = 0;
    CData/*2:0*/ __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v2;
    __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v2 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v2;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v2 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v15;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v15 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v15;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v15 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v16;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v16 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v16;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v16 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v17;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v17 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v17;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v17 = 0;
    CData/*7:0*/ __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v18;
    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v18 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v18;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v18 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v19;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v19 = 0;
    CData/*0:0*/ __VdlySet__tb_scelbal__DOT__dut__DOT__r__v20;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v20 = 0;
    // Body
    __Vdly__tb_scelbal__DOT__dut__DOT__op = vlSelfRef.tb_scelbal__DOT__dut__DOT__op;
    __Vdly__tb_scelbal__DOT__dut__DOT__carry = vlSelfRef.tb_scelbal__DOT__dut__DOT__carry;
    __Vdly__tb_scelbal__DOT__dut__DOT__zero = vlSelfRef.tb_scelbal__DOT__dut__DOT__zero;
    __Vdly__tb_scelbal__DOT__dut__DOT__sign = vlSelfRef.tb_scelbal__DOT__dut__DOT__sign;
    __Vdly__tb_scelbal__DOT__dut__DOT__parity = vlSelfRef.tb_scelbal__DOT__dut__DOT__parity;
    __Vdly__tb_scelbal__DOT__dut__DOT__sp = vlSelfRef.tb_scelbal__DOT__dut__DOT__sp;
    __Vdly__tb_scelbal__DOT__dut__DOT__pc = vlSelfRef.tb_scelbal__DOT__dut__DOT__pc;
    __Vdly__tb_scelbal__DOT__dut__DOT__state = vlSelfRef.tb_scelbal__DOT__dut__DOT__state;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v0 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v1 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v2 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v0 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v1 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v2 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v3 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v4 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v5 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v6 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v7 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v8 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v9 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v10 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v11 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v12 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v13 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v14 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v15 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v16 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v17 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v18 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v19 = 0U;
    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v20 = 0U;
    __VdlySet__tb_scelbal__DOT__mem__v0 = 0U;
    if (vlSelfRef.tb_scelbal__DOT__rst_n) {
        if (vlSelfRef.tb_scelbal__DOT__mem_write) {
            vlSelfRef.tb_scelbal__DOT__writes = ((IData)(1U) 
                                                 + vlSelfRef.tb_scelbal__DOT__writes);
            __VdlyVal__tb_scelbal__DOT__mem__v0 = (
                                                   (8U 
                                                    & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                    ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]
                                                    : 
                                                   ((4U 
                                                     & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                     ? 
                                                    ((2U 
                                                      & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                      ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]
                                                      : 
                                                     ((1U 
                                                       & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                       ? 
                                                      ((0x3eU 
                                                        == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op))
                                                        ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__immediate)
                                                        : 
                                                       ((6U 
                                                         >= 
                                                         (7U 
                                                          & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op)))
                                                         ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                                        [
                                                        (7U 
                                                         & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op))]
                                                         : 0U))
                                                       : vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]))
                                                     : vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]));
            __VdlyDim0__tb_scelbal__DOT__mem__v0 = vlSelfRef.tb_scelbal__DOT__mem_addr;
            __VdlySet__tb_scelbal__DOT__mem__v0 = 1U;
        }
        if ((1U & ((~ ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state) 
                       >> 3U)) & ((~ ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state) 
                                      >> 2U)) | (IData)(
                                                        (0U 
                                                         == 
                                                         (3U 
                                                          & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)))))))) {
            vlSelfRef.tb_scelbal__DOT__reads = ((IData)(1U) 
                                                + vlSelfRef.tb_scelbal__DOT__reads);
        }
        if ((IData)((6U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)))) {
            vlSelfRef.tb_scelbal__DOT__inputs = ((IData)(1U) 
                                                 + vlSelfRef.tb_scelbal__DOT__inputs);
        }
        if ((IData)((7U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)))) {
            vlSelfRef.tb_scelbal__DOT__outputs = ((IData)(1U) 
                                                  + vlSelfRef.tb_scelbal__DOT__outputs);
        }
        vlSelfRef.tb_scelbal__DOT__retire = 0U;
        if ((8U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
            if ((4U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            } else if ((2U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            } else if ((1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            } else if ((0U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code 
                    = vlSelfRef.tb_scelbal__DOT__mem
                    [vlSelfRef.tb_scelbal__DOT__mem_addr];
                __Vdly__tb_scelbal__DOT__dut__DOT__op 
                    = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code;
                __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                    = (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                if ((((0xffU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)) 
                      | (0U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                     | (1U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 8U;
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                } else if ((3U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 6U)))) {
                    if ((7U == (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__state = 5U;
                    } else if ((7U == (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__state = 4U;
                    } else {
                        if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                          >> 3U)))) {
                            __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v0 
                                = ((6U >= (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))
                                    ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                   [(7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))]
                                    : 0U);
                            __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v0 
                                = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 3U));
                            __VdlySet__tb_scelbal__DOT__dut__DOT__r__v0 = 1U;
                        }
                        vlSelfRef.tb_scelbal__DOT__retire = 1U;
                        __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                    }
                } else if ((2U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 6U)))) {
                    if ((7U == (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__state = 4U;
                    } else {
                        __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value 
                            = ((6U >= (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))
                                ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                               [(7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))]
                                : 0U);
                        __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp 
                            = (0x000001ffU & ((4U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                               ? ((2U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                   ? 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                    ? 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value))
                                                    : 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    | (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value)))
                                                   : 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                    ? 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    ^ (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value))
                                                    : 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value))))
                                               : ((2U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                   ? 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                    ? 
                                                   ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                     - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value)) 
                                                    - (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                    : 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value)))
                                                   : 
                                                  ((1U 
                                                    & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))
                                                    ? 
                                                   ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                     + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value)) 
                                                    + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                    : 
                                                   (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__value))))));
                        vlSelfRef.tb_scelbal__DOT__retire = 1U;
                        __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                        __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                            = (IData)((((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp) 
                                        >> 8U) & (~ 
                                                  ((4U 
                                                    <= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind)) 
                                                   & (6U 
                                                      >= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))))));
                        __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value 
                            = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp));
                        __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                            = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value));
                        __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                            = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value) 
                                     >> 7U));
                        __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                            = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__1__value)));
                        if ((7U != (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__kind))) {
                            __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v1 
                                = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__0__tmp));
                            __VdlySet__tb_scelbal__DOT__dut__DOT__r__v1 = 1U;
                        }
                    }
                } else if (((6U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                            | (4U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 1U;
                } else if (((0U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                            | (1U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                    vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8 
                        = (0x000000ffU & ((1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))
                                           ? (((6U 
                                                >= 
                                                (7U 
                                                 & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                    >> 3U)))
                                                ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                               [(7U 
                                                 & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                    >> 3U))]
                                                : 0U) 
                                              - (IData)(1U))
                                           : ((IData)(1U) 
                                              + ((6U 
                                                  >= 
                                                  (7U 
                                                   & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U)))
                                                  ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                                 [(7U 
                                                   & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U))]
                                                  : 0U))));
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v2 
                            = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8;
                        __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v2 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v2 = 1U;
                    }
                    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value 
                        = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8;
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value));
                    __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value) 
                                 >> 7U));
                    __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__2__value)));
                } else if ((IData)((0x40U == (0xc1U 
                                              & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 2U;
                } else if ((7U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                        = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                 - (IData)(1U)));
                    __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                        = vlSelfRef.tb_scelbal__DOT__dut__DOT__stack
                        [(7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                - (IData)(1U)))];
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                } else if ((3U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which 
                        = (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_0__flag_selected 
                        = ((0U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which))
                            ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry)
                            : ((1U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which))
                                ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero)
                                : ((2U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__3__which))
                                    ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign)
                                    : (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity))));
                    if (((1U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                >> 5U)) == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_0__flag_selected))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                     - (IData)(1U)));
                        __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                            = vlSelfRef.tb_scelbal__DOT__dut__DOT__stack
                            [(7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                    - (IData)(1U)))];
                    }
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                } else if ((5U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v0 
                        = (0x00003fffU & ((IData)(1U) 
                                          + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                    __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v0 
                        = vlSelfRef.tb_scelbal__DOT__dut__DOT__sp;
                    __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v0 = 1U;
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                        = (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp)));
                    __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                        = (0x00000038U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code));
                } else if ((0x41U == (0xc1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state 
                        = ((0U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                         >> 4U))) ? 6U
                            : 7U);
                } else {
                    if ((2U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                            = (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                     >> 7U));
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v3 
                            = ((0x000000feU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                               << 1U)) 
                               | (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                        >> 7U)));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v3 = 1U;
                    } else if ((0x0aU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                            = (1U & vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]);
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v4 
                            = ((0x00000080U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                               << 7U)) 
                               | (0x0000007fU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                 >> 1U)));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v4 = 1U;
                    } else if ((0x12U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                            = (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                     >> 7U));
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v5 
                            = ((0x000000feU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                               << 1U)) 
                               | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v5 = 1U;
                    } else if ((0x1aU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                        __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                            = (1U & vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]);
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v6 
                            = (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                                << 7U) | (0x0000007fU 
                                          & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                             >> 1U)));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v6 = 1U;
                    }
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                }
            }
        } else if ((4U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
            if ((2U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                if ((1U & (~ (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)))) {
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v7 = 1U;
                }
            } else if ((1U & (~ (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)))) {
                if ((3U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                  >> 6U)))) {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                      >> 3U)))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v8 
                            = vlSelfRef.tb_scelbal__DOT__mem
                            [vlSelfRef.tb_scelbal__DOT__mem_addr];
                        __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v8 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                     >> 3U));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v8 = 1U;
                    }
                } else {
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value 
                        = vlSelfRef.tb_scelbal__DOT__mem
                        [vlSelfRef.tb_scelbal__DOT__mem_addr];
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind 
                        = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                 >> 3U));
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp 
                        = (0x000001ffU & ((4U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                           ? ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                                   ? 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   | (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                                   ? 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   ^ (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value))))
                                           : ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value)) 
                                                   - (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value)) 
                                                   + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__value))))));
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (IData)((((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp) 
                                    >> 8U) & (~ ((4U 
                                                  <= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind)) 
                                                 & (6U 
                                                    >= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))))));
                    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value 
                        = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp));
                    __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value));
                    __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value) 
                                 >> 7U));
                    __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__5__value)));
                    if ((7U != (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__kind))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v9 
                            = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__4__tmp));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v9 = 1U;
                    }
                }
            }
            vlSelfRef.tb_scelbal__DOT__retire = 1U;
            __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
        } else if ((2U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
            if ((1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                    = (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which 
                    = (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                             >> 3U));
                vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_1__flag_selected 
                    = ((0U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which))
                        ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry)
                        : ((1U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which))
                            ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero)
                            : ((2U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__6__which))
                                ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign)
                                : (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity))));
                if ((1U & (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                            >> 2U) | ((1U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                             >> 5U)) 
                                      == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_1__flag_selected))))) {
                    if ((2U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v1 
                            = (0x00003fffU & ((IData)(1U) 
                                              + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                        __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v1 
                            = vlSelfRef.tb_scelbal__DOT__dut__DOT__sp;
                        __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v1 = 1U;
                        __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                            = (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp)));
                    }
                    __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                        = ((0x00003f00U & (vlSelfRef.tb_scelbal__DOT__mem
                                           [vlSelfRef.tb_scelbal__DOT__mem_addr] 
                                           << 8U)) 
                           | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__addr_low));
                }
            } else {
                __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                    = (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                vlSelfRef.tb_scelbal__DOT__dut__DOT__addr_low 
                    = vlSelfRef.tb_scelbal__DOT__mem
                    [vlSelfRef.tb_scelbal__DOT__mem_addr];
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 3U;
            }
        } else if ((1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
            __Vdly__tb_scelbal__DOT__dut__DOT__pc = 
                (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
            if ((6U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op)))) {
                if ((7U == (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                  >> 3U)))) {
                    vlSelfRef.tb_scelbal__DOT__dut__DOT__immediate 
                        = vlSelfRef.tb_scelbal__DOT__mem
                        [vlSelfRef.tb_scelbal__DOT__mem_addr];
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 5U;
                } else {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                      >> 3U)))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v10 
                            = vlSelfRef.tb_scelbal__DOT__mem
                            [vlSelfRef.tb_scelbal__DOT__mem_addr];
                        __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v10 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                                     >> 3U));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v10 = 1U;
                    }
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                }
            } else {
                __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value 
                    = vlSelfRef.tb_scelbal__DOT__mem
                    [vlSelfRef.tb_scelbal__DOT__mem_addr];
                __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind 
                    = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__op) 
                             >> 3U));
                __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp 
                    = (0x000001ffU & ((4U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                       ? ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                           ? ((1U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                               ? (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value))
                                               : (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  | (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value)))
                                           : ((1U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                               ? (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  ^ (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value))
                                               : (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value))))
                                       : ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                           ? ((1U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                               ? ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value)) 
                                                  - (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                               : (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value)))
                                           : ((1U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))
                                               ? ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value)) 
                                                  + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                               : (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                  + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__value))))));
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                    = (IData)((((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp) 
                                >> 8U) & (~ ((4U <= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind)) 
                                             & (6U 
                                                >= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))))));
                __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value 
                    = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp));
                __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                    = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value));
                __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                    = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value) 
                             >> 7U));
                __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                    = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__8__value)));
                if ((7U != (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__kind))) {
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v11 
                        = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__7__tmp));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v11 = 1U;
                }
            }
        } else if ((0U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))) {
            vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code 
                = vlSelfRef.tb_scelbal__DOT__mem[vlSelfRef.tb_scelbal__DOT__mem_addr];
            __Vdly__tb_scelbal__DOT__dut__DOT__op = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code;
            __Vdly__tb_scelbal__DOT__dut__DOT__pc = 
                (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
            if ((((0xffU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)) 
                  | (0U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                 | (1U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 8U;
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
            } else if ((3U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 6U)))) {
                if ((7U == (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                  >> 3U)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 5U;
                } else if ((7U == (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 4U;
                } else {
                    if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                      >> 3U)))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v12 
                            = ((6U >= (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))
                                ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                               [(7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))]
                                : 0U);
                        __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v12 
                            = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 3U));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v12 = 1U;
                    }
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                }
            } else if ((2U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 6U)))) {
                if ((7U == (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 4U;
                } else {
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value 
                        = ((6U >= (7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))
                            ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                           [(7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))]
                            : 0U);
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind 
                        = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    __Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp 
                        = (0x000001ffU & ((4U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                           ? ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                                   ? 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   | (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                                   ? 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   ^ (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value))))
                                           : ((2U & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                               ? ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value)) 
                                                   - (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   - (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value)))
                                               : ((1U 
                                                   & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))
                                                   ? 
                                                  ((vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                    + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value)) 
                                                   + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry))
                                                   : 
                                                  (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                                   + (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__value))))));
                    vlSelfRef.tb_scelbal__DOT__retire = 1U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (IData)((((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp) 
                                    >> 8U) & (~ ((4U 
                                                  <= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind)) 
                                                 & (6U 
                                                    >= (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))))));
                    __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value 
                        = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp));
                    __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                        = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value));
                    __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                        = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value) 
                                 >> 7U));
                    __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                        = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__10__value)));
                    if ((7U != (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__kind))) {
                        __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v13 
                            = (0x000000ffU & (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__execute_alu__9__tmp));
                        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v13 = 1U;
                    }
                }
            } else if (((6U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                        | (4U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 1U;
            } else if (((0U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) 
                        | (1U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8 
                    = (0x000000ffU & ((1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))
                                       ? (((6U >= (7U 
                                                   & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                      >> 3U)))
                                            ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                           [(7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                   >> 3U))]
                                            : 0U) - (IData)(1U))
                                       : ((IData)(1U) 
                                          + ((6U >= 
                                              (7U & 
                                               ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                >> 3U)))
                                              ? vlSelfRef.tb_scelbal__DOT__dut__DOT__r
                                             [(7U & 
                                               ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                                >> 3U))]
                                              : 0U))));
                if ((6U >= (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                  >> 3U)))) {
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v14 
                        = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8;
                    __VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v14 
                        = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                 >> 3U));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v14 = 1U;
                }
                __Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value 
                    = vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8;
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                __Vdly__tb_scelbal__DOT__dut__DOT__zero 
                    = (0U == (IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value));
                __Vdly__tb_scelbal__DOT__dut__DOT__sign 
                    = (1U & ((IData)(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value) 
                             >> 7U));
                __Vdly__tb_scelbal__DOT__dut__DOT__parity 
                    = (1U & (~ VL_REDXOR_8(__Vtask_tb_scelbal__DOT__dut__DOT__set_szp__11__value)));
            } else if ((IData)((0x40U == (0xc1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 2U;
            } else if ((7U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                    = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                             - (IData)(1U)));
                __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                    = vlSelfRef.tb_scelbal__DOT__dut__DOT__stack
                    [(7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                            - (IData)(1U)))];
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            } else if ((3U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which 
                    = (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                             >> 3U));
                vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_0__flag_selected 
                    = ((0U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which))
                        ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry)
                        : ((1U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which))
                            ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__zero)
                            : ((2U == (IData)(__Vfunc_tb_scelbal__DOT__dut__DOT__flag_selected__12__which))
                                ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sign)
                                : (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__parity))));
                if (((1U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                            >> 5U)) == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT____VlemCall_0__flag_selected))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                        = (7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                 - (IData)(1U)));
                    __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                        = vlSelfRef.tb_scelbal__DOT__dut__DOT__stack
                        [(7U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp) 
                                - (IData)(1U)))];
                }
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            } else if ((5U == (0xc7U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v2 
                    = (0x00003fffU & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                __VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v2 
                    = vlSelfRef.tb_scelbal__DOT__dut__DOT__sp;
                __VdlySet__tb_scelbal__DOT__dut__DOT__stack__v2 = 1U;
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
                __Vdly__tb_scelbal__DOT__dut__DOT__sp 
                    = (7U & ((IData)(1U) + (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sp)));
                __Vdly__tb_scelbal__DOT__dut__DOT__pc 
                    = (0x00000038U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code));
            } else if ((0x41U == (0xc1U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code)))) {
                __Vdly__tb_scelbal__DOT__dut__DOT__state 
                    = ((0U == (3U & ((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code) 
                                     >> 4U))) ? 6U : 7U);
            } else {
                if ((2U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                 >> 7U));
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v15 
                        = ((0x000000feU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                           << 1U)) 
                           | (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                    >> 7U)));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v15 = 1U;
                } else if ((0x0aU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (1U & vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]);
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v16 
                        = ((0x00000080U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                           << 7U)) 
                           | (0x0000007fU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                             >> 1U)));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v16 = 1U;
                } else if ((0x12U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (1U & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                 >> 7U));
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v17 
                        = ((0x000000feU & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                           << 1U)) 
                           | (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v17 = 1U;
                } else if ((0x1aU == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code))) {
                    __Vdly__tb_scelbal__DOT__dut__DOT__carry 
                        = (1U & vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U]);
                    __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v18 
                        = (((IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__carry) 
                            << 7U) | (0x0000007fU & 
                                      (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
                                       >> 1U)));
                    __VdlySet__tb_scelbal__DOT__dut__DOT__r__v18 = 1U;
                }
                vlSelfRef.tb_scelbal__DOT__retire = 1U;
                __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
            }
        }
    } else {
        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v19 = 1U;
        __Vdly__tb_scelbal__DOT__dut__DOT__state = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__pc = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__sp = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__op = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__addr_low = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__immediate = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__carry = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__zero = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__sign = 0U;
        __Vdly__tb_scelbal__DOT__dut__DOT__parity = 0U;
        vlSelfRef.tb_scelbal__DOT__retire = 0U;
        __VdlySet__tb_scelbal__DOT__dut__DOT__r__v20 = 1U;
    }
    vlSelfRef.tb_scelbal__DOT__dut__DOT__carry = __Vdly__tb_scelbal__DOT__dut__DOT__carry;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__zero = __Vdly__tb_scelbal__DOT__dut__DOT__zero;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__sign = __Vdly__tb_scelbal__DOT__dut__DOT__sign;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__parity = __Vdly__tb_scelbal__DOT__dut__DOT__parity;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__sp = __Vdly__tb_scelbal__DOT__dut__DOT__sp;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__op = __Vdly__tb_scelbal__DOT__dut__DOT__op;
    if (__VdlySet__tb_scelbal__DOT__mem__v0) {
        vlSelfRef.tb_scelbal__DOT__mem[__VdlyDim0__tb_scelbal__DOT__mem__v0] 
            = __VdlyVal__tb_scelbal__DOT__mem__v0;
    }
    vlSelfRef.tb_scelbal__DOT__dut__DOT__pc = __Vdly__tb_scelbal__DOT__dut__DOT__pc;
    vlSelfRef.tb_scelbal__DOT__dut__DOT__state = __Vdly__tb_scelbal__DOT__dut__DOT__state;
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__stack__v0) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[__VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v0] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v0;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__stack__v1) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[__VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v1] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v1;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__stack__v2) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[__VdlyDim0__tb_scelbal__DOT__dut__DOT__stack__v2] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__stack__v2;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v0) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v0] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v0;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v1) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v1;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v2) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v2] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v2;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v3) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v3;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v4) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v4;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v5) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v5;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v6) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v6;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v7) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] = 0U;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v8) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v8] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v8;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v9) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v9;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v10) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v10] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v10;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v11) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v11;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v12) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v12] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v12;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v13) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v13;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v14) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[__VdlyDim0__tb_scelbal__DOT__dut__DOT__r__v14] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v14;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v15) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v15;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v16) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v16;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v17) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v17;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v18) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] 
            = __VdlyVal__tb_scelbal__DOT__dut__DOT__r__v18;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v19) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[0U] = 0U;
    }
    if (__VdlySet__tb_scelbal__DOT__dut__DOT__r__v20) {
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[0U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[1U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[2U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[3U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[4U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[5U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[6U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__stack[7U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[1U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[2U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[3U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[4U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U] = 0U;
        vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U] = 0U;
    }
    vlSelfRef.tb_scelbal__DOT__mem_write = (IData)(
                                                   (5U 
                                                    == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)));
    vlSelfRef.tb_scelbal__DOT__mem_addr = ((8U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                            ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)
                                            : ((4U 
                                                & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                ? (
                                                   (2U 
                                                    & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                                    ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)
                                                    : 
                                                   ((0x00003f00U 
                                                     & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U] 
                                                        << 8U)) 
                                                    | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]))
                                                : (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
}

void Vtb_scelbal___024root___timing_ready(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___timing_ready\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((2ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VtrigSched_hebcb83c2__0.ready("@(negedge tb_scelbal.clk)");
    }
}

void Vtb_scelbal___024root___timing_resume(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___timing_resume\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VtrigSched_hebcb83c2__0.moveToResumeQueue(
                                                          "@(negedge tb_scelbal.clk)");
    vlSelfRef.__VtrigSched_hebcb83c2__0.resume("@(negedge tb_scelbal.clk)");
    if ((4ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VdlySched.resume();
    }
}

void Vtb_scelbal___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

void Vtb_scelbal___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

void Vtb_scelbal___024root____VbeforeTrig_hebcb83c2__0(Vtb_scelbal___024root* vlSelf, const char* __VeventDescription) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root____VbeforeTrig_hebcb83c2__0\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    VlUnpacked<QData/*63:0*/, 1> __VTmp;
    // Body
    __VTmp[0U] = (QData)((IData)((((~ (IData)(vlSelfRef.tb_scelbal__DOT__clk)) 
                                   & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0)) 
                                  << 1U)));
    vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0 
        = vlSelfRef.tb_scelbal__DOT__clk;
    if ((2ULL & __VTmp[0U])) {
        vlSelfRef.__VtrigSched_hebcb83c2__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_hebcb83c2__0.ready(__VeventDescription);
    }
    vlSelfRef.__VactTriggeredAcc[0U] = (vlSelfRef.__VactTriggeredAcc[0U] 
                                        | __VTmp[0U]);
}

#ifdef VL_DEBUG
void Vtb_scelbal___024root___eval_debug_assertions(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_debug_assertions\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
