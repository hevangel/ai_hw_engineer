// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16721.md.
// ttl_74x16721 - 20-bit edge-triggered D flip-flop (3-state).
module ttl_74x16721 (
    input  logic        clk,
    input  logic        oe_n,
    input  logic [19:0] d,
    output logic [19:0] q
);
    logic [19:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q = oe_n ? 20'h00000 : q_lat;
endmodule
