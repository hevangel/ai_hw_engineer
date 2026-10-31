// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x876.md.
// ttl_74x876 - Dual 4-bit edge-triggered D flip-flop with set, inverting (3-state).
// Like ttl_74x874 but each unit's async control is /PRE (set to 1) instead of
// /CLR, and Q outputs are inverted.
module ttl_74x876 (
    input  logic       clk1,
    input  logic       pre1_n,
    input  logic       oe1_n,
    input  logic [3:0] d1,
    output logic [3:0] q1,
    output logic       q1_oe_n,
    input  logic       clk2,
    input  logic       pre2_n,
    input  logic       oe2_n,
    input  logic [3:0] d2,
    output logic [3:0] q2,
    output logic       q2_oe_n
);
    logic [3:0] q1_lat, q2_lat;

    always_ff @(posedge clk1 or negedge pre1_n) begin
        if (!pre1_n) q1_lat <= 4'hF;
        else         q1_lat <= d1;
    end

    always_ff @(posedge clk2 or negedge pre2_n) begin
        if (!pre2_n) q2_lat <= 4'hF;
        else         q2_lat <= d2;
    end

    assign q1_oe_n = oe1_n;
    assign q2_oe_n = oe2_n;
    assign q1      = oe1_n ? 4'b0 : ~q1_lat;
    assign q2      = oe2_n ? 4'b0 : ~q2_lat;
endmodule
