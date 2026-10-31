// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3283.md.
// ttl_74x3283 - 32-bit latchable transceiver with parity gen/check.
// Bidirectional 32-bit transceiver with a transparent latch on each
// direction and odd-parity gen/check on the A side parity bit.
//   - leab = 1 makes the A->B path transparent; leab = 0 holds it.
//   - leba = 1 makes the B->A path transparent; leba = 0 holds it.
//   - dir selects which direction is enabled when oe_n is low.
// parity_out is the odd-parity bit covering the *currently driven* data;
// parity_in is checked against the inbound data with a sticky error flag
// (cleared by clr_n).
module ttl_74x3283 (
    input  logic        oe_n, dir,
    input  logic        leab, leba,
    input  logic        clk, clr_n,
    input  logic [31:0] a_in, b_in,
    input  logic        parity_in,
    output logic [31:0] a_out, b_out,
    output logic        parity_out,
    output logic        err_n,
    output logic        hiz
);
    logic [31:0] ab_q, ba_q;
    logic        err_reg;

    always_latch if (leab) ab_q = a_in;
    always_latch if (leba) ba_q = b_in;

    wire [31:0] tx_data = dir ? ab_q : ba_q;
    assign b_out      = (!oe_n &&  dir) ? tx_data : 32'b0;
    assign a_out      = (!oe_n && !dir) ? tx_data : 32'b0;
    assign parity_out = (!oe_n)         ? ~(^tx_data) : 1'b0;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)            err_reg <= 1'b1;
        else if (!dir && !oe_n) err_reg <= err_reg & (^{b_in, parity_in});
    end

    assign err_n = err_reg;
    assign hiz   = oe_n;
endmodule
