// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x822.md.
// ttl_74x822 - 10-bit bus interface flip-flop, inverting inputs (3-state).
//
// Inverting twin of ttl_74x821: D inputs are inverted before storage, so
// the latched value (and Q output when enabled) is the bitwise complement
// of the data presented at the D pins on the clock edge.
module ttl_74x822 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [9:0] d,
    output logic [9:0] q,
    output logic       q_oe_n
);
    logic [9:0] q_lat;

    always_ff @(posedge clk) q_lat <= ~d;

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 10'h000 : q_lat;
endmodule
