// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x667.md.
// ttl_74x667 - 8-bit D-type transparent read-back latch (inverting Q, 3-state).
//
// Identical to ttl_74x666 except the Q-port drives the bitwise complement of
// the latched data. The read-back path still presents the true latched data
// onto the D pins (per the SN74ALS667 logic diagram).
module ttl_74x667 (
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
    assign q_out  = q_oe_n ? 8'h00 : ~q_lat;

    assign d_oe_n = oerb_n;
    assign d_out  = d_oe_n ? 8'h00 : q_lat;
endmodule
