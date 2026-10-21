// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x283 - 4-bit binary full adder with fast carry (improved pinout)
//
// Same logic as 74x83 but with a different DIP pin assignment that places
// Vcc / GND in standard corners. Often a drop-in upgrade in new designs.
// =============================================================================

module ttl_74x283 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       c0,
    output logic [3:0] sum,
    output logic       c4
);
    logic [4:0] add;
    assign add = {1'b0, a} + {1'b0, b} + {4'b0000, c0};
    assign sum = add[3:0];
    assign c4  = add[4];
endmodule
