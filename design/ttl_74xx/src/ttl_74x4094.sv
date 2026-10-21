// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4094.md.
// ttl_74x4094 - 8-bit 3-state shift register / latch.
// Serial shift on posedge clk; transparent storage latch on negedge stb
// (transparent when stb=1, hold when stb=0); parallel outputs are 3-state
// (oe enabled when oe=1).
module ttl_74x4094 (
    input  logic       clk, stb, oe, ser,
    output logic [7:0] q,
    output logic       qs1, qs2
);
    logic [7:0] sr, latch_q;
    always_ff @(posedge clk) sr <= {sr[6:0], ser};
    always_latch if (stb) latch_q = sr;
    assign q   = oe ? latch_q : 8'b0;
    assign qs1 = sr[7];
    assign qs2 = sr[7];
endmodule
