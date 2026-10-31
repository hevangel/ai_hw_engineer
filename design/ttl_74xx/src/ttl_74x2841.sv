// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2841.md.
// ttl_74x2841 - 10-bit transparent latch (3-state).
module ttl_74x2841 (
    input  logic        oe_n, le,
    input  logic [9:0]  d,
    output logic [9:0]  q,
    output logic        hiz
);
    logic [9:0] r;
    always_latch if (le) r = d;
    assign q   = oe_n ? 10'b0 : r;
    assign hiz = oe_n;
endmodule
