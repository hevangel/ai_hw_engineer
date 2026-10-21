// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1803.md.
// ttl_74x1803 - Quad clock driver (4 non-inverting buffers with extra drive strength).
module ttl_74x1803 (
    input  logic [3:0] a,
    output logic [3:0] y
);
    assign y = a;
endmodule
