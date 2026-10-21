// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x29828.md.
// ttl_74x29828 - 10-bit bus buffer/driver, inverting (= 74x2828).
module ttl_74x29828 (
    input  logic        oe_n,
    input  logic [9:0]  a,
    output logic [9:0]  y,
    output logic        hiz
);
    assign y   = oe_n ? 10'b0 : ~a;
    assign hiz = oe_n;
endmodule
