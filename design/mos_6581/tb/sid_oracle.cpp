// Oracle adapter for the unchanged reSIDfp engine pinned from MAME's
// 3rdparty tree (GPL-2.0-or-later; fetched into ignored work/reference and
// never committed). Access specifiers are widened by macro only so the
// harness can observe digital state; no reference line is edited.
// Per system clock the adapter recomputes reSIDfp's hard-sync schedule
// (voiceSync(false)) and runs clockDigital(1): oscillators, envelopes and
// the three voice outputs, i.e. the per-cycle sequence of SID::clock()
// without the analog filter. The schedule refresh only re-derives the
// cycle of the next MSB rise from the current accumulators.
#include <cstdint>
#include <memory>

#define private public
#define protected public
#include "SID.h"
#include "WaveformCalculator.h"
#undef private
#undef protected

namespace {
std::unique_ptr<reSIDfp::SID> sid;
rc_matrix_t pulldown;
}

extern "C" {
void sid_init(int mos8580) {
    sid.reset(new reSIDfp::SID());
    const auto model = mos8580 ? reSIDfp::CSG8580 : reSIDfp::MOS6581;
    sid->setChipModel(model);
    sid->setSamplingParameters(985248.0, reSIDfp::NONE, 985248.0);
    sid->reset();
    pulldown = reSIDfp::WaveformCalculator::getInstance()->buildPulldownTable(model, reSIDfp::AVERAGE);
}

void sid_clock(void) {
    sid->voiceSync(false);
    sid->clockDigital(1);
}

unsigned sid_read(unsigned reg) { return sid->read(int(reg & 31)); }
void sid_write(unsigned reg, unsigned data) { sid->write(int(reg & 31), uint8_t(data)); }
void sid_paddle(unsigned x, unsigned y) { sid->setPaddle(uint8_t(x), uint8_t(y)); }

unsigned sid_wave(int v) { return sid->voice[v].wave()->waveform_output; }
unsigned sid_env(int v) { return sid->voice[v].envelope()->envelope_counter; }
unsigned sid_acc(int v) { return sid->voice[v].wave()->accumulator; }
unsigned sid_bus(void) { return sid->busValue; }
// Debug observation of the noise shifter.
unsigned sid_sr(int v) { return sid->voice[v].wave()->shift_register; }
unsigned sid_latch(int v) { return sid->voice[v].wave()->shift_latch; }
unsigned sid_pipe(int v) { return unsigned(sid->voice[v].wave()->shift_pipeline); }
unsigned sid_noise(int v) { return sid->voice[v].wave()->noise_output; }
// Pull-down table entry: table 0..4 (TS, PT, PS, PTS, NP), 12-bit index.
unsigned sid_pulldown(int table, unsigned index) {
    return unsigned((*pulldown)[table][index & 0xfff]);
}
}
