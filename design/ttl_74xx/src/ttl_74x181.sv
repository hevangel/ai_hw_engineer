`timescale 1ns/1ps
// Family entry point for the independently verified original 74181.
// Carry and group generate/propagate ports retain original active-low polarity.
module ttl_74x181 (
    input logic [3:0] a, b, s,
    input logic m, cn,
    output logic [3:0] f,
    output logic cn_p_4, a_eq_b, p_n, g_n
);
    alu_74181 impl (
        .a(a), .b(b), .s(s), .m(m), .cn(cn), .f(f),
        .cn4(cn_p_4), .a_eq_b(a_eq_b), .p_bar(p_n), .g_bar(g_n)
    );
endmodule
