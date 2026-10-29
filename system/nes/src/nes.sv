// Nintendo Entertainment System (NES-001 / Famicom main board) virtual
// platform: Ricoh 2A03/2A07 CPU+APU, 2C02/2C07 PPU, 2 KiB work RAM, CIRAM,
// cartridge mapper logic and two standard controllers. See spec/spec.md.
module nes #(
    parameter bit REGION = 1'b0          // 0 = NTSC (2A03/2C02), 1 = PAL (2A07/2C07)
) (
    input  logic clk,                    // master oscillator 21.477272 / 26.601712 MHz
    input  logic rst_n,                  // reset button (also low at power-on)
    input  logic por_n,                  // power-on reset, low together with rst_n
    // Cartridge header (from the iNES file)
    input  logic [7:0] mapper_i,
    input  logic mirror_v_i,
    input  logic chr_ram_i,
    input  logic [18:0] prg_mask_i,
    input  logic [17:0] chr_mask_i,
    // Controllers {Right, Left, Down, Up, Start, Select, B, A}, 1 = pressed
    input  logic [7:0] pad1_i, pad2_i,
    // Video
    output logic [5:0] pixel,
    output logic [2:0] emphasis,
    output logic pixel_valid,
    output logic [8:0] scanline, dot,
    output logic frame_odd,
    // Audio DAC codes
    output logic [3:0] pulse1, pulse2, triangle, noise,
    output logic [6:0] dmc,
    // Observability
    output logic cpu_clk,
    output logic cpu_tick,               // master edge that completes a CPU cycle
    output logic [15:0] cpu_addr,
    output logic [7:0] cpu_data,
    output logic cpu_we, cpu_fetch, cpu_dma, cpu_jammed, cpu_fault,
    output logic [2:0] exp_out,          // OUT2-OUT0 (OUT1/OUT2 go to the expansion port)
    output logic [15:0] cpu_pc,
    output logic [7:0] cpu_a, cpu_x, cpu_y, cpu_s, cpu_p,
    output logic nmi_n,
    input  logic [15:0] host_addr,
    output logic [7:0] host_rdata
);
    localparam int CPU_DIV = REGION ? 16 : 12;
    localparam int PPU_DIV = REGION ? 5 : 4;

    // ---- Clocks: one master clock; the CPU clock rises on a master falling
    // edge so CPU and master-domain logic never sample each other mid-update.
    logic [3:0] cpu_div;
    logic [2:0] ppu_div;
    logic dot_ce;
    always_ff @(posedge clk) begin
        if (!rst_n) begin cpu_div <= '0; ppu_div <= '0; end
        else begin
            cpu_div <= (cpu_div == 4'(CPU_DIV - 1)) ? 4'd0 : cpu_div + 4'd1;
            ppu_div <= (ppu_div == 3'(PPU_DIV - 1)) ? 3'd0 : ppu_div + 3'd1;
        end
    end
    always_ff @(negedge clk) cpu_clk <= cpu_div < 4'(CPU_DIV / 2);
    assign cpu_tick = rst_n && cpu_div == 4'(CPU_DIV - 1);
    assign dot_ce = rst_n && ppu_div == 3'(PPU_DIV - 1);

    // ---- Reset: hold the CPU in reset for whole CPU cycles.
    // The cartridge and controllers have no reset line: only power clears them.
    logic cpu_rst_n, cpu_por_n;
    always_ff @(posedge cpu_clk) begin
        cpu_rst_n <= rst_n;
        cpu_por_n <= por_n;
    end

    // ---- CPU ----
    logic [15:0] addr;
    logic [7:0] wdata, rdata, bus_latch;
    logic we, ext_rd, oe1_n, oe2_n;
    logic [2:0] out;
    ricoh_2a03 #(.REGION(REGION)) cpu (
        .clk(cpu_clk), .rst_n(cpu_rst_n), .por_n(cpu_por_n), .irq_n(1'b1), .nmi_n,
        .addr_o(addr), .data_i(rdata), .data_o(wdata), .we_o(we), .ext_rd_o(ext_rd),
        .out_o(out), .oe1_n_o(oe1_n), .oe2_n_o(oe2_n),
        .pulse1_o(pulse1), .pulse2_o(pulse2), .triangle_o(triangle), .noise_o(noise), .dmc_o(dmc),
        .dma_o(cpu_dma), .fetch_o(cpu_fetch), .jammed_o(cpu_jammed), .fault_o(cpu_fault),
        .pc_o(cpu_pc), .a_o(cpu_a), .x_o(cpu_x), .y_o(cpu_y), .s_o(cpu_s), .p_o(cpu_p)
    );
    assign cpu_addr = addr;
    assign exp_out = out;
    assign cpu_we = we;
    assign cpu_data = we ? wdata : rdata;

    // ---- PPU ----
    logic [13:0] vram_addr;
    logic vram_we;
    /* verilator lint_off UNUSEDSIGNAL */
    logic vram_rd;                       // storage reads are combinational
    /* verilator lint_on UNUSEDSIGNAL */
    logic [7:0] vram_wdata, vram_rdata, ppu_rdata;
    ricoh_2c02 #(.REGION(REGION)) ppu (
        .clk, .rst_n, .dot_ce, .cpu_ce(cpu_tick), .cpu_cs(addr[15:13] == 3'b001),
        .cpu_we(we), .cpu_addr(addr[2:0]), .cpu_wdata(wdata), .cpu_rdata(ppu_rdata),
        .nmi_n, .vram_addr, .vram_rd, .vram_we, .vram_wdata, .vram_rdata,
        .pixel, .emphasis, .pixel_valid, .scanline, .dot, .frame_odd
    );

    // ---- Cartridge ----
    logic [18:0] prg_addr;
    logic [17:0] chr_addr;
    logic prg_rom_sel, prg_ram_sel, chr_sel, ciram_a10;
    nes_cartridge cart (
        .cpu_clk, .rst_n(cpu_por_n), .mapper_i, .mirror_v_i, .prg_mask_i, .chr_mask_i,
        .cpu_addr(addr), .cpu_we(we), .cpu_wdata(wdata), .prg_addr, .prg_rom_sel, .prg_ram_sel,
        .ppu_addr(vram_addr), .chr_addr, .chr_sel, .ciram_a10
    );

    // ---- Storage ----
    logic [7:0] ram_rdata, prg_rdata, wram_rdata, chr_rdata, ciram_rdata;
    nes_memory mem (
        .cpu_clk, .clk, .cpu_addr(addr), .cpu_we(we), .cpu_wdata(wdata), .prg_addr,
        .ram_rdata, .prg_rdata, .wram_rdata,
        .ppu_we(dot_ce && vram_we), .ppu_wdata(vram_wdata), .chr_addr, .chr_sel, .chr_ram_i,
        .ciram_addr({ciram_a10, vram_addr[9:0]}), .chr_rdata, .ciram_rdata,
        .host_addr, .host_rdata
    );
    assign vram_rdata = chr_sel ? chr_rdata : ciram_rdata;

    // ---- Controllers ----
    logic pad1_bit, pad2_bit;
    nes_controller pad1 (.cpu_clk, .rst_n(cpu_por_n), .strobe_i(out[0]), .clock_i(!oe1_n),
                         .buttons_i(pad1_i), .data_o(pad1_bit));
    nes_controller pad2 (.cpu_clk, .rst_n(cpu_por_n), .strobe_i(out[0]), .clock_i(!oe2_n),
                         .buttons_i(pad2_i), .data_o(pad2_bit));

    // ---- CPU data bus: devices, else the open-bus latch ----
    always_comb begin
        rdata = bus_latch;
        if (addr[15:13] == 3'b000) rdata = ram_rdata;
        else if (addr[15:13] == 3'b001) rdata = ppu_rdata;
        else if (!oe1_n) rdata = {bus_latch[7:5], 4'b0000, pad1_bit};
        else if (!oe2_n) rdata = {bus_latch[7:5], 4'b0000, pad2_bit};
        else if (prg_ram_sel) rdata = wram_rdata;
        else if (prg_rom_sel) rdata = prg_rdata;
    end
    always_ff @(posedge cpu_clk) begin
        if (!cpu_rst_n) bus_latch <= '0;
        else if (we) bus_latch <= wdata;
        else if (ext_rd) bus_latch <= rdata;
    end
endmodule
