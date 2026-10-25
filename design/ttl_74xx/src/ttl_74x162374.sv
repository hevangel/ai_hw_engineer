// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162374.md.
// ttl_74x162374 - 3.3-V ABT 16-bit edge-triggered D flip-flop (3-state).
module ttl_74x162374 (
    input  logic        clk,
    input  logic        oe_n,
    input  logic [15:0] d,
    output logic [15:0] q
);
    logic [15:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q = oe_n ? 16'h0000 : q_lat;
endmodule
