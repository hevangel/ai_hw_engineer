// Ricoh RP2C02 (NTSC) / RP2C07 (PAL) picture processing unit. See spec/spec.md.
module ricoh_2c02 #(
    parameter bit REGION = 1'b0        // 0 = 2C02 NTSC, 1 = 2C07 PAL
) (
    input  logic clk, rst_n,
    input  logic dot_ce,
    input  logic cpu_ce,
    input  logic cpu_cs,
    input  logic cpu_we,
    input  logic [2:0] cpu_addr,
    input  logic [7:0] cpu_wdata,
    output logic [7:0] cpu_rdata,
    output logic nmi_n,
    output logic [13:0] vram_addr,
    output logic vram_rd, vram_we,
    output logic [7:0] vram_wdata,
    input  logic [7:0] vram_rdata,
    output logic [5:0] pixel,
    output logic [2:0] emphasis,
    output logic pixel_valid,
    output logic [8:0] scanline, dot,
    output logic frame_odd
);
    localparam logic [8:0] PRE_LINE = REGION ? 9'd311 : 9'd261;

    // ---- Registers ---------------------------------------------------
    /* verilator lint_off UNUSEDSIGNAL */
    logic [7:0] ctrl;   // bits 1:0 live in t; bit 6 (EXT master/slave) is not modelled
    /* verilator lint_on UNUSEDSIGNAL */
    logic [7:0] mask, oam_addr, io_latch, read_buffer;
    logic [14:0] v, t;
    logic [2:0] fine_x;
    logic w, vbl, sprite0_hit, sprite_ovf, suppress_vbl;
    logic [5:0] palette [0:31];

    // ---- Raster ------------------------------------------------------
    logic rendering, visible_line, pre_line, fetch_line, eval_line;
    assign rendering = mask[3] || mask[4];
    assign visible_line = scanline < 9'd240;
    assign pre_line = scanline == PRE_LINE;
    assign fetch_line = rendering && (visible_line || pre_line);
    assign eval_line = rendering && visible_line;

    // ---- Background pipeline -------------------------------------------
    logic [7:0] nt_byte, pat_lo, pat_hi;
    logic [1:0] at_bits;
    logic [15:0] bg_lo, bg_hi, at_lo, at_hi;
    logic [2:0] phase;
    logic bg_fetch_dot, spr_fetch_dot, nt_dummy_dot, shift_dot;
    logic [13:0] bg_addr, spr_addr;
    assign phase = 3'(dot - 9'd1);
    assign bg_fetch_dot = (dot >= 9'd1 && dot <= 9'd256) || (dot >= 9'd321 && dot <= 9'd336);
    assign spr_fetch_dot = dot >= 9'd257 && dot <= 9'd320;
    assign nt_dummy_dot = dot >= 9'd337;
    assign shift_dot = (dot >= 9'd2 && dot <= 9'd257) || (dot >= 9'd322 && dot <= 9'd337);
    always_comb begin
        case (phase[2:1])
            2'd0: bg_addr = {2'b10, v[11:0]};
            2'd1: bg_addr = {2'b10, v[11:10], 4'b1111, v[9:7], v[4:2]};
            2'd2: bg_addr = {1'b0, ctrl[4], nt_byte, 1'b0, v[14:12]};
            default: bg_addr = {1'b0, ctrl[4], nt_byte, 1'b1, v[14:12]};
        endcase
    end

    // ---- Sprites -------------------------------------------------------
    logic [7:0] oam_rdata;
    logic spr_ovf_set, spr_behind, spr_zero;
    logic [1:0] spr_pix, spr_pal;
    logic oam_we;
    assign oam_we = cpu_ce && cpu_cs && cpu_we && cpu_addr == 3'd4;
    ricoh_2c02_sprites sprites (
        .clk, .rst_n, .dot_ce, .dot, .line(scanline), .eval_line, .fetch_line, .pre_line,
        .tall(ctrl[5]), .table_sel(ctrl[3]), .show(mask[4]), .show_left(mask[2]),
        .oam_we, .oam_addr, .oam_wdata(cpu_wdata), .oam_rdata,
        .fetch_addr(spr_addr), .vram_rdata, .overflow_set(spr_ovf_set),
        .pix(spr_pix), .pal(spr_pal), .behind(spr_behind), .zero(spr_zero)
    );

    // ---- CPU $2007 bus access ------------------------------------------
    logic [1:0] acc_left;            // dots remaining in the pending access
    logic acc_write;
    logic [13:0] acc_addr;
    logic [7:0] acc_data;
    logic palette_space;
    assign palette_space = v[13:8] == 6'h3f;

    always_comb begin
        vram_rd = 1'b0; vram_we = 1'b0; vram_wdata = acc_data; vram_addr = {v[13:0]};
        if (acc_left != 0) begin
            vram_addr = acc_addr;
            vram_rd = !acc_write;
            vram_we = acc_write && acc_left == 2'd1;
        end else if (fetch_line) begin
            vram_rd = 1'b1;
            if (spr_fetch_dot) vram_addr = phase[2] ? spr_addr : {2'b10, v[11:0]};
            else if (bg_fetch_dot || nt_dummy_dot) vram_addr = nt_dummy_dot ? {2'b10, v[11:0]} : bg_addr;
            else vram_rd = 1'b0;
        end
    end

    // ---- Pixel composition ------------------------------------------------
    logic [1:0] bg_pix, bg_pal;
    logic [3:0] fx_sel;
    logic [4:0] pal_addr;
    logic [4:0] pal_index;
    logic hit;
    // Dots 2-256 shift before the pixel is taken; select the post-shift bit.
    assign fx_sel = 4'd15 - {1'b0, fine_x} - {3'd0, dot != 9'd1};
    always_comb begin
        bg_pix = {bg_hi[fx_sel], bg_lo[fx_sel]};
        bg_pal = {at_hi[fx_sel], at_lo[fx_sel]};
        if (!mask[3] || (dot <= 9'd8 && !mask[1])) bg_pix = 2'd0;
        hit = 1'b0;
        if (bg_pix == 0 && spr_pix == 0) pal_addr = 5'd0;
        else if (bg_pix == 0) pal_addr = {1'b1, spr_pal, spr_pix};
        else if (spr_pix == 0) pal_addr = {1'b0, bg_pal, bg_pix};
        else begin
            pal_addr = spr_behind ? {1'b0, bg_pal, bg_pix} : {1'b1, spr_pal, spr_pix};
            hit = spr_zero && dot != 9'd256;
        end
        if (!rendering) pal_addr = palette_space ? v[4:0] : 5'd0;
    end
    // $3F10/$3F14/$3F18/$3F1C mirror the background entries.
    function automatic logic [4:0] pal_mirror(input logic [4:0] a);
        pal_mirror = (a[1:0] == 2'd0) ? {1'b0, a[3:0]} : a;
    endfunction
    assign pal_index = pal_mirror(pal_addr);

    // ---- CPU register reads (value before this access's side effects) -----
    logic [7:0] reg_value;
    always_comb begin
        case (cpu_addr)
            3'd2: reg_value = {vbl, sprite0_hit, sprite_ovf, io_latch[4:0]};
            3'd4: reg_value = oam_rdata;
            3'd7: reg_value = palette_space ? {io_latch[7:6], palette[pal_mirror(v[4:0])]} : read_buffer;
            default: reg_value = io_latch;
        endcase
    end

    // ---- I/O latch decay: each bit fades to 0 about 600 ms after it was
    // last driven. Writes drive all bits; reads drive only the bits the
    // register returns ($2002: 7-5, palette reads: 5-0).
    localparam logic [5:0] DECAY_FRAMES = REGION ? 6'd30 : 6'd36;
    logic [7:0] latch_drive;
    logic [47:0] decay_age;          // six-bit frame age per latch bit
    always_comb begin
        latch_drive = 8'h00;
        if (cpu_ce && cpu_cs) begin
            if (cpu_we) latch_drive = 8'hff;
            else if (cpu_addr == 3'd2) latch_drive = 8'he0;
            else if (cpu_addr == 3'd4) latch_drive = 8'hff;
            else if (cpu_addr == 3'd7) latch_drive = palette_space ? 8'h3f : 8'hff;
        end
    end

    // Rendering-time $2007 increments the scroll counters instead of v += 1/32.
    function automatic logic [14:0] inc_x(input logic [14:0] a);
        if (a[4:0] == 5'd31) inc_x = {a[14:11], ~a[10], a[9:5], 5'd0};
        else inc_x = a + 15'd1;
    endfunction
    function automatic logic [14:0] inc_y(input logic [14:0] a);
        logic [4:0] cy;
        if (a[14:12] != 3'd7) inc_y = a + 15'h1000;
        else begin
            cy = a[9:5];
            if (cy == 5'd29) inc_y = {3'd0, ~a[11], a[10], 5'd0, a[4:0]};
            else if (cy == 5'd31) inc_y = {3'd0, a[11:10], 5'd0, a[4:0]};
            else inc_y = {3'd0, a[11:10], cy + 5'd1, a[4:0]};
        end
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ctrl <= '0; mask <= '0; oam_addr <= '0; io_latch <= '0; read_buffer <= '0;
            decay_age <= '0;
            v <= '0; t <= '0; fine_x <= '0; w <= 1'b0;
            vbl <= 1'b0; sprite0_hit <= 1'b0; sprite_ovf <= 1'b0; suppress_vbl <= 1'b0;
            scanline <= '0; dot <= '0; frame_odd <= 1'b0;
            acc_left <= '0; acc_write <= 1'b0; acc_addr <= '0; acc_data <= '0;
            nt_byte <= '0; at_bits <= '0; pat_lo <= '0; pat_hi <= '0;
            bg_lo <= '0; bg_hi <= '0; at_lo <= '0; at_hi <= '0;
            pixel <= '0; emphasis <= '0; pixel_valid <= 1'b0; cpu_rdata <= '0;
        end else begin
            // The sprite unit pulses overflow for one master clock.
            if (spr_ovf_set) sprite_ovf <= 1'b1;
            // ---------------- PPU dot ----------------
            if (dot_ce) begin
                pixel_valid <= 1'b0;
                if (visible_line && dot >= 9'd1 && dot <= 9'd256) begin
                    pixel <= palette[pal_index] & (mask[0] ? 6'h30 : 6'h3f);
                    emphasis <= mask[7:5];
                    pixel_valid <= 1'b1;
                    if (hit && rendering && mask[3] && mask[4]) sprite0_hit <= 1'b1;
                end
                if (fetch_line) begin
                    if (shift_dot) begin
                        bg_lo <= bg_lo << 1; bg_hi <= bg_hi << 1;
                        at_lo <= at_lo << 1; at_hi <= at_hi << 1;
                    end
                    if (bg_fetch_dot) begin
                        case (phase)
                            3'd1: nt_byte <= vram_rdata;
                            3'd3: at_bits <= 2'(vram_rdata >> {v[6], v[1], 1'b0});
                            3'd5: pat_lo <= vram_rdata;
                            3'd7: begin pat_hi <= vram_rdata; v <= inc_x(v); end
                            default: ;
                        endcase
                    end
                    // Shift then reload the low bytes at dots 9, 17, ... 257, 329, 337.
                    if (phase == 3'd0 && ((dot >= 9'd9 && dot <= 9'd257) || dot == 9'd329 || dot == 9'd337)) begin
                        bg_lo <= {bg_lo[14:7], pat_lo}; bg_hi <= {bg_hi[14:7], pat_hi};
                        at_lo <= {at_lo[14:7], {8{at_bits[0]}}}; at_hi <= {at_hi[14:7], {8{at_bits[1]}}};
                    end
                    if (dot == 9'd256) v <= inc_y(inc_x(v));
                    if (dot == 9'd257) v <= {v[14:11], t[10], v[9:5], t[4:0]};
                    if (pre_line && dot >= 9'd280 && dot <= 9'd304) v <= {t[14:11], v[10], t[9:5], v[4:0]};
                    if (spr_fetch_dot) oam_addr <= '0;
                end
                if (acc_left != 0) begin
                    acc_left <= acc_left - 2'd1;
                    if (acc_left == 2'd1 && !acc_write) read_buffer <= vram_rdata;
                end
                // Flags.
                if (scanline == 9'd241 && dot == 9'd1) begin
                    if (!suppress_vbl) vbl <= 1'b1;
                    suppress_vbl <= 1'b0;
                    for (int i = 0; i < 8; i++) begin
                        if (decay_age[i*6 +: 6] == DECAY_FRAMES) io_latch[i] <= 1'b0;
                        else decay_age[i*6 +: 6] <= decay_age[i*6 +: 6] + 6'd1;
                    end
                end
                if (pre_line && dot == 9'd1) begin
                    vbl <= 1'b0; sprite0_hit <= 1'b0; sprite_ovf <= 1'b0;
                end
                // Raster advance with the NTSC odd-frame skip.
                if (!REGION && pre_line && dot == 9'd339 && frame_odd && rendering) begin
                    dot <= '0; scanline <= '0; frame_odd <= 1'b0;
                end else if (dot == 9'd340) begin
                    dot <= '0;
                    if (pre_line) begin scanline <= '0; frame_odd <= !frame_odd; end
                    else scanline <= scanline + 9'd1;
                end else dot <= dot + 9'd1;
            end

            // ---------------- CPU register access ----------------
            if (cpu_ce && cpu_cs) begin
                for (int i = 0; i < 8; i++) if (latch_drive[i]) decay_age[i*6 +: 6] <= '0;
                if (!cpu_we) begin
                    cpu_rdata <= reg_value;
                    io_latch <= (io_latch & ~latch_drive) | (reg_value & latch_drive);
                    case (cpu_addr)
                        3'd2: begin
                            vbl <= 1'b0; w <= 1'b0;
                            if (scanline == 9'd241 && dot == 9'd1 && !dot_ce) suppress_vbl <= 1'b1;
                        end
                        3'd7: begin
                            acc_left <= 2'd2; acc_write <= 1'b0;
                            acc_addr <= palette_space ? {2'b10, v[11:0]} : v[13:0];
                            v <= (fetch_line) ? inc_y(inc_x(v)) : v + (ctrl[2] ? 15'd32 : 15'd1);
                        end
                        default: ;
                    endcase
                end else begin
                    io_latch <= cpu_wdata;
                    case (cpu_addr)
                        3'd0: begin ctrl <= cpu_wdata; t[11:10] <= cpu_wdata[1:0]; end
                        3'd1: mask <= cpu_wdata;
                        3'd3: oam_addr <= cpu_wdata;
                        3'd4: oam_addr <= oam_addr + 8'd1;
                        3'd5: begin
                            if (!w) begin t[4:0] <= cpu_wdata[7:3]; fine_x <= cpu_wdata[2:0]; end
                            else begin t[9:5] <= cpu_wdata[7:3]; t[14:12] <= cpu_wdata[2:0]; end
                            w <= !w;
                        end
                        3'd6: begin
                            if (!w) begin t[13:8] <= cpu_wdata[5:0]; t[14] <= 1'b0; end
                            else begin t[7:0] <= cpu_wdata; v <= {t[14:8], cpu_wdata}; end
                            w <= !w;
                        end
                        3'd7: begin
                            if (palette_space) palette[pal_mirror(v[4:0])] <= cpu_wdata[5:0];
                            else begin
                                acc_left <= 2'd2; acc_write <= 1'b1; acc_addr <= v[13:0]; acc_data <= cpu_wdata;
                            end
                            v <= (fetch_line) ? inc_y(inc_x(v)) : v + (ctrl[2] ? 15'd32 : 15'd1);
                        end
                        default: ;
                    endcase
                end
            end
        end
    end

    assign nmi_n = !(vbl && ctrl[7]);

`ifdef FORMAL
    `include "ricoh_2c02_props.sv"
`endif
endmodule
