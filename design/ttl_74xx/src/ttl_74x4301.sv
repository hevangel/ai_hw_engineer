// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4301.md.
// ttl_74x4301 - 8-bit transparent latch, inverting (3-state).
module ttl_74x4301 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_latch if (le) r = d;
    assign q   = oe_n ? 8'b0 : ~r;
    assign hiz = oe_n;
endmodule
