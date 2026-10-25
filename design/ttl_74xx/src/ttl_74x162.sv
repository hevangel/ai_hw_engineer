// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x162 - Synchronous presettable 4-bit BCD decade counter, sync clear.
module ttl_74x162 (
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
        if (!clr_n)              q <= 4'd0;
        else if (!load_n)        q <= d;
        else if (enp & ent) begin
            if (q == 4'd9)       q <= 4'd0;
            else                 q <= q + 4'd1;
        end
    end
    assign rco = (q == 4'd9) & ent;
endmodule
