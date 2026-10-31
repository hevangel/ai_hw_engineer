// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1002.md.
// ttl_74x1002 - Quad 2-input NOR gate (driver). High-drive variant of 74x02.
module ttl_74x1002 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule
