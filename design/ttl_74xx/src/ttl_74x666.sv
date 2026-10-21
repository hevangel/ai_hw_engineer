// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x666.md.
// ttl_74x666 - 8-bit D-type transparent read-back latch (non-inverting, 3-state).
//
// Per SN74ALS666 datasheet (SDAS227A):
//   - Latch transparent while LE is high; holds while LE is low.
//   - /CLR (async) clears latches to 0; /PRE (async) presets to 1.
//   - Q outputs 3-state-enabled only when BOTH /OE1 and /OE2 are low.
//   - /OERB low drives the latched data back onto the D input bus.
module ttl_74x666 (
    input  logic       le,
    input  logic       pre_n,
    input  logic       clr_n,
    input  logic       oe1_n,
    input  logic       oe2_n,
    input  logic       oerb_n,
    input  logic [7:0] d_in,
    output logic [7:0] d_out,
    output logic [7:0] q_out,
    output logic       d_oe_n,
    output logic       q_oe_n
);
    logic [7:0] q_lat;

    always_latch begin
        if (!clr_n)      q_lat = 8'h00;
        else if (!pre_n) q_lat = 8'hFF;
        else if (le)     q_lat = d_in;
    end

    assign q_oe_n = oe1_n | oe2_n;
    assign q_out  = q_oe_n ? 8'h00 : q_lat;

    assign d_oe_n = oerb_n;
    assign d_out  = d_oe_n ? 8'h00 : q_lat;
endmodule
