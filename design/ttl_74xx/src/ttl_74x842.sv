// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x842.md.
// ttl_74x842 - 10-bit bus-interface D-type transparent latch, inverting inputs (3-state).
// Inverting-D twin of ttl_74x841 per SN74ALS842 datasheet.
module ttl_74x842 (
    input  logic       le,
    input  logic       oe_n,
    input  logic [9:0] d,
    output logic [9:0] q,
    output logic       q_oe_n
);
    logic [9:0] q_lat;

    always_latch begin
        if (le) q_lat = ~d;
    end

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 10'h000 : q_lat;
endmodule
