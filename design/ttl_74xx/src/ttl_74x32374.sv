// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32374.md.
// ttl_74x32374 - 32-bit D-type flip-flops (= 74x374 widened to 32 bits).
module ttl_74x32374 (
    input  logic        clk, oe_n,
    input  logic [31:0] d,
    output logic [31:0] q,
    output logic        hiz
);
    logic [31:0] r;
    always_ff @(posedge clk) r <= d;
    assign q   = oe_n ? 32'b0 : r;
    assign hiz = oe_n;
endmodule
