// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16841.md.
// ttl_74x16841 - 20-bit bus interface transparent latch (3-state). Widebus 841.
module ttl_74x16841 (
    input  logic        le,
    input  logic        oe_n,
    input  logic [19:0] d,
    output logic [19:0] q,
    output logic        q_oe_n
);
    logic [19:0] q_lat;
    always_latch begin
        if (le) q_lat = d;
    end
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 20'h00000 : q_lat;
endmodule
