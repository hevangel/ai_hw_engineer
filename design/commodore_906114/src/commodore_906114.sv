// Commodore 906114-01 (82S100 FPLA) C64 address decoder. Combinational
// sum-of-products; pins keep the board's active levels (outputs low =
// selected). Term list and input meanings: spec/spec.md. The 82S100 has 48
// product-term slots; only the 29 terms below are modeled and no claim is
// made about their physical slot order.
module commodore_906114 (
    input  logic cas_i,     // I0  CAS strobe from the VIC (high = idle)
    input  logic loram_i,   // I1  6510 P0
    input  logic hiram_i,   // I2  6510 P1
    input  logic charen_i,  // I3  6510 P2
    input  logic va14_i,    // I4  CIA2 PA0 level (/VA14: high in VIC banks 0 and 2)
    input  logic a15_i,     // I5
    input  logic a14_i,     // I6
    input  logic a13_i,     // I7
    input  logic a12_i,     // I8
    input  logic ba_i,      // I9  VIC BA
    input  logic aec_i,     // I10 inverted VIC AEC: high = VIC owns the bus
    input  logic rw_i,      // I11 high = read
    input  logic exrom_i,   // I12 expansion port, pulled up
    input  logic game_i,    // I13 expansion port, pulled up
    input  logic va13_i,    // I14 VIC address
    input  logic va12_i,    // I15 VIC address
    output logic casram_n_o,
    output logic basic_n_o,
    output logic kernal_n_o,
    output logic charom_n_o,
    output logic grw_n_o,
    output logic io_n_o,
    output logic roml_n_o,
    output logic romh_n_o
);
    logic cpu, dio, ultimax, game_on, cart16;
    logic [28:0] p;

    assign cpu = !aec_i;
    assign dio = a15_i && a14_i && !a13_i && a12_i;  // $D000-$DFFF
    assign ultimax = exrom_i && !game_i;
    assign game_on = game_i;                          // no cartridge or 8K
    assign cart16 = !exrom_i && !game_i;              // 16K cartridge

    // BASIC $A000-$BFFF, KERNAL $E000-$FFFF (reads only).
    assign p[0]  = loram_i && hiram_i && a15_i && !a14_i && a13_i && cpu && rw_i && game_on;
    assign p[1]  = hiram_i && a15_i && a14_i && a13_i && cpu && rw_i && game_on;
    assign p[2]  = hiram_i && a15_i && a14_i && a13_i && cpu && rw_i && cart16;
    // Character ROM: CPU reads at $D000 with CHAREN low, VIC at $1000/$9000.
    assign p[3]  = hiram_i && !charen_i && dio && cpu && rw_i && game_on;
    assign p[4]  = loram_i && !charen_i && dio && cpu && rw_i && game_on;
    assign p[5]  = hiram_i && !charen_i && dio && cpu && rw_i && cart16;
    assign p[6]  = va14_i && aec_i && game_on && !va13_i && va12_i;
    assign p[7]  = va14_i && aec_i && cart16 && !va13_i && va12_i;
    // Color RAM write strobe for any CPU write in $D000-$DFFF.
    assign p[8]  = !cas_i && dio && cpu && !rw_i;
    // I/O. Reads also require BA high, so a CPU held on a read by RDY
    // cannot repeat side-effect reads. ASSUMPTION: spec/spec.md.
    assign p[9]  = hiram_i && charen_i && dio && cpu && ba_i && rw_i && game_on;
    assign p[10] = hiram_i && charen_i && dio && cpu && !rw_i && game_on;
    assign p[11] = loram_i && charen_i && dio && cpu && ba_i && rw_i && game_on;
    assign p[12] = loram_i && charen_i && dio && cpu && !rw_i && game_on;
    assign p[13] = hiram_i && charen_i && dio && cpu && ba_i && rw_i && cart16;
    assign p[14] = hiram_i && charen_i && dio && cpu && !rw_i && cart16;
    assign p[15] = loram_i && charen_i && dio && cpu && ba_i && rw_i && cart16;
    assign p[16] = loram_i && charen_i && dio && cpu && !rw_i && cart16;
    assign p[17] = dio && cpu && ba_i && rw_i && ultimax;
    assign p[18] = dio && cpu && !rw_i && ultimax;
    // Cartridge ROML $8000-$9FFF and ROMH $A000/$E000 (VIC: $3000 in Ultimax).
    assign p[19] = loram_i && hiram_i && a15_i && !a14_i && !a13_i && cpu && rw_i && !exrom_i;
    assign p[20] = a15_i && !a14_i && !a13_i && cpu && ultimax;
    assign p[21] = hiram_i && a15_i && !a14_i && a13_i && cpu && rw_i && cart16;
    assign p[22] = a15_i && a14_i && a13_i && cpu && ultimax;
    assign p[23] = aec_i && ultimax && va13_i && va12_i;
    // Ultimax leaves $1000-$7FFF and $A000-$CFFF unmapped for the CPU.
    assign p[24] = !a15_i && a14_i && cpu && ultimax;
    assign p[25] = !a15_i && a13_i && cpu && ultimax;
    assign p[26] = !a15_i && a12_i && cpu && ultimax;
    assign p[27] = a15_i && !a14_i && a13_i && cpu && ultimax;
    assign p[28] = a15_i && a14_i && !a13_i && !a12_i && cpu && ultimax;

    assign basic_n_o  = !p[0];
    assign kernal_n_o = !(p[1] || p[2]);
    assign charom_n_o = !(|p[7:3]);
    assign grw_n_o    = !p[8];
    assign io_n_o     = !(|p[18:9]);
    assign roml_n_o   = !(p[19] || p[20]);
    assign romh_n_o   = !(|p[23:21]);
    // DRAM is deselected whenever any ROM, I/O or unmapped term matches.
    assign casram_n_o = cas_i || (|p[7:0]) || (|p[28:9]);

`ifdef FORMAL
    `include "commodore_906114_props.sv"
`endif
endmodule
