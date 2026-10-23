// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1008.md.
// ttl_74x1008 - Quad 2-input AND gate (driver). High-drive variant of 74x08.
module ttl_74x1008 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = a & b;
endmodule
