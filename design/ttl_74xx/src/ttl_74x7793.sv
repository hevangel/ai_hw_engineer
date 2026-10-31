// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7793.md.
// ttl_74x7793 - 8-bit non-inverting transparent latch with readback.
// Standard transparent latch on `d` controlled by `le`; the latched value
// is always visible on `q_rb` (readback) and is driven to the 3-state `q`
// output when `oe_n` is low.
module ttl_74x7793 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic [7:0] q_rb,
    output logic       hiz
);
    logic [7:0] r;
    always_latch if (le) r = d;
    assign q    = oe_n ? 8'b0 : r;
    assign q_rb = r;
    assign hiz  = oe_n;
endmodule
