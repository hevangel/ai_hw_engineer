// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x04 - Hex inverter
//
// Original part number : 74x04 (74LS04, 74HC04, 74AS04, 74F04, ...)
// Description          : Six independent inverters in a 14-pin DIP.
// Datasheet reference  : TI SN74LS04 (https://www.ti.com/lit/gpn/sn74ls04)
//
// FPGA notes
// ----------
//   y[i] = ~a[i]
// Pure combinational. Six LUT1s.
//
// Unsupported physical behavior
// -----------------------------
// The 74x04 is sometimes wrapped with a feedback resistor and crystal to
// build a Pierce-style oscillator. That use depends on the small-signal
// linear region of the CMOS inverter; this RTL is digital-only and does
// not oscillate. For an FPGA clock, use the device's PLL/MMCM.
// =============================================================================

module ttl_74x04 (
    input  logic [5:0] a,
    output logic [5:0] y
);

    assign y = ~a;

endmodule
