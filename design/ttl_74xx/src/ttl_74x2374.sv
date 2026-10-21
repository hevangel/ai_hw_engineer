// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2374.md.
// ttl_74x2374 - Octal D-type flip-flop (3-state) (= 74x374).
module ttl_74x2374 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] q_reg;
    always_ff @(posedge clk) q_reg <= d;
    assign q = oe_n ? 8'h00 : q_reg;
endmodule
