// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x379.md.
// ttl_74x379 - 4-bit register with clock enable and complementary outputs.
module ttl_74x379 (
    input  logic       clk,
    input  logic       ce_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    always_ff @(posedge clk) begin
        if (!ce_n) q <= d;
    end
    assign q_n = ~q;
endmodule
