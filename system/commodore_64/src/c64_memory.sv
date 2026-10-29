// C64 storage model: 64 KiB DRAM, 1 Kx4 color SRAM (2114) and the BASIC,
// KERNAL and character ROMs. Reads are asynchronous against the stable
// address of each access; the CPU write executes on the CPU cycle-end edge.
// Like the other system boards, storage is an explicit interface that
// synthesis treats as a blackbox (synth/c64_memory_stub.v). ROM images are
// loaded from +basic=, +kernal= and +chargen= hex files.
module c64_memory (
    input  logic        cpu_clk,
    // CPU port.
    input  logic [15:0] cpu_addr,
    output logic [7:0]  cpu_ram_q,
    output logic [7:0]  basic_q,
    output logic [7:0]  kernal_q,
    output logic [7:0]  charom_q,
    output logic [3:0]  cpu_color_q,
    input  logic        ram_we,
    input  logic [7:0]  ram_wdata,
    input  logic        color_we,
    // VIC phase-one and phase-two fetch ports (RAM, then character ROM).
    input  logic [15:0] vic1_addr,
    output logic [7:0]  vic1_ram_q,
    output logic [7:0]  vic1_rom_q,
    input  logic [15:0] vic2_addr,
    output logic [7:0]  vic2_ram_q,
    output logic [7:0]  vic2_rom_q,
    input  logic [9:0]  vic_color_addr,
    output logic [3:0]  vic_color_q,
    // Host observation of DRAM and color RAM.
    input  logic [15:0] host_addr,
    output logic [7:0]  host_ram_q,
    output logic [3:0]  host_color_q
);
    logic [7:0] ram [0:65535];
    logic [3:0] color [0:1023];
    logic [7:0] basic [0:8191];
    logic [7:0] kernal [0:8191];
    logic [7:0] chargen [0:4095];
    string path;

    assign cpu_ram_q = ram[cpu_addr];
    assign basic_q = basic[cpu_addr[12:0]];
    assign kernal_q = kernal[cpu_addr[12:0]];
    assign charom_q = chargen[cpu_addr[11:0]];
    assign cpu_color_q = color[cpu_addr[9:0]];
    assign vic1_ram_q = ram[vic1_addr];
    assign vic1_rom_q = chargen[vic1_addr[11:0]];
    assign vic2_ram_q = ram[vic2_addr];
    assign vic2_rom_q = chargen[vic2_addr[11:0]];
    assign vic_color_q = color[vic_color_addr];
    assign host_ram_q = ram[host_addr];
    assign host_color_q = color[host_addr[9:0]];

    always_ff @(posedge cpu_clk) begin
        if (ram_we) ram[cpu_addr] <= ram_wdata;
        if (color_we) color[cpu_addr[9:0]] <= ram_wdata[3:0];
    end

    // ASSUMPTION: power-on DRAM pattern. Real 4164 contents are undefined;
    // alternating 64-byte $00/$FF stripes are used unless +raminit=<hex>
    // fills a constant (the oracle comparison uses zero in both models).
    logic [7:0] fill;
    initial begin
        for (int i = 0; i < 65536; i++) ram[i] = ((i >> 6) & 1) != 0 ? 8'hff : 8'h00;
        if ($value$plusargs("raminit=%h", fill))
            for (int i = 0; i < 65536; i++) ram[i] = fill;
        for (int i = 0; i < 1024; i++) color[i] = 4'h0;
        for (int i = 0; i < 8192; i++) begin basic[i] = 8'hff; kernal[i] = 8'hff; end
        for (int i = 0; i < 4096; i++) chargen[i] = 8'hff;
        if ($value$plusargs("basic=%s", path)) $readmemh(path, basic);
        if ($value$plusargs("kernal=%s", path)) $readmemh(path, kernal);
        if ($value$plusargs("chargen=%s", path)) $readmemh(path, chargen);
    end
endmodule
