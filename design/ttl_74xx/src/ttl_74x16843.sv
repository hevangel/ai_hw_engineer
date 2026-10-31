// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16843.md.
// ttl_74x16843 - 18-bit bus interface transparent latch with /PRE, /CLR (3-state). Widebus 843.
module ttl_74x16843 (
    input  logic        le,
    input  logic        pre_n,
    input  logic        clr_n,
    input  logic        oe_n,
    input  logic [17:0] d,
    output logic [17:0] q,
    output logic        q_oe_n
);
    logic [17:0] q_lat;
    always_latch begin
        if (!pre_n)      q_lat = 18'h3_FFFF;
        else if (!clr_n) q_lat = 18'h0_0000;
        else if (le)     q_lat = d;
    end
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 18'h0_0000 : q_lat;
endmodule
