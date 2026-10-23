// Oracle adapter: compiles the unchanged, pinned MAME mos6526.cpp/.h
// (BSD-3-Clause) against tb/mame_stubs. One call of cia_clock() is one
// execute_run() iteration (one phase-two cycle). Access is widened by
// macro only for observation; no reference line is edited.
#include <cstdint>
#include <memory>

#define private public
#define protected public
#include "mos6526.cpp"
#undef private
#undef protected

namespace {
const machine_config config;
std::unique_ptr<mos6526_device> cia;
uint8_t pa_in = 0xff, pb_in = 0xff;
}

extern "C" {
// variant: 0 = 6526, 1 = 6526A, 2 = 8520.
void cia_init(int variant) {
    if (variant == 2) cia.reset(new mos8520_device(config, "cia", nullptr, 709379));
    else if (variant == 1) cia.reset(new mos6526a_device(config, "cia", nullptr, 1000000));
    else cia.reset(new mos6526_device(config, "cia", nullptr, 1000000));
    cia->m_read_pa.reader = [](offs_t) { return pa_in; };
    cia->m_read_pb.reader = [](offs_t) { return pb_in; };
    cia->device_start();
    cia->device_reset();
}
void cia_clock(void) {
    cia->m_icount = 1;
    cia->execute_run();
}
unsigned cia_read(unsigned reg) { return cia->read(reg & 15); }
void cia_write(unsigned reg, unsigned data) { cia->write(reg & 15, uint8_t(data)); }
void cia_pins(unsigned pa, unsigned pb) { pa_in = uint8_t(pa); pb_in = uint8_t(pb); }
void cia_cnt(int level) { cia->cnt_w(level); }
void cia_flag(int level) { cia->flag_w(level); }
void cia_tod(int level) { cia->tod_w(level); }
void cia_sp(int level) { cia->sp_w(level); }
int cia_irq(void) { return cia->m_irq ? 1 : 0; }
unsigned cia_tod_value(void) { return cia->m_tod; }
unsigned cia_ta(void) { return cia->m_ta; }
unsigned cia_tb(void) { return cia->m_tb; }
unsigned cia_icr(void) { return cia->m_icr; }
unsigned cia_imr(void) { return cia->m_imr; }
unsigned cia_cra(void) { return cia->m_cra; }
unsigned cia_crb(void) { return cia->m_crb; }
}
