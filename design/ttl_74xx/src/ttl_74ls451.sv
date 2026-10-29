// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls451.md.
// ttl_74ls451 - Dual 8-to-1 multiplexer.
module ttl_74ls451 (
    input  logic [2:0] s,
    input  logic [1:0] g_n,
    input  logic [7:0] d0, d1,
    output logic [1:0] y
);
    assign y[0] = g_n[0] ? 1'b0 : d0[s];
    assign y[1] = g_n[1] ? 1'b0 : d1[s];
endmodule
