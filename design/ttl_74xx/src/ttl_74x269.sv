// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x269 - 8-bit bidirectional binary counter.
module ttl_74x269 (
    input  logic       clk,
    input  logic       load_n,
    input  logic       ctr_en_n,
    input  logic       d_u_n,         // 1=down, 0=up
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       rco_n
);
    always_ff @(posedge clk) begin
        if (!load_n)        q <= d;
        else if (!ctr_en_n) begin
            if (!d_u_n) q <= q + 8'd1;
            else        q <= q - 8'd1;
        end
    end
    assign rco_n = ~(((!d_u_n && q == 8'hFF) || (d_u_n && q == 8'h00)) && !ctr_en_n);
endmodule
