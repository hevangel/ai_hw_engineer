// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x810.md.
// ttl_74x810 - quad 2-input XNOR gates.
module ttl_74x810 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a ^ b);
endmodule
