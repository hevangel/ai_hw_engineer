// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x5074.md.
// ttl_74x5074 - Dual D-type FF, positive-edge triggered (metastable-immune).
// Each FF has its own clock, async clr_n/pre_n, and an internal dual-rank
// synchronizer that mitigates metastability on the d input.
module ttl_74x5074 (
    input  logic clk1, clr1_n, pre1_n, d1,
    output logic q1, q1_n,
    input  logic clk2, clr2_n, pre2_n, d2,
    output logic q2, q2_n
);
    logic stage1_a, stage1_b, stage2_a, stage2_b;
    always_ff @(posedge clk1 or negedge clr1_n or negedge pre1_n) begin
        if (!clr1_n)      begin stage1_a <= 0; stage1_b <= 0; end
        else if (!pre1_n) begin stage1_a <= 1; stage1_b <= 1; end
        else              begin stage1_a <= d1; stage1_b <= stage1_a; end
    end
    always_ff @(posedge clk2 or negedge clr2_n or negedge pre2_n) begin
        if (!clr2_n)      begin stage2_a <= 0; stage2_b <= 0; end
        else if (!pre2_n) begin stage2_a <= 1; stage2_b <= 1; end
        else              begin stage2_a <= d2; stage2_b <= stage2_a; end
    end
    assign q1   =  stage1_b;
    assign q1_n = ~stage1_b;
    assign q2   =  stage2_b;
    assign q2_n = ~stage2_b;
endmodule
