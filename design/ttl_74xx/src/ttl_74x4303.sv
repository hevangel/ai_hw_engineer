// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4303.md.
// ttl_74x4303 - 8-bit D flip-flop, inverting outputs (3-state).
module ttl_74x4303 (
    input  logic       clk, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_ff @(posedge clk) r <= d;
    assign q   = oe_n ? 8'b0 : ~r;
    assign hiz = oe_n;
endmodule
