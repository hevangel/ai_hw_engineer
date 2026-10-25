// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x138 - 3-to-8 line decoder / demultiplexer, active-low outputs
//
// Inputs:
//   a[2:0]   : 3-bit select
//   g1       : Enable, active HIGH
//   g2a_n    : Enable, active LOW
//   g2b_n    : Enable, active LOW
// Output:
//   y_n[7:0] : Active-low decoded outputs
//
// When g1 & ~g2a_n & ~g2b_n (all enables true), y_n[a] = 0 and all others = 1.
// When any enable is false, all y_n bits are 1.
// =============================================================================

module ttl_74x138 (
    input  logic [2:0] a,
    input  logic       g1,
    input  logic       g2a_n,
    input  logic       g2b_n,
    output logic [7:0] y_n
);
    logic enable;
    assign enable = g1 & ~g2a_n & ~g2b_n;

    always_comb begin
        if (enable) begin
            y_n = 8'b11111111;
            y_n[a] = 1'b0;
        end else begin
            y_n = 8'b11111111;
        end
    end
endmodule
