// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8151.md.
// ttl_74x8151 - 10-bit selectable inverting/non-inverting buffer (3-state).
module ttl_74x8151 (
    input  logic        oe_n, inv,
    input  logic [9:0]  a,
    output logic [9:0]  y,
    output logic        hiz
);
    assign y   = oe_n ? 10'b0 : (inv ? ~a : a);
    assign hiz = oe_n;
endmodule
