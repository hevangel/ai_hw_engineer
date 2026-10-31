// Storage model: 2 KiB CPU RAM, 2 KiB CIRAM, PRG ROM (up to 512 KiB),
// CHR ROM/RAM (up to 256 KiB) and 8 KiB PRG RAM. Images load from
// +prg=/+chr= $readmemh plusargs (built in work/ from the iNES file, never
// committed). External interface; blackboxed by the synthesis check.
module nes_memory (
    input  logic cpu_clk,
    input  logic clk,
    // CPU port
    input  logic [15:0] cpu_addr,
    input  logic cpu_we,
    input  logic [7:0] cpu_wdata,
    input  logic [18:0] prg_addr,
    output logic [7:0] ram_rdata, prg_rdata, wram_rdata,
    // PPU port
    input  logic ppu_we,
    input  logic [7:0] ppu_wdata,
    input  logic [17:0] chr_addr,
    input  logic chr_sel,
    input  logic chr_ram_i,
    input  logic [10:0] ciram_addr,
    output logic [7:0] chr_rdata, ciram_rdata,
    // Host observation (no side effects)
    input  logic [15:0] host_addr,
    output logic [7:0] host_rdata
);
    logic [7:0] ram [0:2047];
    logic [7:0] ciram [0:2047];
    logic [7:0] wram [0:8191];
    logic [7:0] prg [0:524287];
    logic [7:0] chr [0:262143];
    string path;
    initial begin
        foreach (ram[i]) ram[i] = 8'h00;
        foreach (ciram[i]) ciram[i] = 8'h00;
        foreach (wram[i]) wram[i] = 8'h00;
        if ($value$plusargs("prg=%s", path)) $readmemh(path, prg);
        if ($value$plusargs("chr=%s", path)) $readmemh(path, chr);
    end
    assign ram_rdata = ram[cpu_addr[10:0]];
    assign wram_rdata = wram[cpu_addr[12:0]];
    assign prg_rdata = prg[prg_addr];
    assign chr_rdata = chr[chr_addr];
    assign ciram_rdata = ciram[ciram_addr];
    always_ff @(posedge cpu_clk) if (cpu_we) begin
        if (cpu_addr[15:13] == 3'b000) ram[cpu_addr[10:0]] <= cpu_wdata;
        if (cpu_addr[15:13] == 3'b011) wram[cpu_addr[12:0]] <= cpu_wdata;
    end
    always_ff @(posedge clk) if (ppu_we) begin
        if (!chr_sel) ciram[ciram_addr] <= ppu_wdata;
        else if (chr_ram_i) chr[chr_addr] <= ppu_wdata;
    end
    always_comb begin
        case (host_addr[15:13])
            3'b000: host_rdata = ram[host_addr[10:0]];
            3'b001: host_rdata = ciram[host_addr[10:0]];   // name tables (raw CIRAM)
            3'b011: host_rdata = wram[host_addr[12:0]];
            default: host_rdata = 8'hff;
        endcase
    end
endmodule
