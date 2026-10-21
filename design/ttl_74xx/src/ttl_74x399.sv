// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x399.md.
// ttl_74x399 - Quad 2-input mux with storage. Same as 74x298.
module ttl_74x399 (
    input  logic       clk,
    input  logic       select,
    input  logic [3:0] a, b,
    output logic [3:0] q
);
    always_ff @(posedge clk) q <= select ? b : a;
endmodule
