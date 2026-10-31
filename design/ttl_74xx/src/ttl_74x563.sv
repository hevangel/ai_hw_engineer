// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x563.md.
// ttl_74x563 - octal D-type transparent latch, inverting outputs, 3-state.
module ttl_74x563 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q_n,
    output logic       hiz
);
    logic [7:0] r;
    always_latch if (le) r = d;
    assign q_n = oe_n ? 8'b0 : ~r;
    assign hiz = oe_n;
endmodule
