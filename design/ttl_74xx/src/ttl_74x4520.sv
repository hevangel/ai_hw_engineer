// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4520.md.
// ttl_74x4520 - Dual 4-bit synchronous binary counter.
module ttl_74x4520 (
    input  logic       clk_a, en_a, rst_a,
    output logic [3:0] q_a,
    input  logic       clk_b, en_b, rst_b,
    output logic [3:0] q_b
);
    always_ff @(posedge clk_a or posedge rst_a) begin
        if (rst_a)    q_a <= 4'd0;
        else if (en_a) q_a <= q_a + 4'd1;
    end
    always_ff @(posedge clk_b or posedge rst_b) begin
        if (rst_b)    q_b <= 4'd0;
        else if (en_b) q_b <= q_b + 4'd1;
    end
endmodule
