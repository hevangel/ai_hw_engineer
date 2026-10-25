// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x843.md.
// ttl_74x843 - 9-bit bus-interface D-type transparent latch with /PRE and /CLR (3-state).
//
// Per SN74ALS843 datasheet (SDAS232A): nine transparent latches with
// asynchronous preset and clear (preset takes priority over clear), level-
// sensitive LE, and a buffered /OE that gates only the output buffers.
//
// Note: the project task header for the 843 family says "flip-flops"; the
// TI datasheet is unambiguous that these are transparent latches. We follow
// the datasheet.
module ttl_74x843 (
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
        else if (le)     q_lat = d;
    end

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 9'h000 : q_lat;
endmodule
