// ASSUMPTION: The phase-accumulator model preserves long-run pulse rate and gating, not the exact native rate-multiplier pulse positions.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x97 - Synchronous 6-bit binary rate multiplier
//
// Outputs an average pulse rate of (rate / 64) * f_clk.
//
// Implementation: phase accumulator. Each cycle we add `rate` to a 6-bit
// phase register; the carry out is the output pulse. Over 64 cycles the
// accumulator sums to rate*64, producing exactly `rate` carries — so the
// long-run output rate equals rate/64.
// =============================================================================

module ttl_74x97 (
    input  logic       clk,
    input  logic       ena_n,
    input  logic       clr_n,
    input  logic [5:0] rate,
    output logic       y,
    output logic       y_n
);
    logic [5:0] phase;
    logic       carry_q;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            phase   <= 6'd0;
            carry_q <= 1'b0;
        end else begin
            {carry_q, phase} <= {1'b0, phase} + {1'b0, rate};
        end
    end

    assign y   = (!ena_n) ? carry_q : 1'b0;
    assign y_n = ~y;
endmodule
