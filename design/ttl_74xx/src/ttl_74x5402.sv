// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x5402.md.
// ttl_74x5402 - 12-bit line/memory driver, non-inverting (3-state).
module ttl_74x5402 (
    input  logic        oe_n,
    input  logic [11:0] a,
    output logic [11:0] y,
    output logic        hiz
);
    assign y   = oe_n ? 12'b0 : a;
    assign hiz = oe_n;
endmodule
