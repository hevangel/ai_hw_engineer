// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x468.md.
// ttl_74x468 - Octal buffer, inverting (same as 74x466).
module ttl_74x468 (
    input  logic [7:0] a,
    input  logic       g1_n, g2_n,
    output logic [7:0] y
);
    logic en;
    assign en = !g1_n && !g2_n;
    assign y = en ? ~a : 8'h00;
endmodule
