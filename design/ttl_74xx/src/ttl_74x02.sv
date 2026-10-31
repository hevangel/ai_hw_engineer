// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x02 - Quad 2-input NOR gate
//
// Original part number : 74x02 (74LS02, 74HC02, 74AS02, 74F02, ...)
// Description          : Four independent 2-input NOR gates in a 14-pin DIP.
// Datasheet reference  : TI SN74LS02 (https://www.ti.com/lit/gpn/sn74ls02)
//
// FPGA notes
// ----------
//   y[i] = ~(a[i] | b[i])
// Pure combinational. The pinout of 74x02 differs from 74x00: on the real
// part, output Y appears first on each gate (pins 1, 4, 10, 13) and the A/B
// inputs follow. The RTL exposes a/b/y vectors and the README documents
// the physical pin map.
//
// Unsupported physical behavior: none.
// =============================================================================

module ttl_74x02 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = ~(a | b);

endmodule
