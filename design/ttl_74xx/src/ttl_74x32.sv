// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x32 - Quad 2-input OR gate
//
// Original part number : 74x32 (74LS32, 74HC32, 74AS32, 74F32, ...)
// Description          : Four independent 2-input OR gates in a 14-pin DIP.
// Datasheet reference  : TI SN74LS32 (https://www.ti.com/lit/gpn/sn74ls32)
//
// FPGA notes
// ----------
//   y[i] = a[i] | b[i]
// Pure combinational. Four LUT2s.
//
// Unsupported physical behavior: none.
// =============================================================================

module ttl_74x32 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = a | b;

endmodule
