// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtb_scelbal__pch.h"

//============================================================
// Constructors

Vtb_scelbal::Vtb_scelbal(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtb_scelbal__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtb_scelbal::Vtb_scelbal(const char* _vcname__)
    : Vtb_scelbal(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtb_scelbal::~Vtb_scelbal() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtb_scelbal___024root___eval_debug_assertions(Vtb_scelbal___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vtb_scelbal___024root___eval_static(Vtb_scelbal___024root* vlSelf);
void Vtb_scelbal___024root___eval_initial(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD bool Vtb_scelbal___024root___eval_stl(Vtb_scelbal___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vtb_scelbal___024root___eval_sample(Vtb_scelbal___024root* vlSelf);
bool Vtb_scelbal___024root___eval_ico(Vtb_scelbal___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vtb_scelbal___024root___eval_act(Vtb_scelbal___024root* vlSelf);
bool Vtb_scelbal___024root___eval_inact(Vtb_scelbal___024root* vlSelf);
bool Vtb_scelbal___024root___eval_nba(Vtb_scelbal___024root* vlSelf);
bool Vtb_scelbal___024root___eval_obs(Vtb_scelbal___024root* vlSelf);
bool Vtb_scelbal___024root___eval_react(Vtb_scelbal___024root* vlSelf);
void Vtb_scelbal___024root___eval_postponed(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_final(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__stl(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__ico(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__act(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__nba(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__obs(Vtb_scelbal___024root* vlSelf);
VL_ATTR_COLD void Vtb_scelbal___024root___eval_dump_triggers__react(Vtb_scelbal___024root* vlSelf);

void Vtb_scelbal::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtb_scelbal::eval_step\n"); );
    m_evalLoop.eval();
}

void Vtb_scelbal::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vtb_scelbal___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vtb_scelbal::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->TOP.__VdlySched.cleanupForevered();
}

void Vtb_scelbal::evalStatic() {
    Vtb_scelbal___024root___eval_static(&(vlSymsp->TOP));
}

void Vtb_scelbal::evalInitial() {
    Vtb_scelbal___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalStl(bool firstIteration) {
    return Vtb_scelbal___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vtb_scelbal::evalSample() {
    Vtb_scelbal___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalIco(bool firstIteration) {
    return Vtb_scelbal___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vtb_scelbal::evalAct() {
    return Vtb_scelbal___024root___eval_act(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalInact() {
    return Vtb_scelbal___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalNba() {
    return Vtb_scelbal___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalObs() {
    return Vtb_scelbal___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vtb_scelbal::evalReact() {
    return Vtb_scelbal___024root___eval_react(&(vlSymsp->TOP));
}

void Vtb_scelbal::evalPostponed() {
    Vtb_scelbal___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vtb_scelbal::evalFinal() {
    Vtb_scelbal___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersStl() {
    Vtb_scelbal___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersIco() {
    Vtb_scelbal___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersAct() {
    Vtb_scelbal___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersNba() {
    Vtb_scelbal___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersObs() {
    Vtb_scelbal___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_scelbal::dumpTriggersReact() {
    Vtb_scelbal___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vtb_scelbal::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vtb_scelbal::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vtb_scelbal::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vtb_scelbal::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtb_scelbal::hierName() const { return vlSymsp->name(); }
const char* Vtb_scelbal::modelName() const { return "Vtb_scelbal"; }
unsigned Vtb_scelbal::threads() const { return 1; }
void Vtb_scelbal::prepareClone() const { contextp()->prepareClone(); }
void Vtb_scelbal::atClone() const {
    contextp()->threadPoolpOnClone();
}
