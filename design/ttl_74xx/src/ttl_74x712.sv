// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x712.md.
// =============================================================================
// ttl_74x712 - Quint 3-to-1 data selector/multiplexer
//
// Original part number : 74x712 (74F712)
// Datasheet reference  : Signetics FAST 74F712 (June 1987)
//
// Function
// --------
// Five 3-to-1 multiplexers with common selects S0, S1. Equivalent to five
// 'F153s. No output enable (outputs are always driven, non-inverting).
// Per channel n (0..4):
//
//     q[n] = s1 ? dc[n] : (s0 ? db[n] : da[n])
//
// Datasheet Function Table ('F712):
//     S0 S1 | Qn
//     L  L  | data a
//     H  L  | data b
//     X  H  | data c
//
// FPGA notes
// ----------
// Pure combinational. No clock, reset, enable, or three-state.
//
// Pin mapping (24-pin): D0a=1,D1a=2,D2a=3,D3a=4,D4a=5, D0b=6,D1b=7,D2b=8,D3b=9,
// D4b=10, S0=11, GND=12, S1=13, Q4=14,Q3=15,Q2=16,Q1=17,Q0=18,
// D4c=19,D3c=20,D2c=21,D1c=22,D0c=23, Vcc=24. (da[n]=Dna, db[n]=Dnb, dc[n]=Dnc.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive characteristics.
// =============================================================================

module ttl_74x712 (
    input  logic [4:0] da,      // D0a..D4a (S1=0, S0=0)
    input  logic [4:0] db,      // D0b..D4b (S1=0, S0=1)
    input  logic [4:0] dc,      // D0c..D4c (S1=1)
    input  logic       s0,
    input  logic       s1,
    output logic [4:0] q        // Q0..Q4
);
    assign q = s1 ? dc : (s0 ? db : da);
endmodule
