// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x5401.md.
// ttl_74x5401 - 11-bit line/memory driver, inverting (3-state).
module ttl_74x5401 (
    input  logic        oe_n,
    input  logic [10:0] a,
    output logic [10:0] y,
    output logic        hiz
);
    assign y   = oe_n ? 11'b0 : ~a;
    assign hiz = oe_n;
endmodule
