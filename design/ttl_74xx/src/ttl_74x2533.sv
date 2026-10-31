// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2533.md.
// ttl_74x2533 - 8-bit bus interface latch, inverting (= 74x533).
module ttl_74x2533 (
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
