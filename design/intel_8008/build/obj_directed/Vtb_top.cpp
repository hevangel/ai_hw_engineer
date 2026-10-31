// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtb_top__pch.h"

//============================================================
// Constructors

Vtb_top::Vtb_top(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtb_top__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtb_top::Vtb_top(const char* _vcname__)
    : Vtb_top(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtb_top::~Vtb_top() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtb_top___024root___eval_debug_assertions(Vtb_top___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vtb_top___024root___eval_static(Vtb_top___024root* vlSelf);
void Vtb_top___024root___eval_initial(Vtb_top___024root* vlSelf);
VL_ATTR_COLD bool Vtb_top___024root___eval_stl(Vtb_top___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vtb_top___024root___eval_sample(Vtb_top___024root* vlSelf);
bool Vtb_top___024root___eval_ico(Vtb_top___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vtb_top___024root___eval_act(Vtb_top___024root* vlSelf);
bool Vtb_top___024root___eval_inact(Vtb_top___024root* vlSelf);
bool Vtb_top___024root___eval_nba(Vtb_top___024root* vlSelf);
bool Vtb_top___024root___eval_obs(Vtb_top___024root* vlSelf);
bool Vtb_top___024root___eval_react(Vtb_top___024root* vlSelf);
void Vtb_top___024root___eval_postponed(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_final(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__stl(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__ico(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__act(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__nba(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__obs(Vtb_top___024root* vlSelf);
VL_ATTR_COLD void Vtb_top___024root___eval_dump_triggers__react(Vtb_top___024root* vlSelf);

void Vtb_top::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtb_top::eval_step\n"); );
    m_evalLoop.eval();
}

void Vtb_top::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vtb_top___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vtb_top::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->TOP.__VdlySched.cleanupForevered();
}

void Vtb_top::evalStatic() {
    Vtb_top___024root___eval_static(&(vlSymsp->TOP));
}

void Vtb_top::evalInitial() {
    Vtb_top___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vtb_top::evalStl(bool firstIteration) {
    return Vtb_top___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vtb_top::evalSample() {
    Vtb_top___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vtb_top::evalIco(bool firstIteration) {
    return Vtb_top___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vtb_top::evalAct() {
    return Vtb_top___024root___eval_act(&(vlSymsp->TOP));
}

bool Vtb_top::evalInact() {
    return Vtb_top___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vtb_top::evalNba() {
    return Vtb_top___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vtb_top::evalObs() {
    return Vtb_top___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vtb_top::evalReact() {
    return Vtb_top___024root___eval_react(&(vlSymsp->TOP));
}

void Vtb_top::evalPostponed() {
    Vtb_top___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vtb_top::evalFinal() {
    Vtb_top___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersStl() {
    Vtb_top___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersIco() {
    Vtb_top___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersAct() {
    Vtb_top___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersNba() {
    Vtb_top___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersObs() {
    Vtb_top___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_top::dumpTriggersReact() {
    Vtb_top___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vtb_top::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vtb_top::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vtb_top::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vtb_top::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtb_top::hierName() const { return vlSymsp->name(); }
const char* Vtb_top::modelName() const { return "Vtb_top"; }
unsigned Vtb_top::threads() const { return 1; }
void Vtb_top::prepareClone() const { contextp()->prepareClone(); }
void Vtb_top::atClone() const {
    contextp()->threadPoolpOnClone();
}
