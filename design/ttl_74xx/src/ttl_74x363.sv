// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x363.md.
// ttl_74x363 - Octal transparent latch (same as 74x373).
module ttl_74x363 (
    input  logic       oe_n,
    input  logic       le,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;
    always_latch begin
        if (le) latch_q = d;
    end
    assign q = oe_n ? 8'h00 : latch_q;
endmodule
