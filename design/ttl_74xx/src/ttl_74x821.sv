// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x821.md.
// ttl_74x821 - 10-bit bus interface flip-flop (3-state, non-inverting).
//
// Per SN74AS821A datasheet (SDAS230A): ten posedge-triggered D flip-flops with
// a single buffered /OE for all outputs. /OE does NOT affect the flip-flop's
// internal state — the storage updates on every posedge of CLK regardless of
// /OE; only the output drive is gated. No async clear or preset.
module ttl_74x821 (
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
