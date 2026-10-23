// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x190 - Synchronous 4-bit up/down BCD decade counter.
// d_u_n: 1=down, 0=up; ctr_en_n: active-low count enable.
// load_n: async parallel load (active low).
module ttl_74x190 (
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
        if (!load_n)            q <= d;
        else if (!ctr_en_n) begin
            if (!d_u_n) begin
                if (q == 4'd9) q <= 4'd0;
                else           q <= q + 4'd1;
            end else begin
                if (q == 4'd0) q <= 4'd9;
                else           q <= q - 4'd1;
            end
        end
    end
    assign max_min = (!d_u_n && q == 4'd9) || (d_u_n && q == 4'd0);
    assign rco_n   = ~(max_min && !ctr_en_n);
endmodule
