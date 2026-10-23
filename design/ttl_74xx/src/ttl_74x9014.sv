// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9014.md.
// ttl_74x9014 - 9-bit buffer / line driver, inverting (3-state).
module ttl_74x9014 (
    input  logic       oe_n,
    input  logic [8:0] a,
    output logic [8:0] y,
    output logic       hiz
);
    assign y   = oe_n ? 9'b0 : ~a;
    assign hiz = oe_n;
endmodule
