// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x991.md.
// ttl_74x991 - 8-bit D-type transparent read-back latch, inverting (3-state).
// Inverting-Q sibling of ttl_74x990. The read-back D-out path still presents
// the true (non-inverted) latched data, per the SN74ALS667 precedent.
module ttl_74x991 (
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

    assign q      = ~q_lat;
    assign d_oe_n = oerb_n;
    assign d_out  = oerb_n ? 8'h00 : q_lat;
endmodule
