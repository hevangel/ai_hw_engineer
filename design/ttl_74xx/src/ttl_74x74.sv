// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x74 - Dual D positive-edge-triggered flip-flop, async clear & preset
//
// Two independent D flip-flops. Each has:
//   - posedge-triggered D capture
//   - asynchronous active-low clear (clr_n)
//   - asynchronous active-low preset (pre_n)
//
// Truth table priority (matches datasheet "normal" operation):
//   pre_n=0          -> Q <- 1
//   pre_n=1, clr_n=0 -> Q <- 0
//   else, posedge clk -> Q <- D
//
// Both controls asserted force Q=Q_n=1, as specified by the LS74A table.
// Effective clear becomes active when preset releases with clear held low.
// Simultaneous release of both controls is an unspecified recovery case.
//
// Datasheet: TI SN74LS74A.
// =============================================================================

module ttl_74x74 (
    input  logic [1:0] clk,
    input  logic [1:0] d,
    input  logic [1:0] clr_n,
    input  logic [1:0] pre_n,
    output logic [1:0] q,
    output logic [1:0] q_n
);
    logic q_0, q_1;
    logic [1:0] effective_clear_n;
    assign effective_clear_n = clr_n | ~pre_n;
    assign q = {q_1, q_0};

    // Flip-flop 0
    always_ff @(posedge clk[0] or negedge effective_clear_n[0] or negedge pre_n[0]) begin
        if (!pre_n[0])      q_0 <= 1'b1;
        else if (!effective_clear_n[0]) q_0 <= 1'b0;
        else                q_0 <= d[0];
    end

    // Flip-flop 1
    always_ff @(posedge clk[1] or negedge effective_clear_n[1] or negedge pre_n[1]) begin
        if (!pre_n[1])      q_1 <= 1'b1;
        else if (!effective_clear_n[1]) q_1 <= 1'b0;
        else                q_1 <= d[1];
    end

    assign q_n = ~q | ~(pre_n | clr_n);

endmodule
