// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_scelbal.h for the primary calling header

#include "Vtb_scelbal__pch.h"

void Vtb_scelbal___024root___timing_ready(Vtb_scelbal___024root* vlSelf);

VL_ATTR_COLD void Vtb_scelbal___024root___eval_static(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_static\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_static__TOP
        vlSelfRef.tb_scelbal__DOT__clk = 0U;
        vlSelfRef.tb_scelbal__DOT__rst_n = 0U;
        vlSelfRef.tb_scelbal__DOT__reads = 0U;
        vlSelfRef.tb_scelbal__DOT__writes = 0U;
        vlSelfRef.tb_scelbal__DOT__inputs = 0U;
        vlSelfRef.tb_scelbal__DOT__outputs = 0U;
        const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
        vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__code = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 10278385579876102345ull);
        vlSelfRef.tb_scelbal__DOT__dut__DOT__sequencer__DOT__tmp8 = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 3053048164039006643ull);
    }
    vlSelfRef.__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0 = 0U;
    Vtb_scelbal___024root___timing_ready(vlSelf);
    do {
        vlSelfRef.__VactTriggeredAcc[vlSelfRef.__Vi] 
            = vlSelfRef.__VactTriggered[vlSelfRef.__Vi];
        vlSelfRef.__Vi = ((IData)(1U) + vlSelfRef.__Vi);
    } while ((0U >= vlSelfRef.__Vi));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vtb_scelbal___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

VL_ATTR_COLD bool Vtb_scelbal___024root___eval_stl(Vtb_scelbal___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_stl\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_scelbal___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vtb_scelbal___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        {
            // Inlined CFunc: _eval_body__stl
            if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
                {
                    // Inlined CFunc: _stl_sequent__TOP__0
                    vlSelfRef.tb_scelbal__DOT__mem_write 
                        = (IData)((5U == (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state)));
                    vlSelfRef.tb_scelbal__DOT__mem_addr 
                        = ((8U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                            ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)
                            : ((4U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                ? ((2U & (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__state))
                                    ? (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)
                                    : ((0x00003f00U 
                                        & (vlSelfRef.tb_scelbal__DOT__dut__DOT__r[5U] 
                                           << 8U)) 
                                       | vlSelfRef.tb_scelbal__DOT__dut__DOT__r[6U]))
                                : (IData)(vlSelfRef.tb_scelbal__DOT__dut__DOT__pc)));
                }
            }
        }
    }
    return (__VstlExecute);
}

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__stl(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__stl\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_scelbal___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__ico(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__ico\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_scelbal___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__act(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__act\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_scelbal___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
}

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__nba(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__nba\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_scelbal___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
}

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__obs(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__obs\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__react(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_dump_triggers__react\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vtb_scelbal___024root___eval_final(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___eval_final\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vtb_scelbal___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vtb_scelbal___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___trigger_anySet__stl\n"); );
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

bool Vtb_scelbal___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vtb_scelbal___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vtb_scelbal___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vtb_scelbal___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge tb_scelbal.clk)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(negedge tb_scelbal.clk)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 2U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 2 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_scelbal___024root___ctor_var_reset(Vtb_scelbal___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_scelbal___024root___ctor_var_reset\n"); );
    Vtb_scelbal__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->tb_scelbal__DOT__mem_addr = VL_SCOPED_RAND_RESET_I(14, __VscopeHash, 417440049171270270ull);
    vlSelf->tb_scelbal__DOT__mem_write = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 18413680851259003451ull);
    vlSelf->tb_scelbal__DOT__retire = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5647036844266369378ull);
    for (int __Vi0 = 0; __Vi0 < 16384; ++__Vi0) {
        vlSelf->tb_scelbal__DOT__mem[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 13497043066397476999ull);
    }
    for (int __Vi0 = 0; __Vi0 < 16384; ++__Vi0) {
        vlSelf->tb_scelbal__DOT__final_mem[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 17897834751702784658ull);
    }
    for (int __Vi0 = 0; __Vi0 < 200000; ++__Vi0) {
        VL_SCOPED_RAND_RESET_W(77, vlSelf->tb_scelbal__DOT__expected[__Vi0], __VscopeHash, 14735275609499014123ull);
    }
    vlSelf->tb_scelbal__DOT__cycles = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 10521691614532398523ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__state = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 8281381283768100668ull);
    for (int __Vi0 = 0; __Vi0 < 7; ++__Vi0) {
        vlSelf->tb_scelbal__DOT__dut__DOT__r[__Vi0] = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 13113634864009590788ull);
    }
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->tb_scelbal__DOT__dut__DOT__stack[__Vi0] = VL_SCOPED_RAND_RESET_I(14, __VscopeHash, 17133926141652278087ull);
    }
    vlSelf->tb_scelbal__DOT__dut__DOT__sp = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 10213148033711182998ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__pc = VL_SCOPED_RAND_RESET_I(14, __VscopeHash, 12173988865528363677ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__op = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 18088150508145683198ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__addr_low = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 11578558277408670173ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__immediate = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 7566225757942536619ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__carry = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3082586450614620267ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__zero = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8253535877338949590ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__sign = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5404133707617814762ull);
    vlSelf->tb_scelbal__DOT__dut__DOT__parity = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6725890258960453845ull);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggeredAcc[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__tb_scelbal__DOT__clk__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
    vlSelf->__Vi = 0;
}
