// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4302.md.
// ttl_74x4302 - 8-bit transparent latch, non-inverting (3-state).
module ttl_74x4302 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_latch if (le) r = d;
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
