// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9114.md.
// ttl_74x9114 - 9-bit inverter (3-state).
module ttl_74x9114 (
    input  logic       oe_n,
    input  logic [8:0] a,
    output logic [8:0] y,
    output logic       hiz
);
    assign y   = oe_n ? 9'b0 : ~a;
    assign hiz = oe_n;
endmodule
