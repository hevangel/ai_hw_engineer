// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9595.md.
// ttl_74x9595 - 8-bit shift register with output latch (serial-in, parallel-out).
// Serial data shifts into `sr` on posedge clk; the latch captures `sr` on
// posedge lclk; the output `q` is gated by oe_n.
module ttl_74x9595 (
    input  logic       clk, lclk, oe_n, clr_n, ser,
    output logic [7:0] q,
    output logic       qs
);
    logic [7:0] sr, latch_q;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) sr <= 8'b0;
        else        sr <= {sr[6:0], ser};
    end
    always_ff @(posedge lclk) latch_q <= sr;
    assign q  = oe_n ? 8'b0 : latch_q;
    assign qs = sr[7];
endmodule
