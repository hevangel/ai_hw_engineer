// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x841.md.
// ttl_74x841 - 10-bit bus-interface D-type transparent latch (3-state, non-inverting).
//
// Per SN74ALS841 datasheet (SDAS059C): ten transparent latches sharing a
// common LE (latch enable, active high) and a buffered /OE that gates the
// output buffers without affecting internal storage. The task header
// describes this part as a "flip-flop", but the datasheet is unambiguous
// that it is a level-sensitive *latch*; the README documents this.
module ttl_74x841 (
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
