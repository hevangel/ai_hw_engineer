// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2828.md.
// ttl_74x2828 - 10-bit buffer, inverting (3-state).
module ttl_74x2828 (
    input  logic        oe_n,
    input  logic [9:0]  a,
    output logic [9:0]  y,
    output logic        hiz
);
    assign y   = oe_n ? 10'b0 : ~a;
    assign hiz = oe_n;
endmodule
