// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x994.md.
// ttl_74x994 - 10-bit D-type transparent read-back latch, non-inverting (3-state).
module ttl_74x994 (
    input  logic       le,
    input  logic       oerb_n,
    input  logic [9:0] d_in,
    output logic [9:0] d_out,
    output logic [9:0] q,
    output logic       d_oe_n
);
    logic [9:0] q_lat;
    always_latch begin
        if (le) q_lat = d_in;
    end
    assign q      = q_lat;
    assign d_oe_n = oerb_n;
    assign d_out  = oerb_n ? 10'b0 : q_lat;
endmodule
