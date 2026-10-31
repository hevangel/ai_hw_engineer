// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_scelbal.h for the primary calling header

#include "Vtb_scelbal__pch.h"

void Vtb_scelbal___024root___ctor_var_reset(Vtb_scelbal___024root* vlSelf);

Vtb_scelbal___024root::Vtb_scelbal___024root(Vtb_scelbal__Syms* symsp, const char* namep)
    : __VdlySched{*symsp->_vm_contextp__}
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vtb_scelbal___024root___ctor_var_reset(this);
}

void Vtb_scelbal___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtb_scelbal___024root::~Vtb_scelbal___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
