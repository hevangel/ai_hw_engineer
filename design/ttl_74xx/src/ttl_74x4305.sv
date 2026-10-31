// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4305.md.
// ttl_74x4305 - Dual 4-bit buffer, inverting (3-state).
module ttl_74x4305 (
    input  logic       oe1_n, oe2_n,
    input  logic [3:0] a1, a2,
    output logic [3:0] y1, y2,
    output logic       hiz1, hiz2
);
    assign y1   = oe1_n ? 4'b0 : ~a1;
    assign y2   = oe2_n ? 4'b0 : ~a2;
    assign hiz1 = oe1_n;
    assign hiz2 = oe2_n;
endmodule
