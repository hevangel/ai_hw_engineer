// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x996.md.
// ttl_74x996 - 8-bit D-type edge-triggered read-back latch (3-state).
//
// Edge-triggered relative of ttl_74x990: storage uses a posedge-clocked D
// flip-flop instead of a level-sensitive latch. Read-back path is the same
// (drives latched data onto D when /OERB is low).
module ttl_74x996 (
    input  logic       clk,
    input  logic       oerb_n,
    input  logic [7:0] d_in,
    output logic [7:0] d_out,
    output logic [7:0] q,
    output logic       d_oe_n
);
    logic [7:0] q_lat;
    always_ff @(posedge clk) q_lat <= d_in;
    assign q      = q_lat;
    assign d_oe_n = oerb_n;
    assign d_out  = oerb_n ? 8'h00 : q_lat;
endmodule
