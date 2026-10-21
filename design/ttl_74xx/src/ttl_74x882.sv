// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x882.md.
// =============================================================================
// ttl_74x882 - 32-bit look-ahead carry generator
//
// Original part number : 74x882 (SN74AS882)
// Datasheet reference  : TI SN54AS882/SN74AS882 (D2661)
//
// Function
// --------
// A high-speed look-ahead carry generator that anticipates the carry across a
// group of eight 4-bit adders/ALUs (directly compatible with the '181A/'881A),
// implementing look-ahead for a 32-bit ALU. It takes eight propagate (P) and
// eight generate (G) signals (active-low, from the ALUs' P/G outputs) and the
// incoming carry Cn, and produces carries every eight bits.
//
// Per the datasheet logic equations (active-high P,G = ~ of the active-low
// inputs):
//   Cn+8  = G1 + P1.G0 + P1.P0.Cn
//   Cn+16 = G3 + P3.G2 + P3.P2.G1 + P3.P2.P1.G0 + P3.P2.P1.P0.Cn
//   Cn+24 = G5 + P5.G4 + ... + P5..P0.Cn
//   Cn+32 = G7 + P7.G6 + ... + P7..P0.Cn
//
// FPGA notes
// ----------
// Pure combinational. Active-low P/G inputs follow the same convention as
// ttl_74x182 (inverted internally to the true generate/propagate values).
//
// Pin mapping (24-pin): Cn=1, /G0=2, /P0=3, /G1=4, /P1=5, /G2=6, /P2=7, /G3=8,
// /P3=9, /G4=10, Cn+16=11, GND=12, /P4=13, /G5=15, /P5=14, Cn+24=17, /P6=18,
// /G6=19, /P7=20, /G7=21, Cn+32=22, NC=23, Vcc=24, Cn+8=6-area (see datasheet).
// (Active-low /P,/G inputs map to p_n[i], g_n[i].)
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x882 (
    input  logic       cn,
    input  logic [7:0] p_n,     // propagate inputs, active low (/P0../P7)
    input  logic [7:0] g_n,     // generate inputs, active low (/G0../G7)
    output logic       cn_p_8,
    output logic       cn_p_16,
    output logic       cn_p_24,
    output logic       cn_p_32
);
    logic [7:0] p, g;
    assign p = ~p_n;
    assign g = ~g_n;

    assign cn_p_8 =
        g[1] | (p[1] & g[0]) | (p[1] & p[0] & cn);

    assign cn_p_16 =
        g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0])
        | (p[3] & p[2] & p[1] & p[0] & cn);

    assign cn_p_24 =
        g[5] | (p[5] & g[4]) | (p[5] & p[4] & g[3]) | (p[5] & p[4] & p[3] & g[2])
        | (p[5] & p[4] & p[3] & p[2] & g[1]) | (p[5] & p[4] & p[3] & p[2] & p[1] & g[0])
        | (p[5] & p[4] & p[3] & p[2] & p[1] & p[0] & cn);

    assign cn_p_32 =
        g[7] | (p[7] & g[6]) | (p[7] & p[6] & g[5]) | (p[7] & p[6] & p[5] & g[4])
        | (p[7] & p[6] & p[5] & p[4] & g[3]) | (p[7] & p[6] & p[5] & p[4] & p[3] & g[2])
        | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & g[1])
        | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & g[0])
        | (p[7] & p[6] & p[5] & p[4] & p[3] & p[2] & p[1] & p[0] & cn);
endmodule
