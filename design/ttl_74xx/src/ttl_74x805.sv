// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x805.md.
// ttl_74x805 - hex 2-input NOR drivers.
module ttl_74x805 (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);
    assign y = ~(a | b);
endmodule
