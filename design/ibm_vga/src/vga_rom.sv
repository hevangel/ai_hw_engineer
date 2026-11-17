// IBM PS/2 Display Adapter BIOS ROM window C0000h-C7FFFh (32 KB).
//
// ROM_FILE is a $readmemh image of the window in CPU order (offset 0 =
// C0000h = 55h AAh); scripts/get_rom.py writes it. ASSUMPTION V22: the
// 24 KB option ROM occupies the first 24 KB and 6000h-7FFFh read 00h, as
// in MAME's 32 KB dump. Synchronous read.
module vga_rom #(
    parameter ROM_FILE = ""
) (
    input  logic        clk,
    input  logic [14:0] addr,
    output logic [7:0]  rdata
);
`ifdef FORMAL
    (* anyseq *) logic [7:0] f_d;
    always_ff @(posedge clk) rdata <= f_d;
    logic f_unused;
    assign f_unused = ^addr;
`else
    logic [7:0] mem [0:32767];

    initial begin
        for (int i = 0; i < 32768; i++) mem[i] = 8'h00;
        if (ROM_FILE != "") $readmemh(ROM_FILE, mem);
    end

    always_ff @(posedge clk) rdata <= mem[addr];
`endif
endmodule
