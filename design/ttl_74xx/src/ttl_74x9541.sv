// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9541.md.
// ttl_74x9541 - 8-bit buffer / line driver, selectable inverting/non-inverting.
// Same logic as ttl_74x8541.
module ttl_74x9541 (
    input  logic       oe_n, inv,
    input  logic [7:0] a,
    output logic [7:0] y,
    output logic       hiz
);
    assign y   = oe_n ? 8'b0 : (inv ? ~a : a);
    assign hiz = oe_n;
endmodule
