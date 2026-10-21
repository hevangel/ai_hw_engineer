// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x844.md.
// ttl_74x844 - 9-bit transparent latch with /PRE, /CLR, inverting inputs (3-state).
// Inverting-D twin of ttl_74x843 per SN74ALS844.
module ttl_74x844 (
    input  logic       le,
    input  logic       pre_n,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic [8:0] d,
    output logic [8:0] q,
    output logic       q_oe_n
);
    logic [8:0] q_lat;

    always_latch begin
        if (!pre_n)      q_lat = 9'h1FF;
        else if (!clr_n) q_lat = 9'h000;
        else if (le)     q_lat = ~d;
    end

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 9'h000 : q_lat;
endmodule
