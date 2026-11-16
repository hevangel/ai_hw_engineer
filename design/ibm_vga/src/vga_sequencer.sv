// IBM VGA sequencer (VGAXGA p.2-47 to 2-54, HITR p.42-50).
//
// Registers (all readable): Reset, Clocking Mode, Map Mask, Character Map
// Select, Memory Mode. Generates the dot clock enable and the character
// boundary, the processor plane address (odd/even, chain 4, extended
// memory) with the per-plane write enables, and the character generator
// table offset. Copied from ega_sequencer.sv and extended: chain 4,
// 3-bit character maps, screen off, readback.
module vga_sequencer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        addr_we,
    input  logic        data_we,
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata_idx,     // 3C4 read
    output logic [7:0]  rdata,         // 3C5 read
    input  logic        master_ce,
    output logic        dot_ce,
    output logic        char_ce,
    output logic [3:0]  dot_idx,
    output logic [3:0]  char_w,        // 8 or 9, latched at the boundary
    // processor addressing
    input  logic [16:0] cpu_off,
    input  logic        map128,        // memory map 00 (128 KB)
    input  logic        chain,         // Graphics Miscellaneous bit 1
    input  logic        page,          // Misc Output bit 5 (ASSUMPTION V13)
    output logic [15:0] cpu_paddr,
    output logic [3:0]  plane_we_mask,
    output logic        chain4,
    output logic [1:0]  chain4_map,
    // display
    input  logic        attr_b3,
    output logic [2:0]  font_tbl,      // map 2 address bits 15-13 of the character table
    output logic        ext_mem,
    output logic        shift_load,
    output logic        screen_off,
    output logic        w8,            // Clocking Mode bit 0
    output logic [39:0] dbg_regs,
    output logic [2:0]  idx
);
    logic [7:0] regs [0:4];
    logic [3:0] dotcnt;
    logic       half;
    logic       running;
    logic       is_dot;
    logic       oddeven;
    logic [7:0] wmask;

    assign running   = (regs[0][1:0] == 2'b11);
    assign dbg_regs  = {regs[4], regs[3], regs[2], regs[1], regs[0]};
    assign ext_mem   = regs[4][1];
    assign shift_load = regs[1][2];
    assign screen_off = regs[1][5];
    assign w8        = regs[1][0];
    assign oddeven   = !regs[4][2];
    assign chain4    = regs[4][3];
    assign chain4_map = cpu_off[1:0];
    assign rdata_idx = {5'd0, idx};

    // ASSUMPTION V7: undefined bits are not stored and read 0
    always_comb begin
        unique case (idx)
            3'd0:    wmask = 8'h03;
            3'd1:    wmask = 8'h3D;
            3'd2:    wmask = 8'h0F;
            3'd3:    wmask = 8'h3F;
            3'd4:    wmask = 8'h0E;
            default: wmask = 8'h00;
        endcase
    end
    assign rdata = (idx <= 3'd4) ? regs[idx] : 8'h00;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 3'd0;
            for (int i = 0; i < 5; i++) regs[i] <= 8'h00;
        end else begin
            if (addr_we) idx <= wdata[2:0];
            if (data_we && idx <= 3'd4) regs[idx] <= wdata & wmask;
        end
    end

    // Dot clock: every master pulse, or every second one with Clocking
    // Mode bit 3 (EGA E7: the first is a dot). ASSUMPTION V8: halted, no
    // dots and the phase is cleared.
    always_comb begin
        if (!running || !master_ce) is_dot = 1'b0;
        else if (regs[1][3])        is_dot = !half;
        else                        is_dot = 1'b1;
    end
    assign dot_ce  = is_dot;
    assign char_ce = is_dot && (dotcnt == 4'd0);
    assign dot_idx = dotcnt;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dotcnt <= 4'd0;
            half   <= 1'b0;
            char_w <= 4'd9;
        end else if (!running) begin
            dotcnt <= 4'd0;
            half   <= 1'b0;
        end else begin
            if (master_ce) half <= regs[1][3] ? !half : 1'b0;
            if (is_dot) begin
                if (dotcnt == 4'd0) begin
                    char_w <= regs[1][0] ? 4'd8 : 4'd9;
                    dotcnt <= 4'd1;
                end else begin
                    dotcnt <= (dotcnt + 4'd1 >= char_w) ? 4'd0 : dotcnt + 4'd1;
                end
            end
        end
    end

    // Processor plane address. ASSUMPTION V15: chain 4 uses {A15-A2,
    // A15-A14}; ASSUMPTION V13 (EGA E28): odd/even chain replaces A0 by A16
    // (128 KB map) or by NOT the page bit.
    always_comb begin
        if (chain4)     cpu_paddr = {cpu_off[15:2], cpu_off[15:14]};
        else if (chain) cpu_paddr = {cpu_off[15:1], map128 ? cpu_off[16] : !page};
        else            cpu_paddr = cpu_off[15:0];
        if (!ext_mem) cpu_paddr[15:14] = 2'b00;
    end

    // Map Mask (p.2-51) restricted by chain 4 (p.2-54) or odd/even.
    always_comb begin
        plane_we_mask = regs[2][3:0];
        if (chain4)       plane_we_mask = plane_we_mask & (4'b0001 << cpu_off[1:0]);
        else if (oddeven) plane_we_mask = plane_we_mask & (cpu_off[0] ? 4'b1010 : 4'b0101);
    end

    // Character map select (Figure 2-34/2-35), ASSUMPTION V12: map n at
    // the {n[1:0], n[2]} x 8 KB table of map 2.
    logic [2:0] map_a, map_b, map_sel;
    assign map_a = {regs[3][5], regs[3][3:2]};
    assign map_b = {regs[3][4], regs[3][1:0]};
    always_comb begin
        if (ext_mem && (map_a != map_b) && attr_b3) map_sel = map_a;
        else if (ext_mem)                           map_sel = map_b;
        else                                        map_sel = 3'd0;
        font_tbl = {map_sel[1:0], map_sel[2]};
    end
endmodule
