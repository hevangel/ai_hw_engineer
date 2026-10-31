// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x531.md.
// ttl_74x531 - octal transparent latch with 3-state outputs (digital model: muxed Hi-Z bit).
module ttl_74x531 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] latch_q;
    always_latch if (le) latch_q = d;
    assign q   = oe_n ? 8'b0 : latch_q;
    assign hiz = oe_n;
endmodule
