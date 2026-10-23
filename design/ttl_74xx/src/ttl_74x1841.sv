// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1841.md.
// ttl_74x1841 - 10-bit bus-interface transparent latch (3-state, lower-power variant of 74x841).
module ttl_74x1841 (
    input  logic       le,
    input  logic       oe_n,
    input  logic [9:0] d,
    output logic [9:0] q,
    output logic       q_oe_n
);
    logic [9:0] q_lat;
    always_latch begin
        if (le) q_lat = d;
    end
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 10'h000 : q_lat;
endmodule
