// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x711.md.
// =============================================================================
// ttl_74x711 - Quint 2-to-1 data selector/multiplexer, 3-state outputs
//
// Original part number : 74x711 (74F711)
// Datasheet reference  : Signetics FAST 74F711 (June 1987)
//
// Function
// --------
// Five 2-to-1 multiplexers with a common select S and a common active-low
// output enable OE. Equivalent to two 'F257s. Per channel n (0..4):
//
//     q[n] = oe_n ? Z : (s ? db[n] : da[n])
//
// Datasheet Function Table ('F711):
//     S  OE | Qn
//     L  L  | data a
//     H  L  | data b
//     X  H  | Z
//
// High-Z is modeled as a driven 0 (library convention).
//
// FPGA notes
// ----------
// Pure combinational. 3-state modeled as muxed 0.
//
// Pin mapping (20-pin): D0a=1,D0b=2,D1a=3,D1b=4,D2a=5,D2b=6,D3a=7,D3b=8,
// NC=9, GND=10, D4a=11,D4b=12, /OE=13, S=14, Q0=15,Q1=16,Q2=17,Q3=18,Q4=19,
// Vcc=20. (da[n]=Dna, db[n]=Dnb, q[n]=Qn.)
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); electrical drive.
// =============================================================================

module ttl_74x711 (
    input  logic [4:0] da,      // D0a..D4a (selected when s=0)
    input  logic [4:0] db,      // D0b..D4b (selected when s=1)
    input  logic       s,       // common select: 0=a, 1=b
    input  logic       oe_n,    // common output enable, active low
    output logic [4:0] q        // Q0..Q4
);
    assign q = oe_n ? 5'b0 : (s ? db : da);
endmodule
