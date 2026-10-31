// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1821.md.
// ttl_74x1821 - 10-bit bus interface flip-flop (3-state, low-power 821).
module ttl_74x1821 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [9:0] d,
    output logic [9:0] q,
    output logic       q_oe_n
);
    logic [9:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 10'h000 : q_lat;
endmodule
