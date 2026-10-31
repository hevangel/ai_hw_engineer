// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x873.md.
// ttl_74x873 - Dual 4-bit D-type transparent latch with clear (3-state).
//
// Per SN74ALS873B / AS873A datasheet (SDAS036D): two independent 4-bit
// transparent latches, each with its own LE (latch enable), /CLR
// (asynchronous clear), and /OE. While LE is high the Q outputs follow D;
// when LE goes low the captured value is held. /CLR low forces the latch
// to zero independently of LE. /OE high places the four Q outputs of that
// half in Hi-Z without affecting internal storage.
module ttl_74x873 (
    // Latch 1
    input  logic       le1,
    input  logic       clr1_n,
    input  logic       oe1_n,
    input  logic [3:0] d1,
    output logic [3:0] q1,
    output logic       q1_oe_n,
    // Latch 2
    input  logic       le2,
    input  logic       clr2_n,
    input  logic       oe2_n,
    input  logic [3:0] d2,
    output logic [3:0] q2,
    output logic       q2_oe_n
);
    logic [3:0] q1_lat, q2_lat;

    always_latch begin
        if (!clr1_n) q1_lat = 4'b0;
        else if (le1) q1_lat = d1;
    end

    always_latch begin
        if (!clr2_n) q2_lat = 4'b0;
        else if (le2) q2_lat = d2;
    end

    assign q1_oe_n = oe1_n;
    assign q2_oe_n = oe2_n;
    assign q1      = oe1_n ? 4'b0 : q1_lat;
    assign q2      = oe2_n ? 4'b0 : q2_lat;
endmodule
