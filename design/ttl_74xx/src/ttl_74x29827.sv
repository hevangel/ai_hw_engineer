// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x29827.md.
// ttl_74x29827 - 10-bit bus buffer/driver, non-inverting (= 74x2827).
module ttl_74x29827 (
    input  logic        oe_n,
    input  logic [9:0]  a,
    output logic [9:0]  y,
    output logic        hiz
);
    assign y   = oe_n ? 10'b0 : a;
    assign hiz = oe_n;
endmodule
