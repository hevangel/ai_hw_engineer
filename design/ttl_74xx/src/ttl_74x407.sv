// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x407.md.
// ttl_74x407 - Data access register (transparent latch with 3-state output).
module ttl_74x407 (
    input  logic       le,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;
    always_latch begin
        if (le) latch_q = d;
    end
    assign q = oe_n ? 8'h00 : latch_q;
endmodule
