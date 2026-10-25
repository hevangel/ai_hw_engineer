// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x29821.md.
// ttl_74x29821 - 10-bit bus interface flip-flops (= 74x2821).
module ttl_74x29821 (
    input  logic        clk, oe_n,
    input  logic [9:0]  d,
    output logic [9:0]  q,
    output logic        hiz
);
    logic [9:0] r;
    always_ff @(posedge clk) r <= d;
    assign q   = oe_n ? 10'b0 : r;
    assign hiz = oe_n;
endmodule
