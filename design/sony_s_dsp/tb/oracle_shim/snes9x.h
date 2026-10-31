// Minimal stand-in for the snes9x host header so that the pinned SPC_DSP
// reference compiles alone. Gaussian interpolation (method 2), shared echo
// RAM and no MSU-1: the configuration that models the real chip.
#pragma once
#include <vector>
struct S9xSettingsShim {
    int InterpolationMethod = 2;
    bool SeparateEchoBuffer = false;
    bool MSU1 = false;
};
extern S9xSettingsShim Settings;
inline void S9xMSU1Generate(int) {}
class Resampler {
public:
    std::vector<short> samples;
    void push_sample(short l, short r) { samples.push_back(l); samples.push_back(r); }
};
