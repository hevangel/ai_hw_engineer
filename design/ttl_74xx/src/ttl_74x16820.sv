// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16820.md.
// ttl_74x16820 - 3.3-V 10-bit flip-flop with dual (Q and /Q) outputs (3-state).
module ttl_74x16820 (
    input  logic        clk,
    input  logic        oe_n,
    input  logic [9:0]  d,
    output logic [9:0]  q,
    output logic [9:0]  q_n
);
    logic [9:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q   = oe_n ? 10'h000 :  q_lat;
    assign q_n = oe_n ? 10'h000 : ~q_lat;
endmodule
