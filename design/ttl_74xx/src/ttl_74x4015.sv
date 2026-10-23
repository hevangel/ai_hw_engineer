// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4015.md.
// ttl_74x4015 - Dual 4-bit serial-in / parallel-out shift register.
// Each half: clk shifts serial_in into bit 0; bits propagate toward bit 3.
// Async clear sets all bits low.
module ttl_74x4015 (
    input  logic        clk_a, clr_a, sin_a,
    output logic [3:0]  q_a,
    input  logic        clk_b, clr_b, sin_b,
    output logic [3:0]  q_b
);
    always_ff @(posedge clk_a or posedge clr_a) begin
        if (clr_a) q_a <= 4'b0;
        else        q_a <= {q_a[2:0], sin_a};
    end
    always_ff @(posedge clk_b or posedge clr_b) begin
        if (clr_b) q_b <= 4'b0;
        else        q_b <= {q_b[2:0], sin_b};
    end
endmodule
