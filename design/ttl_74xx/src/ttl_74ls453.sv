// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls453.md.
// ttl_74ls453 - Quad 4-to-1 multiplexer.
module ttl_74ls453 (
    input  logic [1:0] s,
    input  logic [3:0] g_n,
    input  logic [3:0] d0, d1, d2, d3,
    output logic [3:0] y
);
    assign y[0] = g_n[0] ? 1'b0 : d0[s];
    assign y[1] = g_n[1] ? 1'b0 : d1[s];
    assign y[2] = g_n[2] ? 1'b0 : d2[s];
    assign y[3] = g_n[3] ? 1'b0 : d3[s];
endmodule
