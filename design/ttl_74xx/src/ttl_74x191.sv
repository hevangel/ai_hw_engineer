// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x191 - Synchronous 4-bit up/down binary counter (no clear).
module ttl_74x191 (
    input  logic       clk,
    input  logic       load_n,
    input  logic       ctr_en_n,
    input  logic       d_u_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       max_min,
    output logic       rco_n
);
    always_ff @(posedge clk or negedge load_n) begin
        if (!load_n)         q <= d;
        else if (!ctr_en_n) begin
            if (!d_u_n) q <= q + 4'd1;
            else        q <= q - 4'd1;
        end
    end
    assign max_min = (!d_u_n && q == 4'hF) || (d_u_n && q == 4'h0);
    assign rco_n   = ~(max_min && !ctr_en_n);
endmodule
