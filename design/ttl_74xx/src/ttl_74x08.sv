// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x08 - Quad 2-input AND gate
//
// Original part number : 74x08 (74LS08, 74HC08, 74AS08, 74F08, ...)
// Description          : Four independent 2-input AND gates in a 14-pin DIP.
// Datasheet reference  : TI SN74LS08 (https://www.ti.com/lit/gpn/sn74ls08)
//
// FPGA notes
// ----------
//   y[i] = a[i] & b[i]
// Pure combinational. Four LUT2s.
//
// Unsupported physical behavior: none.
// =============================================================================

module ttl_74x08 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = a & b;

endmodule
