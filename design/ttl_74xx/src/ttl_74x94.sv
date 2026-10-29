// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x94 - 4-bit shift register with dual asynchronous presets
//
// 4-bit shift register. Two sets of async preset inputs (pre_a, pre_b)
// each with a "select" gate (pa, pb). When pa is high, the register is
// async-loaded with pre_a. When pb is high (and pa is low), loaded with
// pre_b. Otherwise on posedge clk, shifts right: q <= {din, q[3:1]}.
// =============================================================================

module ttl_74x94 (
    input  logic       clk,
    input  logic       din,        // serial in
    input  logic       pa,         // preset-A enable (async, active high)
    input  logic       pb,         // preset-B enable (async, active high)
    input  logic [3:0] pre_a,
    input  logic [3:0] pre_b,
    output logic [3:0] q
);
    always_ff @(posedge clk or posedge pa or posedge pb) begin
        if (pa)      q <= pre_a;
        else if (pb) q <= pre_b;
        else         q <= {q[2:0], din};
    end
endmodule
