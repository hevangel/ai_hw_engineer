// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2540.md.
// ttl_74x2540 - Octal buffer/line driver, inverting (= 74x540).
module ttl_74x2540 (
    input  logic       g1_n, g2_n,
    input  logic [7:0] a,
    output logic [7:0] y_n,
    output logic       hiz
);
    logic enable;
    assign enable = !g1_n && !g2_n;
    assign y_n   = enable ? ~a : 8'b0;
    assign hiz   = !enable;
endmodule
