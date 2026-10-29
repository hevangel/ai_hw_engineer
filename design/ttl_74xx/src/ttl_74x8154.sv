// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8154.md.
// ttl_74x8154 - Dual 16-bit counters with output registers.
// Two independent 16-bit binary up counters, each with its own clock,
// enable, async clear, and a parallel output register sampled on `reg_clk`.
module ttl_74x8154 (
    input  logic        clk_a, en_a, clr_a_n, reg_clk_a,
    output logic [15:0] q_a,
    input  logic        clk_b, en_b, clr_b_n, reg_clk_b,
    output logic [15:0] q_b
);
    logic [15:0] cnt_a, cnt_b;
    always_ff @(posedge clk_a or negedge clr_a_n) begin
        if (!clr_a_n) cnt_a <= 16'd0;
        else if (en_a) cnt_a <= cnt_a + 16'd1;
    end
    always_ff @(posedge clk_b or negedge clr_b_n) begin
        if (!clr_b_n) cnt_b <= 16'd0;
        else if (en_b) cnt_b <= cnt_b + 16'd1;
    end
    always_ff @(posedge reg_clk_a) q_a <= cnt_a;
    always_ff @(posedge reg_clk_b) q_b <= cnt_b;
endmodule
