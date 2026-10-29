// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3827.md.
// ttl_74x3827 - 10-bit buffer, non-inverting (3-state). Same as ttl_74x2827.
module ttl_74x3827 (
    input  logic        oe_n,
    input  logic [9:0]  a,
    output logic [9:0]  y,
    output logic        hiz
);
    assign y   = oe_n ? 10'b0 : a;
    assign hiz = oe_n;
endmodule
