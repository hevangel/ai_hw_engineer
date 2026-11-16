// IBM Personal System/2 Display Adapter (1987): the VGA function, 256 KB
// of video memory, an IMS G171-compatible video DAC and the adapter BIOS
// ROM, as an 8-bit ISA slot device with an analog display interface.
//
// Sources: IBM PS/2 Hardware Interface Technical Reference (May 1988),
// "Video Subsystem (Type 1)", and the IBM VGA/XGA Technical Reference
// (May 1992); see spec/spec.md for the interface, register map and the
// assumption ledger (ASSUMPTION Vn tags below). The slot side and the bus
// contract are those of ibm_ega (design/ibm_ega).
//
// One clock domain `clk`. Every input is sampled on `clk`; the dot clock
// sources are clock-enable inputs. `rst_n` is the simulation/FPGA power-on
// reset; `reset_drv_i` is the slot RESET DRV.
module ibm_vga #(
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
    // oscillators (clock enables)
    input  logic        osc25_ce_i,
    input  logic        osc28_ce_i,
    input  logic        ext_osc_ce_i,
    // display connector
    input  logic [2:0]  load_i,
    output logic        pix_en_o,
    output logic [5:0]  r_o,
    output logic [5:0]  g_o,
    output logic [5:0]  b_o,
    output logic        hsync_o,
    output logic        vsync_o,
    output logic        blank_o,
    output logic        de_o,
    // simulation-only debug reads (no side effects)
    input  logic [7:0]  dbg_reg_addr_i,
    output logic [7:0]  dbg_reg_data_o,
    input  logic [1:0]  dbg_plane_i,
    input  logic [15:0] dbg_mem_addr_i,
    output logic [7:0]  dbg_mem_data_o,
    input  logic [7:0]  dbg_dac_i,
    output logic [17:0] dbg_dac_o
);
    // ------------------------------------------------------ input sampling
    logic [19:0] s_a, p_a;
    logic [7:0]  s_d, p_d;
    logic        s_ior, s_iow, s_memr, s_memw, s_aen, s_dack0, s_rst;
    logic        p_ior, p_iow, p_memr, p_memw, p_aen;
    logic        s_osc25, s_osc28, s_ext;
    logic [2:0]  s_load;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s_a <= '0; s_d <= '0; p_a <= '0; p_d <= '0;
            s_ior <= 1'b1; s_iow <= 1'b1; s_memr <= 1'b1; s_memw <= 1'b1;
            p_ior <= 1'b1; p_iow <= 1'b1; p_memr <= 1'b1; p_memw <= 1'b1;
            s_aen <= 1'b0; p_aen <= 1'b0; s_dack0 <= 1'b1; s_rst <= 1'b0;
            s_osc25 <= 1'b0; s_osc28 <= 1'b0; s_ext <= 1'b0; s_load <= 3'b111;
        end else begin
            s_a <= a_i; s_d <= d_i; s_aen <= aen_i;
            s_ior <= ior_n_i; s_iow <= iow_n_i; s_memr <= memr_n_i; s_memw <= memw_n_i;
            s_dack0 <= dack0_n_i; s_rst <= reset_drv_i;
            p_a <= s_a; p_d <= s_d; p_aen <= s_aen;
            p_ior <= s_ior; p_iow <= s_iow; p_memr <= s_memr; p_memw <= s_memw;
            s_osc25 <= osc25_ce_i; s_osc28 <= osc28_ce_i; s_ext <= ext_osc_ce_i;
            s_load <= load_i;
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
    logic [7:0]  misc, fcr, vse, isr0;
    logic        pos, enable, setup, master_ce, sense, vint;
    logic [71:0] gc_regs;
    logic        gc_graphics, gc_chain;
    logic [1:0]  gc_mem_map;
    assign gc_graphics = gc_regs[48];
    assign gc_chain    = gc_regs[49];
    assign gc_mem_map  = gc_regs[51:50];

    // ----------------------------------------------------------- decode
    logic        any_ev;
    logic [19:0] dec_a;
    logic        dec_aen;
    logic d_attr, d_attr_rd, d_c2, d_seq, d_pelmask, d_dac_ra, d_dac_wa, d_dac_data;
    logic d_fcr_rd, d_misc_rd, d_gc, d_crtc, d_xa, d_vse, d_pos, d_rom, d_ram;
    logic [16:0] d_off;
    assign any_ev  = iow_ev || ior_ev || memw_ev || memr_ev;
    assign dec_a   = any_ev ? p_a : s_a;
    assign dec_aen = any_ev ? p_aen : s_aen;

    vga_io_decode u_dec (
        .a(dec_a), .aen(dec_aen), .enable, .setup, .mono_n(misc[0]), .dack0_n(s_dack0),
        .ram_en(misc[1]), .mem_map(gc_mem_map),
        .io_attr(d_attr), .io_attr_rd(d_attr_rd), .io_c2(d_c2), .io_seq(d_seq),
        .io_pelmask(d_pelmask), .io_dac_ra(d_dac_ra), .io_dac_wa(d_dac_wa),
        .io_dac_data(d_dac_data), .io_fcr_rd(d_fcr_rd), .io_misc_rd(d_misc_rd),
        .io_gc(d_gc), .io_crtc(d_crtc), .io_xa(d_xa), .io_vse(d_vse), .io_pos(d_pos),
        .mem_rom(d_rom), .mem_ram(d_ram), .ram_off(d_off));

    // ------------------------------------------- general / card registers
    vga_general_regs u_gen (
        .clk, .rst_n, .reset_drv(s_rst),
        .misc_we(iow_ev && d_c2), .fcr_we(iow_ev && d_xa),
        .vse_we(iow_ev && d_vse), .pos_we(iow_ev && d_pos),
        .wdata(p_d), .osc25_ce(s_osc25), .osc28_ce(s_osc28), .ext_osc_ce(s_ext),
        .vint, .sense, .misc, .fcr, .vse, .pos, .enable, .setup, .master_ce, .isr0);

    // ---------------------------------------------------------- sequencer
    logic        dot_ce, char_ce, ext_mem, shift_load, screen_off, w8, fattr_b3;
    logic        chain4;
    logic [1:0]  chain4_map;
    logic [3:0]  dot_idx, char_w;
    logic [2:0]  seq_idx;
    logic [15:0] cpu_paddr;
    logic [2:0]  font_tbl;
    logic [3:0]  plane_we_mask;
    logic [39:0] seq_regs;
    logic [7:0]  seq_ri, seq_rd;

    vga_sequencer u_seq (
        .clk, .rst_n,
        .addr_we(iow_ev && d_seq && !p_a[0]), .data_we(iow_ev && d_seq && p_a[0]),
        .wdata(p_d), .rdata_idx(seq_ri), .rdata(seq_rd), .master_ce,
        .dot_ce, .char_ce, .dot_idx, .char_w,
        .cpu_off(d_off), .map128(gc_mem_map == 2'b00), .chain(gc_chain), .page(misc[5]),
        .cpu_paddr, .plane_we_mask, .chain4, .chain4_map,
        .attr_b3(fattr_b3), .font_tbl, .ext_mem, .shift_load, .screen_off, .w8,
        .dbg_regs(seq_regs), .idx(seq_idx));

    // --------------------------------------------------------------- CRTC
    logic        f_de, f_blank, f_hs, f_cursor, f_ul, f_hcodd, vs_line, vrtc_start, lc_hit;
    logic [15:0] crtc_addr;
    logic [4:0]  rs, crtc_idx;
    logic [1:0]  de_skew, cur_skew, hr_delay;
    logic        retrace_en;
    logic [7:0]  crtc_ri, crtc_rd;
    logic [199:0] crtc_regs;

    vga_crtc u_crtc (
        .clk, .rst_n, .reset_drv(s_rst),
        .addr_we(iow_ev && d_crtc && !p_a[0]), .data_we(iow_ev && d_crtc && p_a[0]),
        .wdata(p_d), .rdata_idx(crtc_ri), .rdata(crtc_rd),
        .char_ce, .f_de, .f_blank, .f_hs, .f_cursor, .f_ul, .f_hcodd, .vs_line,
        .disp_addr(crtc_addr), .rs, .vint, .vrtc_start, .lc_hit,
        .de_skew, .cur_skew, .hr_delay, .retrace_en,
        .dbg_regs(crtc_regs), .idx(crtc_idx));

    // ------------------------------------------------------- video memory
    logic [31:0] a_rdata, b_rdata, wd;
    logic [15:0] b_addr;
    logic [7:0]  dbg_pdata [0:3];
    logic [3:0]  plane_we;

    for (genvar p = 0; p < 4; p++) begin : g_plane
        logic [7:0] a_q, b_q;
        assign plane_we[p] = memw_ev && d_ram && plane_we_mask[p];
        vga_plane_ram u_ram (
            .clk, .a_addr(cpu_paddr), .a_we(plane_we[p]),
            .a_wdata(wd[8*p +: 8]), .a_rdata(a_q),
            .b_addr, .b_rdata(b_q),
            .dbg_addr(dbg_mem_addr_i), .dbg_rdata(dbg_pdata[p]));
        assign a_rdata[8*p +: 8] = a_q;
        assign b_rdata[8*p +: 8] = b_q;
    end

    // --------------------------------------------------- display fetch
    logic [7:1]  h_de, h_blank, h_hs, h_cursor;
    logic [31:0] n_p, e_p, e2_p;
    logic [7:0]  n_font, e_font, e2_font;
    logic        n_gcg, e_gcg, e2_gcg, n_odd, e_odd, e2_odd, n_ul, e_ul, e2_ul;

    vga_display_fetch u_fetch (
        .clk, .rst_n, .char_ce,
        .f_de, .f_blank, .f_hs, .f_cursor, .f_ul, .f_hcodd,
        .crtc_addr, .rs, .ext_mem, .gc_graphics, .font_tbl, .fattr_b3,
        .b_addr, .b_rdata, .h_de, .h_blank, .h_hs, .h_cursor,
        .n_p, .e_p, .e2_p, .n_font, .e_font, .e2_font, .n_gcg, .e_gcg, .e2_gcg,
        .n_odd, .e_odd, .e2_odd, .n_ul, .e_ul, .e2_ul);

    // ASSUMPTION V14: pipeline depths (characters): graphics data 2, DE
    // 2 + skew, blank 3, cursor 2 + skew; alphanumeric one more each;
    // horizontal retrace = its delay; vertical retrace 0.
    logic        text;
    logic [2:0]  base, d_de, d_bl, d_ce, d_cn;
    logic [31:0] c_p, x_p;
    logic [7:0]  c_font, x_font;
    logic        c_gcg, x_gcg, c_odd, x_odd, c_ul, x_ul;
    logic        de_in, blank_in, hs_in, c_cur, x_cur;
    assign text = !gc_graphics;
    always_comb begin
        base = text ? 3'd3 : 3'd2;
        d_de = base + {1'b0, de_skew};
        d_bl = base + 3'd1;
        d_ce = base + {1'b0, cur_skew};
        d_cn = d_ce - 3'd1;
        de_in    = h_de[d_de];
        blank_in = h_blank[d_bl];
        c_cur    = h_cursor[d_ce];
        x_cur    = h_cursor[d_cn];
        hs_in    = (hr_delay == 2'd0) ? f_hs : h_hs[{1'b0, hr_delay}];
        if (text) begin
            c_p = e2_p; c_font = e2_font; c_gcg = e2_gcg; c_odd = e2_odd; c_ul = e2_ul;
            x_p = e_p;  x_font = e_font;  x_gcg = e_gcg;  x_odd = e_odd;  x_ul = e_ul;
        end else begin
            c_p = e_p;  c_font = e_font;  c_gcg = e_gcg;  c_odd = e_odd;  c_ul = e_ul;
            x_p = n_p;  x_font = n_font;  x_gcg = n_gcg;  x_odd = n_odd;  x_ul = n_ul;
        end
    end

    // ------------------------------------------------ graphics controller
    logic [7:0]  gc_rd, gc_ri, gc_rr;
    logic [35:0] e_ser, n_ser;
    logic [3:0]  gc_idx;
    logic [31:0] lat;

    vga_graphics_ctrl u_gc (
        .clk, .rst_n,
        .addr_we(iow_ev && d_gc && !p_a[0]), .data_we(iow_ev && d_gc && p_a[0]),
        .wdata(p_d), .rdata_idx(gc_ri), .rdata(gc_rr),
        .cpu_d(p_d), .wd, .rd(a_rdata), .a0(d_off[0]), .chain4, .chain4_map,
        .latch_we(memr_ev && d_ram), .rd_data(gc_rd),
        .shift_load, .e_p(c_p), .n_p(x_p), .e_odd(c_odd), .n_odd(x_odd),
        .e_ser, .n_ser, .dbg_regs(gc_regs), .idx(gc_idx), .lat);

    // ------------------------------------------------- attribute controller
    logic [5:0]  attr_idx, cpe;
    logic        attr_ff, de_out, dac_blank;
    logic [95:0] pal_flat;
    logic [7:0]  amode, overscan, attr_ri, attr_rd, dac_addr;
    logic [5:0]  last_pix;
    logic [3:0]  pan, colsel, w_now;
    logic [4:0]  blink;
    assign w_now = char_ce ? (w8 ? 4'd8 : 4'd9) : char_w;

    vga_attribute_ctrl u_attr (
        .clk, .rst_n,
        .we(iow_ev && d_attr), .ff_reset(ior_ev && d_xa), .wdata(p_d),
        .rdata_idx(attr_ri), .rdata(attr_rd),
        .dot_ce, .char_ce, .dot_idx, .w_now, .vrtc_start, .lc_hit,
        .e_attr(c_p[15:8]), .n_attr(x_p[15:8]),
        .e_code_hi(c_p[7:5]), .n_code_hi(x_p[7:5]),
        .e_font(c_font), .n_font(x_font), .e_gcg(c_gcg), .n_gcg(x_gcg),
        .e_ul(c_ul), .n_ul(x_ul), .e_cursor(c_cur), .n_cursor(x_cur),
        .e_ser, .n_ser,
        .de_in, .blank_in, .hs_in(hs_in && retrace_en), .vs_in(vs_line && retrace_en),
        .screen_off, .hpol(misc[6]), .vpol(misc[7]),
        .dac_addr, .dac_blank,
        .pix_en(pix_en_o), .hsync(hsync_o), .vsync(vsync_o), .blank(blank_o), .de(de_o),
        .de_out, .last_pix, .idx(attr_idx), .ff(attr_ff), .pal_flat, .mode(amode), .overscan, .cpe,
        .pan, .colsel, .blink);

    // ------------------------------------------------------------- DAC
    logic [7:0]  dac_rd, dac_ra, dac_st, pelmask, dac_a;
    logic [1:0]  dac_sub;
    logic        dac_rmode;
    logic [5:0]  hold_r, hold_g;

    vga_dac u_dac (
        .clk, .rst_n,
        .pelmask_we(iow_ev && d_pelmask), .ra_we(iow_ev && d_dac_ra),
        .wa_we(iow_ev && d_dac_wa), .data_we(iow_ev && d_dac_data),
        .data_re(ior_ev && d_dac_data), .wdata(p_d),
        .rd_data(dac_rd), .rd_addr(dac_ra), .rd_state(dac_st), .pelmask,
        .dot_ce, .pix_addr(dac_addr), .pix_blank(dac_blank), .load(s_load),
        .r(r_o), .g(g_o), .b(b_o), .sense,
        .dbg_addr(dbg_dac_i), .dbg_rgb(dbg_dac_o),
        .addr(dac_a), .sub(dac_sub), .rmode(dac_rmode), .hold_r, .hold_g);

    // --------------------------------------------------------- slot outputs
    // ASSUMPTION V16: the EGA's video status multiplexer (EGA TR p.17/p.60,
    // EGA E11) on Input Status 1 bits 5-4, selected by Color Plane Enable
    // bits 5-4: 00 {P2,P0}, 01 {P3,P1}, 10 {P5,P4}, 11 none. HITR calls the
    // bits reserved; the POST (C000:0270-029B) needs settings 00-10.
    logic [1:0] diag;
    always_comb begin
        unique case (cpe[5:4])
            2'b00: diag = {last_pix[2], last_pix[0]};
            2'b01: diag = {last_pix[3], last_pix[1]};
            2'b10: diag = {last_pix[5], last_pix[4]};
            2'b11: diag = 2'b00;
        endcase
    end
    logic [7:0] isr1;
    // p.2-45: bit 3 vertical retrace, bit 0 = 1 while display enable is off
    assign isr1 = {2'b00, diag, vs_line, 2'b00, !de_out};

    logic io_rd, mem_rd;
    assign io_rd  = !s_ior && (d_attr || d_attr_rd || d_c2 || d_seq || d_pelmask ||
                               d_dac_ra || d_dac_wa || d_dac_data || d_fcr_rd ||
                               d_misc_rd || d_gc || d_crtc || d_xa || d_pos);
    assign mem_rd = !s_memr && (d_rom || d_ram);

    logic [7:0] rom_rdata;
    vga_rom #(.ROM_FILE(ROM_FILE)) u_rom (.clk, .addr(s_a[14:0]), .rdata(rom_rdata));

    always_comb begin
        d_oe_o = io_rd || mem_rd;
        d_o = 8'h00;
        if (!s_ior) begin
            if (d_attr)          d_o = attr_ri;
            else if (d_attr_rd)  d_o = attr_rd;
            else if (d_c2)       d_o = isr0;
            else if (d_seq)      d_o = s_a[0] ? seq_rd : seq_ri;
            else if (d_pelmask)  d_o = pelmask;
            else if (d_dac_ra)   d_o = dac_st;
            else if (d_dac_wa)   d_o = dac_ra;
            else if (d_dac_data) d_o = dac_rd;
            else if (d_fcr_rd)   d_o = fcr;
            else if (d_misc_rd)  d_o = misc;
            else if (d_gc)       d_o = s_a[0] ? gc_rr : gc_ri;
            else if (d_crtc)     d_o = s_a[0] ? crtc_rd : crtc_ri;
            else if (d_xa)       d_o = isr1;
            else if (d_pos)      d_o = {7'd0, pos};
        end else if (d_rom) begin
            d_o = rom_rdata;
        end else begin
            d_o = gc_rd;
        end
    end

    assign irq2_o       = vint;                    // EGA E9
    assign irq2_oe_o    = !crtc_regs[8*8'h11 + 5];
    assign iochrdy_o    = 1'b1;                    // ASSUMPTION V24
    assign iochrdy_oe_o = 1'b0;

    // ------------------------------------------------------ debug reads
    always_comb begin
        dbg_reg_data_o = 8'hFF;
        if (dbg_reg_addr_i <= 8'h04)
            dbg_reg_data_o = seq_regs[8*dbg_reg_addr_i[2:0] +: 8];
        else if (dbg_reg_addr_i == 8'h05) dbg_reg_data_o = {5'd0, seq_idx};
        else if (dbg_reg_addr_i >= 8'h10 && dbg_reg_addr_i <= 8'h28)
            dbg_reg_data_o = crtc_regs[8*(dbg_reg_addr_i - 8'h10) +: 8];
        else if (dbg_reg_addr_i == 8'h29) dbg_reg_data_o = {3'd0, crtc_idx};
        else if (dbg_reg_addr_i >= 8'h30 && dbg_reg_addr_i <= 8'h38)
            dbg_reg_data_o = gc_regs[8*(dbg_reg_addr_i - 8'h30) +: 8];
        else if (dbg_reg_addr_i == 8'h39) dbg_reg_data_o = {4'd0, gc_idx};
        else if (dbg_reg_addr_i >= 8'h40 && dbg_reg_addr_i <= 8'h4F)
            dbg_reg_data_o = {2'd0, pal_flat[6*dbg_reg_addr_i[3:0] +: 6]};
        else if (dbg_reg_addr_i == 8'h50) dbg_reg_data_o = amode;
        else if (dbg_reg_addr_i == 8'h51) dbg_reg_data_o = overscan;
        else if (dbg_reg_addr_i == 8'h52) dbg_reg_data_o = {2'd0, cpe};
        else if (dbg_reg_addr_i == 8'h53) dbg_reg_data_o = {4'd0, pan};
        else if (dbg_reg_addr_i == 8'h54) dbg_reg_data_o = {4'd0, colsel};
        else if (dbg_reg_addr_i == 8'h55) dbg_reg_data_o = {2'd0, attr_idx};
        else if (dbg_reg_addr_i == 8'h56) dbg_reg_data_o = {7'd0, attr_ff};
        else if (dbg_reg_addr_i == 8'h60) dbg_reg_data_o = misc;
        else if (dbg_reg_addr_i == 8'h61) dbg_reg_data_o = fcr;
        else if (dbg_reg_addr_i >= 8'h62 && dbg_reg_addr_i <= 8'h65)
            dbg_reg_data_o = lat[8*{30'd0, dbg_reg_addr_i[1:0] + 2'd2} +: 8];
        else if (dbg_reg_addr_i == 8'h67) dbg_reg_data_o = {7'd0, vint};
        else if (dbg_reg_addr_i == 8'h68) dbg_reg_data_o = {3'd0, blink};
        else if (dbg_reg_addr_i == 8'h69) dbg_reg_data_o = vse;
        else if (dbg_reg_addr_i == 8'h6A) dbg_reg_data_o = {7'd0, pos};
        else if (dbg_reg_addr_i == 8'h70) dbg_reg_data_o = pelmask;
        else if (dbg_reg_addr_i == 8'h71) dbg_reg_data_o = dac_a;
        else if (dbg_reg_addr_i == 8'h72) dbg_reg_data_o = {6'd0, dac_sub};
        else if (dbg_reg_addr_i == 8'h73) dbg_reg_data_o = {7'd0, dac_rmode};
        else if (dbg_reg_addr_i == 8'h74) dbg_reg_data_o = {2'd0, hold_r};
        else if (dbg_reg_addr_i == 8'h75) dbg_reg_data_o = {2'd0, hold_g};
        else if (dbg_reg_addr_i == 8'h76) dbg_reg_data_o = {7'd0, sense};
    end
    assign dbg_mem_data_o = dbg_pdata[dbg_plane_i];
`ifdef FORMAL
    // Formal checks (formal/ibm_vga.sby): plane RAMs and ROM are black
    // boxes, the DAC palette is one shadow entry, all slot inputs are free.
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

    logic [7:0] f_x, f_lo;
    logic       f_io3;
    assign f_x   = misc[0] ? 8'hD0 : 8'hB0;
    assign f_lo  = s_a[7:0];
    assign f_io3 = !s_aen && s_a[9:8] == 2'b11;

    always_comb begin
        if (rst_n && !f_init) begin
            // an I/O read drives only a readable port of the enabled card,
            // or POS 102h in setup
            if (d_oe_o && !s_ior) begin
                assert ((enable && f_io3 &&
                         (f_lo == 8'hC0 || f_lo == 8'hC1 || f_lo == 8'hC2 || f_lo == 8'hC4 ||
                          f_lo == 8'hC5 || f_lo == 8'hCA || f_lo == 8'hCC || f_lo == 8'hCE ||
                          f_lo == 8'hCF || f_lo == (f_x | 8'h04) || f_lo == (f_x | 8'h05) ||
                          f_lo == (f_x | 8'h0A) ||
                          (!setup && f_lo >= 8'hC6 && f_lo <= 8'hC9))) ||
                        (setup && !s_aen && s_a[15:0] == 16'h0102));
                // 3C3 and 46E8h are never read (ASSUMPTION V4/V5)
                assert (s_a[15:0] != 16'h46E8 && !(f_io3 && f_lo == 8'hC3));
            end
            // memory reads drive only the ROM, or the RAM of an enabled card
            if (d_oe_o && !s_memr && s_ior)
                assert (s_dack0 && (s_a[19:15] == 5'b11000 ||
                        (enable && misc[1] && s_a[19:17] == 3'b101)));
            if (s_ior && s_memr) assert (!d_oe_o);
            // a disabled card decodes no 3xx port and no RAM
            if (!enable)
                assert (!(d_attr || d_attr_rd || d_c2 || d_seq || d_pelmask || d_dac_ra ||
                          d_dac_wa || d_dac_data || d_fcr_rd || d_misc_rd || d_gc ||
                          d_crtc || d_xa || d_ram));
            // in setup the DAC is not decoded (HITR p.10)
            if (setup) assert (!(d_pelmask || d_dac_ra || d_dac_wa || d_dac_data));
            assert ($onehot0({d_attr, d_attr_rd, d_c2, d_seq, d_pelmask, d_dac_ra, d_dac_wa,
                              d_dac_data, d_fcr_rd, d_misc_rd, d_gc, d_crtc, d_xa, d_vse,
                              d_pos}));
            assert (!(d_rom && d_ram));
            // map-mask / chain-4 / odd-even write gating (p.2-51, p.2-54)
            for (int p = 0; p < 4; p++)
                if (plane_we[p]) begin
                    assert (memw_ev && d_ram && seq_regs[16 + p]);
                    if (seq_regs[35]) assert (d_off[1:0] == 2'(p));
                    else if (!seq_regs[34]) assert (d_off[0] == ((p & 1) != 0));
                end
            assert (irq2_oe_o == !crtc_regs[8*8'h11 + 5]);
            assert (enable == (vse[3] && pos));
        end
    end

    always_ff @(posedge clk) begin
        if ($past(rst_n) && rst_n && !f_init && !$past(f_init)) begin
            // attribute address/data flip-flop (p.2-89)
            if ($past(ior_ev && d_xa))        assert (!attr_ff);
            else if ($past(iow_ev && d_attr)) assert (attr_ff == !$past(attr_ff));
            else                              assert (attr_ff == $past(attr_ff));
            // RESET DRV disables the card (ASSUMPTION V2)
            if ($past(s_rst)) assert (!enable && misc == 8'h00);
        end
    end

    always_comb begin
        if (rst_n) begin
            cover (enable && memw_ev && d_ram && plane_we == 4'b0100 && seq_regs[35]);
            cover (enable && ior_ev && d_dac_data);
            cover (ior_ev && d_xa && attr_ff);
            cover (setup && iow_ev && d_pos);
        end
    end
`endif
endmodule
