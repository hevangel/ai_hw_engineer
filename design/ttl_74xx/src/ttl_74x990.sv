// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x990.md.
// ttl_74x990 - 8-bit D-type transparent read-back latch, non-inverting (3-state).
//
// Per SN74ALS990 datasheet (SDAS027B). Eight transparent latches sharing a
// common LE and a common /OERB (read-back enable). The Q outputs are
// continuously driven ("true logic outputs"); only the D-side bus is
// 3-state, driven by the chip when /OERB is low. LE high makes the latches
// transparent; LE low holds the previously captured value.
module ttl_74x990 (
    input  logic       le,
    input  logic       oerb_n,
    input  logic [7:0] d_in,
    output logic [7:0] d_out,
    output logic [7:0] q,
    output logic       d_oe_n
);
    logic [7:0] q_lat;

    always_latch begin
        if (le) q_lat = d_in;
    end

    assign q      = q_lat;
    assign d_oe_n = oerb_n;
    assign d_out  = oerb_n ? 8'h00 : q_lat;
endmodule
