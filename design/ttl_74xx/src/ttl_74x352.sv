// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x352.md.
// ttl_74x352 - Dual 4-to-1 mux, inverting outputs.
module ttl_74x352 (
    input  logic [1:0] s,
    input  logic [1:0] g_n,
    input  logic [3:0] d0, d1,
    output logic [1:0] y_n
);
    assign y_n[0] = g_n[0] ? 1'b1 : ~d0[s];
    assign y_n[1] = g_n[1] ? 1'b1 : ~d1[s];
endmodule
