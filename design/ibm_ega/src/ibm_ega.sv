// IBM Enhanced Graphics Adapter (1984), original card with the Graphics
// Memory Expansion Card and Module Kit installed (256 KB), as an ISA 8-bit
// slot device with a direct-drive monitor interface.
//
// Sources: IBM "IBM Enhanced Graphics Adapter" technical reference dated
// August 2, 1984 (TR), its logic diagrams and BIOS listing; see
// spec/spec.md for the interface, the register map and the assumption
// ledger (ASSUMPTION En tags below).
//
// One clock domain `clk`. Every input is sampled on `clk`; the three dot
// clock sources are clock-enable inputs. `rst_n` is the simulation/FPGA
// power-on reset; `reset_drv_i` is the slot RESET DRV.
module ibm_ega #(
    parameter ROM_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,
    // ISA slot
    input  logic        reset_drv_i,
    input  logic [19:0] a_i,
    input  logic [7:0]  d_i,
    output logic [7:0]  d_o,
    output logic        d_oe_o,
    input  logic        ior_n_i,
    input  logic        iow_n_i,
    input  logic        memr_n_i,
    input  logic        memw_n_i,
    input  logic        aen_i,
    input  logic        dack0_n_i,
    output logic        irq2_o,
    output logic        irq2_oe_o,
    output logic        iochrdy_o,
    output logic        iochrdy_oe_o,
    input  logic        osc14_ce_i,
    input  logic        osc16_ce_i,
    input  logic        ext_osc_ce_i,
    // board configuration
    input  logic [3:0]  sw_i,
    input  logic        p1_i,
    input  logic        p3_i,
    // feature connector (not modeled beyond these)
    input  logic [1:0]  feat_i,
    output logic [1:0]  fc_o,
    // light pen (P2)
    input  logic        lpen_n_i,
    input  logic        lpen_sw_n_i,
    // monitor (J3 direct drive)
    output logic        pix_en_o,
    output logic [5:0]  video_o,
    output logic        hsync_o,
    output logic        vsync_o,
    output logic        video_oe_o,
    output logic        blank_o,
    output logic        de_o,
    // simulation-only debug reads (no side effects)
    input  logic [7:0]  dbg_reg_addr_i,
    output logic [7:0]  dbg_reg_data_o,
    input  logic [1:0]  dbg_plane_i,
    input  logic [15:0] dbg_mem_addr_i,
    output logic [7:0]  dbg_mem_data_o
);
    // ------------------------------------------------------ input sampling
    logic [19:0] s_a, p_a;
    logic [7:0]  s_d, p_d;
    logic        s_ior, s_iow, s_memr, s_memw, s_aen, s_dack0, s_rst;
    logic        p_ior, p_iow, p_memr, p_memw, p_aen;
    logic        s_osc14, s_osc16, s_ext;
    logic [3:0]  s_sw;
    logic        s_p1, s_p3, s_lpen, s_lpsw;
    logic [1:0]  s_feat;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_a <= '0; s_d <= '0; p_a <= '0; p_d <= '0;
            s_ior <= 1'b1; s_iow <= 1'b1; s_memr <= 1'b1; s_memw <= 1'b1;
            p_ior <= 1'b1; p_iow <= 1'b1; p_memr <= 1'b1; p_memw <= 1'b1;
            s_aen <= 1'b0; p_aen <= 1'b0; s_dack0 <= 1'b1; s_rst <= 1'b0;
            s_osc14 <= 1'b0; s_osc16 <= 1'b0; s_ext <= 1'b0;
            s_sw <= 4'hF; s_p1 <= 1'b1; s_p3 <= 1'b1; s_feat <= 2'b00;
            s_lpen <= 1'b1; s_lpsw <= 1'b1;
        end else begin
            s_a <= a_i; s_d <= d_i; s_aen <= aen_i;
            s_ior <= ior_n_i; s_iow <= iow_n_i; s_memr <= memr_n_i; s_memw <= memw_n_i;
            s_dack0 <= dack0_n_i; s_rst <= reset_drv_i;
            p_a <= s_a; p_d <= s_d; p_aen <= s_aen;
            p_ior <= s_ior; p_iow <= s_iow; p_memr <= s_memr; p_memw <= s_memw;
            s_osc14 <= osc14_ce_i; s_osc16 <= osc16_ce_i; s_ext <= ext_osc_ce_i;
            s_sw <= sw_i; s_p1 <= p1_i; s_p3 <= p3_i; s_feat <= feat_i;
            s_lpen <= lpen_n_i; s_lpsw <= lpen_sw_n_i;
        end
    end

    // Strobe events: writes take effect at the rising edge with the address
    // and data of the last clock the strobe was low.
    logic iow_ev, ior_ev, memw_ev, memr_ev;
    assign iow_ev  = !p_iow  && s_iow;
    assign ior_ev  = !p_ior  && s_ior;
    assign memw_ev = !p_memw && s_memw;
    assign memr_ev = !p_memr && s_memr;

    // --------------------------------------------------------- registers
    logic [7:0] misc;
    logic [1:0] fcr;
    logic       lpff, master_ce;
    logic [7:0] isr0;
    logic [71:0] gc1_regs, gc2_regs;
    logic        gc_graphics, gc_chain;
    logic [1:0]  gc_mem_map;
    // Sheet 4: CHAIN and GRAPHICS come from the GC on sheet 6 (GC 1), the
    // memory map select CDSEL1/0 from the GC on sheet 7 (GC 2). Both chips
    // receive every register write, so the values are equal.
    assign gc_graphics = gc1_regs[48];
    assign gc_chain    = gc1_regs[49];
    assign gc_mem_map  = gc2_regs[51:50];

    // ----------------------------------------------------------- decode
    // One decoder: the address of the last strobe-low clock at a strobe
    // release (write/read side effects), else the current address (read
    // data drive). Strobes never overlap.
    logic        any_ev;
    logic [19:0] dec_a;
    logic        dec_aen;
    logic d_attr, d_c2, d_seq, d_gc2pos, d_gc1pos, d_gc, d_crtc, d_xa, d_lpclr, d_lpset;
    logic d_rom, d_ram;
    logic [16:0] d_off;
    assign any_ev  = iow_ev || ior_ev || memw_ev || memr_ev;
    assign dec_a   = any_ev ? p_a : s_a;
    assign dec_aen = any_ev ? p_aen : s_aen;

    ega_io_decode u_dec (
        .a(dec_a), .aen(dec_aen), .p3(s_p3), .mono_n(misc[0]), .dack0_n(s_dack0),
        .ram_en(misc[1]), .mem_map(gc_mem_map),
        .io_attr(d_attr), .io_c2(d_c2), .io_seq(d_seq), .io_gc2pos(d_gc2pos),
        .io_gc1pos(d_gc1pos), .io_gc(d_gc), .io_crtc(d_crtc), .io_xa(d_xa),
        .io_lpclr(d_lpclr), .io_lpset(d_lpset),
        .mem_rom(d_rom), .mem_ram(d_ram), .ram_off(d_off));

    // -------------------------------------------------- external registers
    ega_ext_regs u_ext (
        .clk, .rst_n, .reset_drv(s_rst),
        .misc_we(iow_ev && d_c2), .fcr_we(iow_ev && d_xa),
        .lpclr_we(iow_ev && d_lpclr), .lpset_we(iow_ev && d_lpset),
        .wdata(p_d), .sw(s_sw), .feat(s_feat), .lpen_n(s_lpen),
        .osc14_ce(s_osc14), .osc16_ce(s_osc16), .ext_osc_ce(s_ext),
        .vint(vint), .misc, .fcr, .lpff, .master_ce, .isr0);

    // ---------------------------------------------------------- sequencer
    logic        dot_ce, char_ce;
    logic [3:0]  dot_idx, char_w, seq_idx;
    logic [15:0] cpu_paddr;
    logic [3:0]  plane_we_mask;
    logic [1:0]  font_map;
    logic        ext_mem, shift_load, fattr_b3;
    logic [39:0] seq_regs;

    ega_sequencer u_seq (
        .clk, .rst_n,
        .addr_we(iow_ev && d_seq && !p_a[0]), .data_we(iow_ev && d_seq && p_a[0]),
        .wdata(p_d[3:0]), .master_ce,
        .dot_ce, .char_ce, .dot_idx, .char_w,
        .cpu_off(d_off), .map128(gc_mem_map == 2'b00),
        .chain(gc_chain), .page(misc[5]),
        .cpu_paddr, .plane_we_mask,
        .attr_b3(fattr_b3), .font_map, .ext_mem, .shift_load,
        .dbg_regs(seq_regs), .idx(seq_idx));

    // --------------------------------------------------------------- CRTC
    logic        f_de, f_blank, f_hs, f_cursor, f_ul, f_hcodd, vs_line, vint, vrtc_start;
    logic [15:0] crtc_addr, lp;
    logic [4:0]  rs, crtc_idx;
    logic [1:0]  de_skew, cur_skew, hr_delay;
    logic        retrace_en;
    logic [7:0]  crtc_rdata;
    logic [199:0] crtc_regs;

    ega_crtc u_crtc (
        .clk, .rst_n, .reset_drv(s_rst),
        .addr_we(iow_ev && d_crtc && !p_a[0]), .data_we(iow_ev && d_crtc && p_a[0]),
        .wdata(p_d), .rdata(crtc_rdata),
        .char_ce, .lpff,
        .f_de, .f_blank, .f_hs, .f_cursor, .f_ul, .f_hcodd, .vs_line,
        .disp_addr(crtc_addr), .rs, .vint, .vrtc_start,
        .de_skew, .cur_skew, .hr_delay, .retrace_en,
        .dbg_regs(crtc_regs), .idx(crtc_idx), .lp);

    // ------------------------------------------------------- plane RAMs
    logic [7:0]  a_rdata [0:3];
    logic [31:0] b_rdata;
    logic [15:0] b_addr;
    logic [7:0]  dbg_pdata [0:3];
    logic [7:0]  wd [0:3];
    logic [1:0]  wr_valid;
    logic [3:0]  plane_we;

    for (genvar p = 0; p < 4; p++) begin : g_plane
        logic [7:0] b_q;
        assign plane_we[p] = memw_ev && d_ram && plane_we_mask[p] && wr_valid[p/2];
        ega_plane_ram u_ram (
            .clk, .a_addr(cpu_paddr),
            .a_we(plane_we[p]),
            .a_wdata(wd[p]), .a_rdata(a_rdata[p]),
            .b_addr, .b_rdata(b_q),
            .dbg_addr(dbg_mem_addr_i), .dbg_rdata(dbg_pdata[p]));
        assign b_rdata[8*p +: 8] = b_q;
    end

    // --------------------------------------------------- display fetch
    logic [5:2]  h_de;
    logic        h_blank;
    logic [5:3]  h_hs;
    logic [5:1]  h_cursor;
    logic [31:0] e_planes, n_planes;
    logic [7:0]  e_font, n_font;
    logic        e_gcg, n_gcg, e_odd, n_odd, e_ul, n_ul;

    ega_display_fetch u_fetch (
        .clk, .rst_n, .char_ce,
        .f_de, .f_blank, .f_hs, .f_cursor, .f_ul, .f_hcodd,
        .crtc_addr, .rs, .ext_mem, .gc_graphics,
        .font_map, .fattr_b3, .b_addr, .b_rdata,
        .h_de, .h_blank, .h_hs, .h_cursor,
        .e_planes, .n_planes, .e_font, .n_font, .e_gcg, .n_gcg,
        .e_odd, .n_odd, .e_ul, .n_ul);

    // --------------------------------------------- graphics controllers
    logic        gc1_drv, gc2_drv;
    logic [7:0]  gc1_rd, gc2_rd;
    logic [17:0] gc1_e, gc1_n, gc2_e, gc2_n;
    logic [3:0]  gc1_idx, gc2_idx;
    logic [1:0]  gc1_pos, gc2_pos;
    logic [7:0]  lat [0:3];
    logic        latch_we;
    assign latch_we = memr_ev && d_ram;

    ega_graphics_ctrl u_gc1 (
        .clk, .rst_n,
        .addr_we(iow_ev && d_gc && !p_a[0]), .data_we(iow_ev && d_gc && p_a[0]),
        .pos_we(iow_ev && d_gc1pos), .wdata(p_d),
        .cpu_d(p_d), .wd0(wd[0]), .wd1(wd[1]), .wr_valid(wr_valid[0]),
        .rd0(a_rdata[0]), .rd1(a_rdata[1]), .a0(d_off[0]), .latch_we,
        .rd_drive(gc1_drv), .rd_data(gc1_rd),
        .shift_load,
        .e_p0(e_planes[7:0]), .e_p1(e_planes[15:8]), .e_odd,
        .n_p0(n_planes[7:0]), .n_p1(n_planes[15:8]), .n_odd,
        .e_ser(gc1_e), .n_ser(gc1_n),
        .dbg_regs(gc1_regs), .idx(gc1_idx), .pos(gc1_pos),
        .lat0(lat[0]), .lat1(lat[1]));

    ega_graphics_ctrl u_gc2 (
        .clk, .rst_n,
        .addr_we(iow_ev && d_gc && !p_a[0]), .data_we(iow_ev && d_gc && p_a[0]),
        .pos_we(iow_ev && d_gc2pos), .wdata(p_d),
        .cpu_d(p_d), .wd0(wd[2]), .wd1(wd[3]), .wr_valid(wr_valid[1]),
        .rd0(a_rdata[2]), .rd1(a_rdata[3]), .a0(d_off[0]), .latch_we,
        .rd_drive(gc2_drv), .rd_data(gc2_rd),
        .shift_load,
        .e_p0(e_planes[23:16]), .e_p1(e_planes[31:24]), .e_odd,
        .n_p0(n_planes[23:16]), .n_p1(n_planes[31:24]), .n_odd,
        .e_ser(gc2_e), .n_ser(gc2_n),
        .dbg_regs(gc2_regs), .idx(gc2_idx), .pos(gc2_pos),
        .lat0(lat[2]), .lat1(lat[3]));

    logic [35:0] e_ser, n_ser;
    always_comb begin
        for (int j = 0; j < 9; j++) begin
            e_ser[4*j +: 4] = {gc2_e[2*j +: 2], gc1_e[2*j +: 2]};
            n_ser[4*j +: 4] = {gc2_n[2*j +: 2], gc1_n[2*j +: 2]};
        end
    end

    // ------------------------------------------------- attribute controller
    logic        de_in, e_cur, n_cur, hs_in;
    logic [5:0]  last_color, attr_idx, overscan, cpe;
    logic        attr_ff, de_out;
    logic [95:0] pal_flat;
    logic [3:0]  amode, pan, w_now;
    logic [4:0]  blink;

    // ASSUMPTION E18: pipeline depths (data k-2, DE k-1-skew, cursor
    // k-2-skew, blank k-1, horizontal retrace k-delay, vertical retrace k).
    always_comb begin
        unique case (de_skew)
            2'd0: de_in = h_de[5];
            2'd1: de_in = h_de[4];
            2'd2: de_in = h_de[3];
            2'd3: de_in = h_de[2];
        endcase
        unique case (cur_skew)
            2'd0: begin e_cur = h_cursor[4]; n_cur = h_cursor[5]; end
            2'd1: begin e_cur = h_cursor[3]; n_cur = h_cursor[4]; end
            2'd2: begin e_cur = h_cursor[2]; n_cur = h_cursor[3]; end
            2'd3: begin e_cur = h_cursor[1]; n_cur = h_cursor[2]; end
        endcase
        unique case (hr_delay)
            2'd0: hs_in = f_hs;
            2'd1: hs_in = h_hs[5];
            2'd2: hs_in = h_hs[4];
            2'd3: hs_in = h_hs[3];
        endcase
    end
    assign w_now = char_ce ? (seq_regs[8] ? 4'd8 : 4'd9) : char_w;

    ega_attribute_ctrl u_attr (
        .clk, .rst_n,
        .we(iow_ev && d_attr), .ff_reset(ior_ev && d_xa), .wdata(p_d[5:0]),
        .dot_ce, .char_ce, .dot_idx, .w_now, .vrtc_start,
        .e_attr(e_planes[15:8]), .n_attr(n_planes[15:8]),
        .e_code_hi(e_planes[7:5]), .n_code_hi(n_planes[7:5]),
        .e_font, .n_font, .e_gcg, .n_gcg, .e_ul, .n_ul,
        .e_cursor(e_cur), .n_cursor(n_cur), .e_ser, .n_ser,
        .de_in, .blank_in(h_blank), .hs_in(hs_in && retrace_en),
        .vs_in(vs_line && retrace_en),
        .hpol(misc[6]), .vpol(misc[7]), .drivers_off(misc[4]), .p1(s_p1),
        .pix_en(pix_en_o), .video(video_o), .hsync(hsync_o), .vsync(vsync_o),
        .blank(blank_o), .de(de_o), .video_oe(video_oe_o),
        .last_color, .de_out,
        .idx(attr_idx), .ff(attr_ff), .pal_flat, .mode(amode), .overscan, .cpe,
        .pan, .blink);

    // --------------------------------------------------------- slot outputs
    logic [1:0] diag;
    always_comb begin
        // ASSUMPTION E11: video status mux (TR p.17/p.60)
        unique case (cpe[5:4])
            2'b00: diag = {last_color[2], last_color[0]};
            2'b01: diag = {last_color[3], last_color[1]};
            2'b10: diag = {last_color[5], last_color[4]};
            2'b11: diag = 2'b00;
        endcase
    end

    logic [7:0] isr1;
    // ASSUMPTION E10: bit 0 = 1 while display enable is off; bits 7-6 pull-ups
    assign isr1 = {2'b11, diag, vs_line, s_lpsw, lpff, !de_out};

    logic       io_rd, mem_rd;
    logic [7:0] ram_rd;
    assign io_rd  = !s_ior && (d_c2 || d_xa || (d_crtc && s_a[0]));
    assign mem_rd = !s_memr && (d_rom || d_ram);

    // ASSUMPTION E30: controllers combine by AND; none selected reads FFh
    always_comb begin
        if (gc1_drv && gc2_drv) ram_rd = gc1_rd & gc2_rd;
        else if (gc1_drv)       ram_rd = gc1_rd;
        else if (gc2_drv)       ram_rd = gc2_rd;
        else                    ram_rd = 8'hFF;
    end

    logic [7:0] rom_rdata;
    ega_rom #(.ROM_FILE(ROM_FILE)) u_rom (.clk, .addr(s_a[13:0]), .rdata(rom_rdata));

    always_comb begin
        d_oe_o = io_rd || mem_rd;
        if (!s_ior && d_c2)       d_o = isr0;
        else if (!s_ior && d_xa)  d_o = isr1;
        else if (!s_ior)          d_o = crtc_rdata;
        else if (d_rom)           d_o = rom_rdata;
        else                      d_o = ram_rd;
    end

    assign irq2_o       = vint;                      // ASSUMPTION E9
    assign irq2_oe_o    = !crtc_regs[8*8'h11 + 5];
    assign iochrdy_o    = 1'b1;                      // ASSUMPTION E26
    assign iochrdy_oe_o = 1'b0;
    assign fc_o         = fcr;

    // ------------------------------------------------------ debug reads
    always_comb begin
        dbg_reg_data_o = 8'hFF;
        if (dbg_reg_addr_i <= 8'h04)
            dbg_reg_data_o = seq_regs[8*dbg_reg_addr_i[2:0] +: 8];
        else if (dbg_reg_addr_i == 8'h05)
            dbg_reg_data_o = {4'd0, seq_idx};
        else if (dbg_reg_addr_i >= 8'h10 && dbg_reg_addr_i <= 8'h28)
            dbg_reg_data_o = crtc_regs[8*(dbg_reg_addr_i - 8'h10) +: 8];
        else if (dbg_reg_addr_i == 8'h29) dbg_reg_data_o = {3'd0, crtc_idx};
        else if (dbg_reg_addr_i == 8'h2A) dbg_reg_data_o = lp[15:8];
        else if (dbg_reg_addr_i == 8'h2B) dbg_reg_data_o = lp[7:0];
        else if (dbg_reg_addr_i >= 8'h30 && dbg_reg_addr_i <= 8'h38)
            dbg_reg_data_o = gc1_regs[8*(dbg_reg_addr_i - 8'h30) +: 8];
        else if (dbg_reg_addr_i == 8'h39) dbg_reg_data_o = {4'd0, gc1_idx};
        else if (dbg_reg_addr_i == 8'h3A) dbg_reg_data_o = {6'd0, gc1_pos};
        else if (dbg_reg_addr_i == 8'h3B) dbg_reg_data_o = {6'd0, gc2_pos};
        else if (dbg_reg_addr_i >= 8'h40 && dbg_reg_addr_i <= 8'h4F)
            dbg_reg_data_o = {2'd0, pal_flat[6*dbg_reg_addr_i[3:0] +: 6]};
        else if (dbg_reg_addr_i == 8'h50) dbg_reg_data_o = {4'd0, amode};
        else if (dbg_reg_addr_i == 8'h51) dbg_reg_data_o = {2'd0, overscan};
        else if (dbg_reg_addr_i == 8'h52) dbg_reg_data_o = {2'd0, cpe};
        else if (dbg_reg_addr_i == 8'h53) dbg_reg_data_o = {4'd0, pan};
        else if (dbg_reg_addr_i == 8'h54) dbg_reg_data_o = {2'd0, attr_idx};
        else if (dbg_reg_addr_i == 8'h55) dbg_reg_data_o = {7'd0, attr_ff};
        else if (dbg_reg_addr_i == 8'h60) dbg_reg_data_o = misc;
        else if (dbg_reg_addr_i == 8'h61) dbg_reg_data_o = {6'd0, fcr};
        else if (dbg_reg_addr_i >= 8'h62 && dbg_reg_addr_i <= 8'h65)
            dbg_reg_data_o = lat[dbg_reg_addr_i[1:0] - 2'd2];
        else if (dbg_reg_addr_i == 8'h66) dbg_reg_data_o = {7'd0, lpff};
        else if (dbg_reg_addr_i == 8'h67) dbg_reg_data_o = {7'd0, vint};
        else if (dbg_reg_addr_i == 8'h68) dbg_reg_data_o = {3'd0, blink};
        else if (dbg_reg_addr_i >= 8'h70 && dbg_reg_addr_i <= 8'h78)
            dbg_reg_data_o = gc2_regs[8*(dbg_reg_addr_i - 8'h70) +: 8];
        else if (dbg_reg_addr_i == 8'h79) dbg_reg_data_o = {4'd0, gc2_idx};
    end
    assign dbg_mem_data_o = dbg_pdata[dbg_plane_i];
`ifdef FORMAL
    // Formal checks (formal/ibm_ega.sby): plane RAMs and ROM are black
    // boxes (their outputs are unconstrained), all slot and board inputs
    // are free.
    logic f_init = 1'b1;
    always_ff @(posedge clk) f_init <= 1'b0;
    always_comb if (f_init) assume (!rst_n);

    // ISA bus protocol (environment): one strobe at a time, address and AEN
    // stable while a strobe is low and in the clock after its release, and
    // no new strobe in the clock of a release.
    always_comb begin
        assume ($onehot0({!s_ior, !s_iow, !s_memr, !s_memw}));
        if (!s_ior || !s_iow || !s_memr || !s_memw || any_ev)
            assume (s_a == p_a && s_aen == p_aen);
        if (any_ev) assume (s_ior && s_iow && s_memr && s_memw);
    end

    logic [7:0] f_x;         // B0 or D0 by Misc Output bit 0
    logic       f_io_dec;     // U16 condition on the current address
    assign f_x = misc[0] ? 8'hD0 : 8'hB0;
    assign f_io_dec = !s_aen && s_a[9] && (s_p3 ? s_a[8] : !s_a[8]);

    always_comb begin
        if (rst_n && !f_init) begin
            // register access rules: only Input Status 0 (3C2), Input
            // Status 1 (3xA) and the CRTC data port (3x5) drive an I/O read
            if (d_oe_o && !s_ior)
                assert (f_io_dec && (s_a[7:0] == 8'hC2 || s_a[7:0] == (f_x | 8'h0A) ||
                                     s_a[7:0] == (f_x | 8'h05)));
            // memory reads drive only the ROM or the enabled RAM window
            if (d_oe_o && !s_memr && s_ior)
                assert (s_dack0 && (s_a[19:14] == 6'b110000 ||
                        (misc[1] && s_a[19:17] == 3'b101)));
            // nothing drives without a read strobe
            if (s_ior && s_memr) assert (!d_oe_o);
            // decode exclusivity: one I/O select at most; ROM and RAM disjoint
            assert ($onehot0({d_attr, d_c2, d_seq, d_gc2pos, d_gc1pos, d_gc, d_crtc,
                              d_xa, d_lpclr, d_lpset}));
            assert (!(d_rom && d_ram));
            // an I/O address never decodes as memory and vice versa:
            // I/O selects need A9 and !AEN; memory needs A19-A17 = 101/110
            // (both can be true only for different strobes)
            if (d_rom) assert (dec_a[19:14] == 6'b110000);
            // map-mask gating (TR p.21, p.23): a plane is written only on
            // a memory write event in the RAM window with its map mask bit
            // set and, in odd/even mode, the matching address parity
            for (int p = 0; p < 4; p++)
                if (plane_we[p]) begin
                    assert (memw_ev && d_ram && seq_regs[16 + p]);
                    if (!seq_regs[34]) assert (d_off[0] == ((p & 1) != 0));
                end
            // IRQ 2 driver enable follows VRE bit 5 (E9)
            assert (irq2_oe_o == !crtc_regs[8*8'h11 + 5]);
        end
    end

    always_ff @(posedge clk) begin
        if ($past(rst_n) && rst_n && !f_init && !$past(f_init)) begin
            // attribute address/data flip-flop (TR p.56-57)
            if ($past(ior_ev && d_xa))
                assert (!attr_ff);
            else if ($past(iow_ev && d_attr))
                assert (attr_ff == !$past(attr_ff));
            else
                assert (attr_ff == $past(attr_ff));
        end
    end

    // each processor write mode reaches the planes
    always_comb begin
        if (rst_n) begin
            cover (gc1_regs[41:40] == 2'd0 && plane_we[0]);
            cover (gc1_regs[41:40] == 2'd1 && plane_we[1]);
            cover (gc1_regs[41:40] == 2'd2 && plane_we[2]);
            cover (memw_ev && d_ram && gc1_regs[41:40] == 2'd3);
            cover (ior_ev && d_xa && attr_ff);
        end
    end
`endif
endmodule
