// ASSUMPTION: The phase-accumulator model preserves long-run pulse rate and gating, not the exact native rate-multiplier pulse positions.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x167 - Synchronous decade rate multiplier.
// Outputs pulses at rate (decade BCD value) / 10. Phase-accumulator BRM.
module ttl_74x167 (
    input  logic       clk,
    input  logic       ena_n,
    input  logic       clr_n,
    input  logic [3:0] rate,    // BCD 0..9
    output logic       y,
    output logic       y_n
);
    logic [3:0] phase;
    logic       carry_q;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            phase   <= 4'd0;
            carry_q <= 1'b0;
        end else begin
            logic [4:0] sum;
            sum = {1'b0, phase} + {1'b0, rate};
            if (sum >= 5'd10) begin
                phase   <= sum[3:0] - 4'd10;
                carry_q <= 1'b1;
            end else begin
                phase   <= sum[3:0];
                carry_q <= 1'b0;
            end
        end
    end

    assign y   = (!ena_n) ? carry_q : 1'b0;
    assign y_n = ~y;
endmodule
