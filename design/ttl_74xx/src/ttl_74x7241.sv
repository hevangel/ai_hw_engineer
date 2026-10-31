// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7241.md.
// ttl_74x7241 - Octal bus buffer, non-inverting (= 74x241).
module ttl_74x7241 (
    input  logic       oe1_n, oe2,
    input  logic [3:0] a1, a2,
    output logic [3:0] y1, y2,
    output logic       hiz1, hiz2
);
    assign y1   = oe1_n ? 4'b0 : a1;
    assign y2   = oe2   ? a2   : 4'b0;
    assign hiz1 = oe1_n;
    assign hiz2 = ~oe2;
endmodule
