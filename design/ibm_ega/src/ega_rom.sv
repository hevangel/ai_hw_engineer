// IBM EGA BIOS ROM, part 6277356, U44 (27128, 16 KB).
//
// ROM_FILE is a $readmemh image of the EPROM in chip order (as a programmer
// reads it; scripts/get_rom.py writes it). The logic diagram drives the
// EPROM address pins A0-A13 from the inverted slot address lines (LS04
// U45-U47, sheets 1 and 4), so processor offset `a` reads chip location
// ~a. That is why chip-order dumps (MAME 6277356.u44) are the CPU image
// reversed.
module ega_rom #(
    parameter ROM_FILE = ""
) (
    input  logic        clk,
    input  logic [13:0] addr,       // processor offset within C0000h-C3FFFh
    output logic [7:0]  rdata
);
    logic [7:0] mem [0:16383];

`ifndef FORMAL
    initial begin
        for (int i = 0; i < 16384; i++) mem[i] = 8'h00;
        if (ROM_FILE != "") $readmemh(ROM_FILE, mem);
    end
`endif

    always_ff @(posedge clk) rdata <= mem[~addr];
endmodule
