// Super Nintendo Entertainment System (SNS-001 / SHVC-001 main board)
// virtual platform: 5A22 CPU, S-PPU1 (5C77) and S-PPU2 (5C78), 128 KiB work
// RAM with its B-bus port, the APU (S-SMP + S-DSP + 64 KiB audio RAM),
// a LoROM/HiROM cartridge slot and two standard controllers. See spec/spec.md.
module snes #(
    parameter bit PAL = 1'b0
) (
    input  logic clk,                    // master clock 21.477272 / 21.281370 MHz
    input  logic rst_n,                  // reset button (also low at power-on)
    // Cartridge configuration (from the ROM header)
    input  logic hirom_i,
    input  logic [21:0] rom_mask_i,
    input  logic [16:0] sram_mask_i,
    input  logic sram_en_i,
    // Controllers {R, L, X, A, Right, Left, Down, Up, Start, Select, Y, B}, 1 = pressed
    input  logic [11:0] pad1_i, pad2_i,
    // IPL ROM load (S-SMP mask ROM image, supplied by the host)
    input  logic ipl_we,
    input  logic [5:0] ipl_addr,
    input  logic [7:0] ipl_data,
    // Video
    output logic pix_valid,
    output logic [9:0] pix_x,
    output logic [8:0] pix_y,
    output logic [14:0] pix_rgb,
    output logic pix_hires,
    output logic frame_o,
    // Audio (32 kHz)
    output logic sample_valid,
    output logic signed [15:0] sample_l, sample_r,
    // Observability
    output logic bus_ce,
    output logic [23:0] a_addr,
    output logic cpu_fetch,
    output logic [23:0] cpu_pc,
    output logic [15:0] cpu_a, cpu_x, cpu_y, cpu_s, cpu_d,
    output logic [7:0] cpu_p, cpu_dbr,
    output logic cpu_e,
    output logic [8:0] vcount,
    output logic [10:0] hcount,
    output logic apu_tick,
    output logic smp_fetch,
    output logic [15:0] smp_pc,
    output logic dsp_overrun,
    input  logic [23:0] host_addr,
    output logic [7:0] host_rdata
);
    // ---------------- CPU ----------------
    logic [7:0] b_addr, a_rdata, b_rdata, wdata, mdr, wrio;
    logic a_rd, a_wr, b_rd, b_wr, a_hit, b_hit;
    logic interlace, overscan, jp_latch, jp1_clk, jp2_clk, pad1_bit, pad2_bit;
    ricoh_5a22 #(.PAL(PAL)) cpu (
        .clk, .rst_n,
        .a_addr, .a_rd, .a_wr, .a_data_i(a_rdata), .a_hit,
        .b_addr, .b_rd, .b_wr, .b_data_i(b_rdata), .b_hit,
        .data_o(wdata), .bus_ce, .refresh_o(), .dma_o(), .mdr_o(mdr),
        .irq_n(1'b1), .interlace_i(interlace), .overscan_i(overscan),
        .vcount_o(vcount), .hcount_o(hcount), .field_o(),
        .wrio_o(wrio), .rdio_i(wrio),
        .jp_latch_o(jp_latch), .jp1_clk_o(jp1_clk), .jp2_clk_o(jp2_clk),
        .jp1_d_i({1'b0, pad1_bit}), .jp2_d_i({1'b0, pad2_bit}),
        .cpu_fetch_o(cpu_fetch), .cpu_pc_o(cpu_pc), .cpu_a_o(cpu_a), .cpu_x_o(cpu_x),
        .cpu_y_o(cpu_y), .cpu_s_o(cpu_s), .cpu_d_o(cpu_d), .cpu_p_o(cpu_p),
        .cpu_dbr_o(cpu_dbr), .cpu_e_o(cpu_e)
    );

    // ---------------- A bus decode (work RAM and cartridge) ----------------
    logic [7:0] bank;
    logic [15:0] off;
    logic wram_sel, rom_sel, sram_sel;
    logic [16:0] wram_a, sram_a;
    logic [21:0] rom_a;
    always_comb begin
        bank = a_addr[23:16];
        off = a_addr[15:0];
        wram_sel = bank[7:1] == 7'h3f || (!bank[6] && off[15:13] == 3'b000);
        wram_a = bank[7:1] == 7'h3f ? {bank[0], off} : {4'h0, off[12:0]};
        if (hirom_i) begin
            rom_sel = !wram_sel && (bank[6] || off[15]);
            rom_a = {bank[5:0], off};
            sram_sel = sram_en_i && !bank[6] && bank[5] && off[15:13] == 3'b011;
            sram_a = {bank[3:0], off[12:0]} & sram_mask_i;
        end else begin
            sram_sel = sram_en_i && bank[6:4] == 3'b111 && bank[3:1] != 3'b111 && !off[15];
            rom_sel = !wram_sel && off[15];
            rom_a = {bank[6:0], off[14:0]};
            sram_a = {2'b00, off[14:0]} & sram_mask_i;
        end
        rom_a = rom_a & rom_mask_i;
    end

    logic [7:0] wram_rdata, rom_rdata, sram_rdata;
    assign a_hit = wram_sel || rom_sel || sram_sel;
    assign a_rdata = wram_sel ? wram_rdata : sram_sel ? sram_rdata : rom_rdata;

    // ---------------- B bus: work RAM port ($2180-$2183) ----------------
    logic [16:0] wmadd;
    wire wm_access = bus_ce && b_addr == 8'h80 && (b_rd || b_wr);
    always_ff @(posedge clk) begin
        if (!rst_n) wmadd <= 17'h0;
        else if (bus_ce && b_wr && b_addr == 8'h81) wmadd[7:0] <= wdata;
        else if (bus_ce && b_wr && b_addr == 8'h82) wmadd[15:8] <= wdata;
        else if (bus_ce && b_wr && b_addr == 8'h83) wmadd[16] <= wdata[0];
        else if (wm_access) wmadd <= wmadd + 17'd1;
    end

    // ---------------- PPUs ----------------
    logic [7:0] ppu1_rdata, ppu2_rdata, bgmode;
    logic ppu1_hit, ppu2_hit, line_start, vblank, field, px_bank, hires;
    logic [8:0] line;
    logic [9:0] px_x;
    logic [47:0] bg_px;
    logic [8:0] obj_px;
    logic [14:0] vram_raddr, vram_caddr;
    logic [15:0] vram_rdata, vram_cdata;
    logic vram_cwe_lo, vram_cwe_hi;
    logic [7:0] vram_cwdata;
    ricoh_5c77 ppu1 (
        .clk, .rst_n, .b_addr, .b_rd, .b_wr, .bus_ce, .b_data_i(wdata),
        .rdata(ppu1_rdata), .hit(ppu1_hit),
        .vram_raddr, .vram_rdata, .vram_caddr, .vram_cwe_lo, .vram_cwe_hi, .vram_cwdata, .vram_cdata,
        .line_start, .line, .vblank, .field,
        .px_x, .px_bank, .bg_px, .obj_px, .mode_o(bgmode), .hires_o(hires)
    );
    ricoh_5c78 #(.PAL(PAL)) ppu2 (
        .clk, .rst_n, .b_addr, .b_rd, .b_wr, .bus_ce, .b_data_i(wdata),
        .rdata(ppu2_rdata), .hit(ppu2_hit), .cpu_mdr(mdr), .wrio7(wrio[7]), .ext_latch(1'b0),
        .line_start, .line, .hcount(), .vblank, .field,
        .interlace_o(interlace), .overscan_o(overscan),
        .px_x, .px_bank, .bg_px, .obj_px, .bgmode, .hires_mode(hires),
        .pix_valid, .pix_x, .pix_y, .pix_rgb, .pix_hires, .frame_o
    );

    // ---------------- APU ----------------
    // 24.576 MHz / 24 = 1.024 MHz SPC700 cycles, from the master clock by a
    // phase accumulator (the APU has its own crystal on the real board).
    localparam int unsigned APU_INC = PAL ? 102400 : 128000;
    localparam int unsigned APU_MOD = PAL ? 2128137 : 2684659;
    logic [21:0] apu_acc;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            apu_acc <= 22'd0;
            apu_tick <= 1'b0;
        end else if (apu_acc + APU_INC >= APU_MOD) begin
            apu_acc <= 22'(apu_acc + APU_INC - APU_MOD);
            apu_tick <= 1'b1;
        end else begin
            apu_acc <= 22'(apu_acc + APU_INC);
            apu_tick <= 1'b0;
        end
    end

    wire apu_b = b_addr[7:6] == 2'b01;
    logic [7:0] apu_rdata, dsp_rdata, dsp_wdata, smp_wdata, smp_rdata, aram_wdata, aram_rdata;
    logic [6:0] dsp_addr;
    logic dsp_wr, smp_wr, aram_we;
    logic [15:0] smp_addr, aram_addr;
    sony_s_smp smp (
        .clk, .rst_n, .ce(apu_tick),
        .cpu_addr(b_addr[1:0]), .cpu_wr(bus_ce && b_wr && apu_b), .cpu_wdata(wdata), .cpu_rdata(apu_rdata),
        .dsp_addr, .dsp_wr, .dsp_wdata, .dsp_rdata,
        .mem_addr(smp_addr), .mem_wr(smp_wr), .mem_wdata(smp_wdata), .mem_rdata(smp_rdata),
        .ipl_we, .ipl_addr, .ipl_data, .pc_o(smp_pc), .fetch_o(smp_fetch)
    );
    sony_s_dsp dsp (
        .clk, .rst_n, .tick(apu_tick),
        .reg_addr(dsp_addr), .reg_wr(dsp_wr), .reg_wdata(dsp_wdata), .reg_rdata(dsp_rdata),
        .smp_addr, .smp_wr, .smp_wdata, .smp_rdata,
        .ram_addr(aram_addr), .ram_we(aram_we), .ram_wdata(aram_wdata), .ram_rdata(aram_rdata),
        .sample_valid, .sample_l, .sample_r, .phase_o(), .overrun_o(dsp_overrun)
    );

    // ---------------- B bus read mux ----------------
    always_comb begin
        b_hit = 1'b1;
        if (ppu1_hit) b_rdata = ppu1_rdata;
        else if (ppu2_hit) b_rdata = ppu2_rdata;
        else if (apu_b) b_rdata = apu_rdata;
        else if (b_addr == 8'h80) b_rdata = wram_rdata;
        else begin
            b_rdata = 8'h00;
            b_hit = 1'b0;
        end
    end

    // ---------------- Controllers ----------------
    snes_controller pad1 (.clk, .rst_n, .latch_i(jp_latch), .clock_i(jp1_clk), .buttons_i(pad1_i), .data_o(pad1_bit));
    snes_controller pad2 (.clk, .rst_n, .latch_i(jp_latch), .clock_i(jp2_clk), .buttons_i(pad2_i), .data_o(pad2_bit));

    // ---------------- Storage ----------------
    // Work RAM is shared by the A bus and the B-bus port; a DMA between
    // the two does not transfer on hardware, and the A side wins here.
    logic [16:0] wram_addr;
    logic wram_we;
    always_comb begin
        if (wram_sel && (a_rd || a_wr)) begin
            wram_addr = wram_a;
            wram_we = bus_ce && a_wr;
        end else begin
            wram_addr = wmadd;
            wram_we = bus_ce && b_wr && b_addr == 8'h80;
        end
    end
    snes_memory mem (
        .clk,
        .wram_addr, .wram_we, .wram_wdata(wdata), .wram_rdata,
        .rom_addr(rom_a), .rom_rdata,
        .sram_addr(sram_a), .sram_we(bus_ce && a_wr && sram_sel), .sram_wdata(wdata), .sram_rdata,
        .vram_raddr, .vram_rdata, .vram_caddr, .vram_cwe_lo, .vram_cwe_hi, .vram_cwdata, .vram_cdata,
        .aram_addr, .aram_we, .aram_wdata, .aram_rdata,
        .host_addr, .host_rdata
    );

endmodule
