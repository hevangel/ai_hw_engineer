// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x846.md.
// ttl_74x846 - 8-bit transparent latch with /PRE, /CLR, inverting inputs (3-state).
// Inverting-D twin of ttl_74x845.
module ttl_74x846 (
    input  logic       le,
    input  logic       pre_n,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       q_oe_n
);
    logic [7:0] q_lat;

    always_latch begin
        if (!pre_n)      q_lat = 8'hFF;
        else if (!clr_n) q_lat = 8'h00;
        else if (le)     q_lat = ~d;
    end

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 8'h00 : q_lat;
endmodule
