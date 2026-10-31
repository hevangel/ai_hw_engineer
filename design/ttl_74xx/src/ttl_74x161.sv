// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x161 - 4-bit synchronous binary counter, asynchronous clear, sync load
//
// Same as 74x163 EXCEPT clear is asynchronous.
//
// Priority:
//   clr_n = 0          -> q <= 0  (asynchronous!)
//   posedge clk:
//     load_n = 0       -> q <= d
//     enp & ent        -> q <= q + 1
//     else             -> hold
//
// rco = (q == 4'hF) & ent
// =============================================================================

module ttl_74x161 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic       enp,
    input  logic       ent,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       rco
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)         q <= 4'b0000;
        else if (!load_n)   q <= d;
        else if (enp & ent) q <= q + 4'b0001;
    end

    assign rco = (q == 4'hF) & ent;
endmodule
