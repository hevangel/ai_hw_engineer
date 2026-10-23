// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x365.md.
// ttl_74x365 - Hex buffer, non-inverting, 3-state.
module ttl_74x365 (
    input  logic [5:0] a,
    input  logic       g1_n, g2_n,
    output logic [5:0] y
);
    logic enable;
    assign enable = !g1_n && !g2_n;
    assign y = enable ? a : 6'h00;
endmodule
