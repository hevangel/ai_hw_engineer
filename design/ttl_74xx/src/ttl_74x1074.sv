// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1074.md.
// ttl_74x1074 - Dual D negative-edge-triggered flip-flop with async /PRE and /CLR.
//
// Per typical 74FR1074 datasheet: two flops sharing only Vcc/GND. Each has
// its own data, clock (negative-edge), async preset and clear, and dual Q/Qbar
// outputs. Clear takes priority over preset when both are asserted (matching
// the standard 74x74 family convention).
module ttl_74x1074 (
    input  logic       clk1_n,
    input  logic       pre1_n,
    input  logic       clr1_n,
    input  logic       d1,
    output logic       q1,
    output logic       q1_n,
    input  logic       clk2_n,
    input  logic       pre2_n,
    input  logic       clr2_n,
    input  logic       d2,
    output logic       q2,
    output logic       q2_n
);
    // Negative-edge clock implemented as posedge of inverted clock.
    logic q1_int, q2_int;

    always_ff @(negedge clk1_n or negedge clr1_n or negedge pre1_n) begin
        if (!clr1_n)      q1_int <= 1'b0;
        else if (!pre1_n) q1_int <= 1'b1;
        else              q1_int <= d1;
    end

    always_ff @(negedge clk2_n or negedge clr2_n or negedge pre2_n) begin
        if (!clr2_n)      q2_int <= 1'b0;
        else if (!pre2_n) q2_int <= 1'b1;
        else              q2_int <= d2;
    end

    assign q1   =  q1_int;
    assign q1_n = ~q1_int;
    assign q2   =  q2_int;
    assign q2_n = ~q2_int;
endmodule
