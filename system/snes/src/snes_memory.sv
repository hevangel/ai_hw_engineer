// Storage model for the SNES board: 128 KiB work RAM, 64 KiB VRAM (two
// 32K x 8 SRAMs seen as 32K x 16), 64 KiB audio RAM, cartridge ROM (up to
// 4 MiB) and battery SRAM (up to 128 KiB). The ROM image loads from the
// +rom= $readmemh plusarg (built in work/ from the cartridge file, never
// committed). External interface; blackboxed by the synthesis check.
module snes_memory (
    input  logic clk,
    // Work RAM: combinational read, write strobe
    input  logic [16:0] wram_addr,
    input  logic wram_we,
    input  logic [7:0] wram_wdata,
    output logic [7:0] wram_rdata,
    // Cartridge
    input  logic [21:0] rom_addr,
    output logic [7:0] rom_rdata,
    input  logic [16:0] sram_addr,
    input  logic sram_we,
    input  logic [7:0] sram_wdata,
    output logic [7:0] sram_rdata,
    // VRAM: render port and CPU port, registered reads
    input  logic [14:0] vram_raddr,
    output logic [15:0] vram_rdata,
    input  logic [14:0] vram_caddr,
    input  logic vram_cwe_lo, vram_cwe_hi,
    input  logic [7:0] vram_cwdata,
    output logic [15:0] vram_cdata,
    // Audio RAM: registered read (read-first)
    input  logic [15:0] aram_addr,
    input  logic aram_we,
    input  logic [7:0] aram_wdata,
    output logic [7:0] aram_rdata,
    // Host observation (no side effects): $00xxxxx WRAM, $10xxxx ARAM,
    // $20xxxx VRAM (byte address), $30xxxx SRAM
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [23:0] host_addr,     // bits 19-17 unused
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [7:0] host_rdata
);
    logic [7:0] wram [0:131071];
    logic [7:0] rom [0:4194303];
    logic [7:0] sram [0:131071];
    logic [7:0] vlo [0:32767];
    logic [7:0] vhi [0:32767];
    logic [7:0] aram [0:65535];
    string path;
    initial begin
        // Power-on contents are undefined on hardware; the model starts at
        // zero (WRAM, VRAM, ARAM) and $FF (SRAM) for repeatable runs.
        foreach (wram[i]) wram[i] = 8'h00;
        foreach (sram[i]) sram[i] = 8'hff;
        foreach (vlo[i]) begin vlo[i] = 8'h00; vhi[i] = 8'h00; end
        foreach (aram[i]) aram[i] = 8'h00;
        if ($value$plusargs("rom=%s", path)) $readmemh(path, rom);
    end
    assign wram_rdata = wram[wram_addr];
    assign rom_rdata = rom[rom_addr];
    assign sram_rdata = sram[sram_addr];
    always_ff @(posedge clk) begin
        if (wram_we) wram[wram_addr] <= wram_wdata;
        if (sram_we) sram[sram_addr] <= sram_wdata;
        vram_rdata <= {vhi[vram_raddr], vlo[vram_raddr]};
        vram_cdata <= {vhi[vram_caddr], vlo[vram_caddr]};
        if (vram_cwe_lo) vlo[vram_caddr] <= vram_cwdata;
        if (vram_cwe_hi) vhi[vram_caddr] <= vram_cwdata;
        aram_rdata <= aram[aram_addr];
        if (aram_we) aram[aram_addr] <= aram_wdata;
    end
    always_comb begin
        case (host_addr[23:20])
            4'h0: host_rdata = wram[host_addr[16:0]];
            4'h1: host_rdata = aram[host_addr[15:0]];
            4'h2: host_rdata = host_addr[0] ? vhi[host_addr[15:1]] : vlo[host_addr[15:1]];
            4'h3: host_rdata = sram[host_addr[16:0]];
            default: host_rdata = 8'hff;
        endcase
    end
endmodule
