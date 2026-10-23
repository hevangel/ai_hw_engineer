// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1011.md.
// ttl_74x1011 - Triple 3-input AND gate (driver). High-drive variant of 74x11.
module ttl_74x1011 (
    input  logic [2:0] a, b, c,
    output logic [2:0] y
);
    assign y = a & b & c;
endmodule
