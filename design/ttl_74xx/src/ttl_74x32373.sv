// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32373.md.
// ttl_74x32373 - 32-bit D-type latches (= 74x373 widened to 32 bits).
module ttl_74x32373 (
    input  logic        le, oe_n,
    input  logic [31:0] d,
    output logic [31:0] q,
    output logic        hiz
);
    logic [31:0] r;
    always_latch if (le) r = d;
    assign q   = oe_n ? 32'b0 : r;
    assign hiz = oe_n;
endmodule
