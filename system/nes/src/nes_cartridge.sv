// Cartridge board logic: NROM (0), MMC1/SxROM (1), UxROM (2) and CNROM (3)
// address translation and CIRAM A10/enable. Storage lives in nes_memory.
module nes_cartridge (
    input  logic cpu_clk, rst_n,
    input  logic [7:0] mapper_i,       // iNES mapper number
    input  logic mirror_v_i,           // iNES header: 1 = vertical mirroring
    input  logic [18:0] prg_mask_i,    // PRG ROM size - 1
    input  logic [17:0] chr_mask_i,    // CHR size - 1
    // CPU side (cpu_clk domain)
    input  logic [15:0] cpu_addr,
    input  logic cpu_we,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [7:0] cpu_wdata,      // D6-D5 unused by these boards
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [18:0] prg_addr,
    output logic prg_rom_sel,          // $8000-$FFFF
    output logic prg_ram_sel,          // $6000-$7FFF work RAM
    // PPU side
    input  logic [13:0] ppu_addr,
    output logic [17:0] chr_addr,
    output logic chr_sel,              // pattern-table access
    output logic ciram_a10
);
    logic [4:0] mmc1_shift;
    logic [4:0] mmc1_control, mmc1_chr0, mmc1_chr1;
    // ASSUMPTION: MMC1 PRG bit 4 (PRG-RAM disable on MMC1B) is stored but ignored;
    // work RAM is always enabled.
    /* verilator lint_off UNUSEDSIGNAL */
    logic [4:0] mmc1_prg;
    /* verilator lint_on UNUSEDSIGNAL */
    logic mmc1_last_write;
    logic [4:0] bank;                  // UxROM PRG / CNROM CHR bank
    logic is_mmc1, is_uxrom, is_cnrom;
    assign is_mmc1 = mapper_i == 8'd1;
    assign is_uxrom = mapper_i == 8'd2;
    assign is_cnrom = mapper_i == 8'd3;

    assign prg_rom_sel = cpu_addr[15];
    assign prg_ram_sel = cpu_addr[15:13] == 3'b011;
    assign chr_sel = !ppu_addr[13];

    // ---- CPU-side registers ----
    always_ff @(posedge cpu_clk) begin
        if (!rst_n) begin
            mmc1_shift <= 5'b10000; mmc1_control <= 5'h0c; mmc1_chr0 <= '0; mmc1_chr1 <= '0;
            mmc1_prg <= '0; mmc1_last_write <= 1'b0; bank <= '0;
        end else begin
            mmc1_last_write <= cpu_we && cpu_addr[15];
            if (cpu_we && cpu_addr[15]) begin
                if (is_uxrom || is_cnrom) bank <= cpu_wdata[4:0];
                // MMC1 ignores the second of two writes on consecutive cycles (RMW).
                if (is_mmc1 && !mmc1_last_write) begin
                    if (cpu_wdata[7]) begin
                        mmc1_shift <= 5'b10000; mmc1_control <= mmc1_control | 5'h0c;
                    end else if (mmc1_shift[0]) begin
                        case (cpu_addr[14:13])
                            2'd0: mmc1_control <= {cpu_wdata[0], mmc1_shift[4:1]};
                            2'd1: mmc1_chr0 <= {cpu_wdata[0], mmc1_shift[4:1]};
                            2'd2: mmc1_chr1 <= {cpu_wdata[0], mmc1_shift[4:1]};
                            default: mmc1_prg <= {cpu_wdata[0], mmc1_shift[4:1]};
                        endcase
                        mmc1_shift <= 5'b10000;
                    end else mmc1_shift <= {cpu_wdata[0], mmc1_shift[4:1]};
                end
            end
        end
    end

    // ---- PRG mapping ----
    always_comb begin
        logic [4:0] b16;               // 16 KiB bank index
        logic outer;                   // SUROM 256 KiB half select (CHR0 bit 4)
        outer = mmc1_chr0[4] && prg_mask_i[18];
        b16 = {4'd0, cpu_addr[14]};
        if (is_mmc1) begin
            case (mmc1_control[3:2])
                2'd0, 2'd1: b16 = {outer, mmc1_prg[3:1], cpu_addr[14]};
                2'd2: b16 = cpu_addr[14] ? {outer, mmc1_prg[3:0]} : {outer, 4'd0};
                default: b16 = cpu_addr[14] ? {outer, 4'hf} : {outer, mmc1_prg[3:0]};
            endcase
        end else if (is_uxrom) b16 = cpu_addr[14] ? 5'h1f : bank[4:0];
        prg_addr = {b16, cpu_addr[13:0]} & prg_mask_i;
    end

    // ---- CHR mapping and mirroring ----
    always_comb begin
        logic [4:0] b4;                // 4 KiB bank index
        b4 = {4'd0, ppu_addr[12]};
        if (is_mmc1) begin
            if (mmc1_control[4]) b4 = ppu_addr[12] ? mmc1_chr1 : mmc1_chr0;
            else b4 = {mmc1_chr0[4:1], ppu_addr[12]};
        end else if (is_cnrom) b4 = {2'd0, bank[1:0], ppu_addr[12]};
        chr_addr = {1'b0, b4, ppu_addr[11:0]} & chr_mask_i;
        if (is_mmc1) begin
            case (mmc1_control[1:0])
                2'd0: ciram_a10 = 1'b0;
                2'd1: ciram_a10 = 1'b1;
                2'd2: ciram_a10 = ppu_addr[10];
                default: ciram_a10 = ppu_addr[11];
            endcase
        end else ciram_a10 = mirror_v_i ? ppu_addr[10] : ppu_addr[11];
    end
endmodule
