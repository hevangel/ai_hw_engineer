// Space Invaders storage model: 8 KiB ROM, 1 KiB work RAM, 7 KiB VRAM.
// Addresses at 4000h and above alias the 0000h-3FFFh space (address bit 14
// ignored), implementing the board's partial-address-decode mirror; game
// code never addresses above 3FFFh. Like the IBM PC and Altair boards,
// storage is an explicit external interface, blackboxed by synthesis. The
// CPU read is asynchronous against the stable transfer address; the write
// request is registered by the board and executes here on the following
// edge.
module si_memory (
    input logic clk,
    input logic [15:0] cpu_addr,
    output logic [7:0] cpu_rdata,
    input logic [15:0] waddr,
    input logic [7:0] wdata,
    input logic we,
    // Window over VRAM 2400h-3FFFh (0..7167) used by the host renderer.
    input logic [12:0] win_addr,
    output logic [7:0] win_rdata,
    // Full-memory debug read for the testbench and oracle comparison.
    input logic [15:0] dbg_addr,
    output logic [7:0] dbg_rdata
);
    logic [7:0] rom  [0:8191];
    logic [7:0] ram  [0:1023];   // 2000h-23FFh
    logic [7:0] vram [0:7167];   // 2400h-3FFFh
    string rom_image;

    // Effective address: bit 14 ignored (4000h+ mirror alias).
    logic [14:0] eff_r, eff_w, eff_d;
    logic unused_bit14;
    assign eff_r = {cpu_addr[15], cpu_addr[13:0]};
    assign eff_w = {waddr[15], waddr[13:0]};
    assign eff_d = {dbg_addr[15], dbg_addr[13:0]};
    assign unused_bit14 = cpu_addr[14] ^ waddr[14] ^ dbg_addr[14];

    function automatic logic [7:0] read_eff(input logic [14:0] e);
        read_eff = 8'hff;
        if (e[14] == 1'b0) begin
            if (e[13] == 1'b0) read_eff = rom[e[12:0]];
            else if (e[12:10] == 3'b000) read_eff = ram[e[9:0]];      // 2000h-23FFh
            else read_eff = vram[e[12:0] - 13'h400];                  // 2400h-3FFFh
        end
    endfunction

    always_comb begin
        cpu_rdata = read_eff(eff_r);
        dbg_rdata = read_eff(eff_d);
    end

    assign win_rdata = vram[win_addr];

    always_ff @(posedge clk) begin
        if (we && eff_w[14] == 1'b0 && eff_w[13] == 1'b1) begin
            if (eff_w[12:10] == 3'b000) ram[eff_w[9:0]] <= wdata;      // 2000h-23FFh
            else vram[eff_w[12:0] - 13'h400] <= wdata;                 // 2400h-3FFFh
        end
    end

    initial begin
        for (integer i = 0; i < 1024; i = i + 1) ram[i] = 8'd0;
        for (integer i = 0; i < 7168; i = i + 1) vram[i] = 8'd0;
        for (integer i = 0; i < 8192; i = i + 1) rom[i] = 8'hff;
        if ($value$plusargs("rom=%s", rom_image))
            $readmemh(rom_image, rom);
    end
endmodule
