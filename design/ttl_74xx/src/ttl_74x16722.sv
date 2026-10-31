// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16722.md.
// ttl_74x16722 - 22-bit edge-triggered D flip-flop (3-state).
module ttl_74x16722 (
    input  logic        clk,
    input  logic        oe_n,
    input  logic [21:0] d,
    output logic [21:0] q
);
    logic [21:0] q_lat;
    always_ff @(posedge clk) q_lat <= d;
    assign q = oe_n ? 22'h000000 : q_lat;
endmodule
