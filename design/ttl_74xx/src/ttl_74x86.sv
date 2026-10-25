// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x86 - Quad 2-input XOR gate
//
// Original part number : 74x86 (74LS86, 74HC86, 74AS86, 74F86, ...)
// Description          : Four independent 2-input XOR gates in a 14-pin DIP.
// Datasheet reference  : TI SN74LS86A (https://www.ti.com/lit/gpn/sn74ls86a)
//
// FPGA notes
// ----------
//   y[i] = a[i] ^ b[i]
// Pure combinational. Four LUT2s. The XOR is the workhorse for adders and
// parity generators.
//
// Unsupported physical behavior: none.
// =============================================================================

module ttl_74x86 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = a ^ b;

endmodule
