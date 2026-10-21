// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x163 - 4-bit synchronous binary counter with synchronous clear/load
//
// Functions on posedge clk, priority high to low:
//   clr_n = 0  -> q <= 0           (synchronous clear)
//   load_n = 0 -> q <= d           (synchronous load)
//   enp & ent  -> q <= q + 1       (count)
//   else       -> q <= q           (hold)
//
// Combinational ripple-carry output:
//   rco = (q == 4'hF) & ent
//
// Note: 74x161 is the same chip except clear is ASYNCHRONOUS.
// =============================================================================

module ttl_74x163 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic       enp,
    input  logic       ent,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       rco
);
    always_ff @(posedge clk) begin
        if (!clr_n)         q <= 4'b0000;
        else if (!load_n)   q <= d;
        else if (enp & ent) q <= q + 4'b0001;
        // else hold
    end

    assign rco = (q == 4'hF) & ent;
endmodule
