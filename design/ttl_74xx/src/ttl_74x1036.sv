// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1036.md.
// ttl_74x1036 - Quad 2-input NOR gate (driver). High-drive variant of 74x02.
module ttl_74x1036 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule
