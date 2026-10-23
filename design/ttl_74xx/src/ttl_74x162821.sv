// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162821.md.
// ttl_74x162821 - 3.3-V 20-bit bus interface flip-flop (3-state).
module ttl_74x162821 (
    input  logic        clk,
    input  logic        oe_n,
    input  logic [19:0] d,
    output logic [19:0] q,
    output logic        q_oe_n
);
    logic [19:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 20'h00000 : q_lat;
endmodule
