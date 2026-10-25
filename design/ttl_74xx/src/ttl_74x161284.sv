// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x161284.md.
// ttl_74x161284 - 19-bit bus interface.
// 19-bit version of ttl_74x245 with a 3-state output enable.
module ttl_74x161284 (
    input  logic        oe_n, dir,
    input  logic [18:0] a_in, b_in,
    output logic [18:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 19'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 19'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
