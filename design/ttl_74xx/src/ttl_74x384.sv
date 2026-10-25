// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x384.md.
// ttl_74x384 - 8-bit by 1-bit two's complement multiplier.
// y = a * b (8-bit signed times 1-bit), result is 9 bits (signed).
module ttl_74x384 (
    input  logic signed [7:0] a,
    input  logic              b,
    output logic signed [8:0] y
);
    assign y = b ? {a[7], a} : 9'sb0;
endmodule
