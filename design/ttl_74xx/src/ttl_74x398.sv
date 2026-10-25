// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x398.md.
// ttl_74x398 - Quad 2-input mux with storage and complementary outputs.
module ttl_74x398 (
    input  logic       clk,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    always_ff @(posedge clk) q <= select ? b : a;
    assign q_n = ~q;
endmodule
