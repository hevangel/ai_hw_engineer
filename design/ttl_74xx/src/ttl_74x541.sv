// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x541.md.
// ttl_74x541 - octal buffer/line driver, non-inverting, 3-state.
module ttl_74x541 (
    input  logic       g1_n, g2_n,
    input  logic [7:0] a,
    output logic [7:0] y,
    output logic       hiz
);
    logic enable;
    assign enable = !g1_n && !g2_n;
    assign y   = enable ? a : 8'b0;
    assign hiz = !enable;
endmodule
