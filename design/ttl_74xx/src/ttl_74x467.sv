// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x467.md.
// ttl_74x467 - Octal buffer, non-inverting (same as 74x465).
module ttl_74x467 (
    input  logic [7:0] a,
    input  logic       g1_n, g2_n,
    output logic [7:0] y
);
    logic en;
    assign en = !g1_n && !g2_n;
    assign y = en ? a : 8'h00;
endmodule
