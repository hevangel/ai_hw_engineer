// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x390.md.
// ttl_74x390 - Dual 4-bit decade counter, async clear.
module ttl_74x390 (
    input  logic [1:0] clk_a,        // ÷2 section clocks
    input  logic [1:0] clk_b,        // ÷5 section clocks
    input  logic [1:0] clr,          // active high
    output logic [3:0] q0,
    output logic [3:0] q1
);
    logic [2:0] cnt5_0, cnt5_1;

    always_ff @(negedge clk_a[0] or posedge clr[0]) begin
        if (clr[0]) q0[0] <= 1'b0;
        else        q0[0] <= ~q0[0];
    end
    always_ff @(negedge clk_b[0] or posedge clr[0]) begin
        if (clr[0])              cnt5_0 <= 3'b000;
        else if (cnt5_0 == 3'b100) cnt5_0 <= 3'b000;
        else                     cnt5_0 <= cnt5_0 + 3'b001;
    end
    assign q0[1] = cnt5_0[0];
    assign q0[2] = cnt5_0[1];
    assign q0[3] = cnt5_0[2];

    always_ff @(negedge clk_a[1] or posedge clr[1]) begin
        if (clr[1]) q1[0] <= 1'b0;
        else        q1[0] <= ~q1[0];
    end
    always_ff @(negedge clk_b[1] or posedge clr[1]) begin
        if (clr[1])              cnt5_1 <= 3'b000;
        else if (cnt5_1 == 3'b100) cnt5_1 <= 3'b000;
        else                     cnt5_1 <= cnt5_1 + 3'b001;
    end
    assign q1[1] = cnt5_1[0];
    assign q1[2] = cnt5_1[1];
    assign q1[3] = cnt5_1[2];
endmodule
