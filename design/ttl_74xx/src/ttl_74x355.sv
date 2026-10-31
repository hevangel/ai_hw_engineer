// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x355.md.
// ttl_74x355 - 8-to-1 mux with transparent registers.
// Same shape as 74x354.
module ttl_74x355 (
    input  logic       le,
    input  logic       oe_n,
    input  logic [2:0] s,
    input  logic [7:0] d,
    output logic       y
);
    logic [7:0] latch_d;
    always_latch begin
        if (le) latch_d = d;
    end
    assign y = oe_n ? 1'b0 : latch_d[s];
endmodule
