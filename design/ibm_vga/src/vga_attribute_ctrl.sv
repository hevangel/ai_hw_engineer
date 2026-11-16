// IBM VGA attribute controller (VGAXGA p.2-89 to 2-96, HITR p.76-89).
//
// Copied from ega_attribute_ctrl.sv and extended: readable registers
// (address at 3C0, data at 3C1), Color Select (index 14h), Attribute Mode
// bits 5 (panning compatibility), 6 (PEL width, 256 colours) and 7 (P5/P4
// select), an 8-bit overscan colour, and an 8-bit DAC address output
// instead of the EGA's 6-bit direct-drive colour. The blink counter is
// clocked by the start of vertical retrace (EGA E23).
module vga_attribute_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        we,             // 3C0 write event
    input  logic        ff_reset,       // Input Status 1 read event
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata_idx,      // 3C0 read
    output logic [7:0]  rdata,          // 3C1 read
    input  logic        dot_ce,
    input  logic        char_ce,
    input  logic [3:0]  dot_idx,
    input  logic [3:0]  w_now,
    input  logic        vrtc_start,
    input  logic        lc_hit,
    input  logic [7:0]  e_attr, n_attr,
    input  logic [2:0]  e_code_hi, n_code_hi,
    input  logic [7:0]  e_font, n_font,
    input  logic        e_gcg, n_gcg,
    input  logic        e_ul, n_ul,
    input  logic        e_cursor, n_cursor,
    input  logic [35:0] e_ser, n_ser,
    input  logic        de_in,
    input  logic        blank_in,
    input  logic        hs_in,
    input  logic        vs_in,
    input  logic        screen_off,     // Clocking Mode bit 5
    input  logic        hpol,
    input  logic        vpol,
    // to the DAC (combinational, sampled with dot_ce)
    output logic [7:0]  dac_addr,
    output logic        dac_blank,
    // registered dot outputs
    output logic        pix_en,
    output logic        hsync,
    output logic        vsync,
    output logic        blank,
    output logic        de,
    output logic        de_out,
    // registers
    output logic [5:0]  idx,
    output logic        ff,
    output logic [95:0] pal_flat,
    output logic [7:0]  mode,
    output logic [7:0]  overscan,
    output logic [5:0]  cpe,
    output logic [3:0]  pan,
    output logic [3:0]  colsel,
    output logic [4:0]  blink
);
    logic [5:0] pal [0:15];
    always_comb
        for (int i = 0; i < 16; i++) pal_flat[6*i +: 6] = pal[i];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 6'd0; ff <= 1'b0;
            mode <= 8'd0; overscan <= 8'd0; cpe <= 6'd0; pan <= 4'd0; colsel <= 4'd0;
            for (int i = 0; i < 16; i++) pal[i] <= 6'd0;
        end else if (ff_reset) begin
            ff <= 1'b0;                                       // p.2-89
        end else if (we) begin
            ff <= !ff;
            if (!ff) idx <= wdata[5:0];
            else begin
                if (idx[4] == 1'b0) begin
                    // EGA E27 / p.2-91: palette writes only while IPAS = 0
                    if (!idx[5]) pal[idx[3:0]] <= wdata[5:0];
                end else begin
                    unique case (idx[3:0])
                        4'h0: mode     <= wdata & 8'hEF;          // ASSUMPTION V7
                        4'h1: overscan <= wdata;
                        4'h2: cpe      <= wdata[5:0];
                        4'h3: pan      <= wdata[3:0];
                        4'h4: colsel   <= wdata[3:0];
                        default: ;
                    endcase
                end
            end
        end
    end

    // readback (ASSUMPTION V6: palette reads with IPAS = 1 return the
    // register; V7: reserved indices read 0)
    assign rdata_idx = {2'b00, idx};
    always_comb begin
        rdata = 8'h00;
        if (!idx[4]) rdata = {2'b00, pal[idx[3:0]]};
        else unique case (idx[3:0])
            4'h0: rdata = mode;
            4'h1: rdata = overscan;
            4'h2: rdata = {2'b00, cpe};
            4'h3: rdata = {4'd0, pan};
            4'h4: rdata = {4'd0, colsel};
            default: rdata = 8'h00;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) blink <= 5'd0;
        else if (vrtc_start) blink <= blink + 5'd1;
    end

    // p.2-92: panning compatibility forces panning to 0 from a line
    // compare match until the next vertical retrace
    logic pan_lc;
    always_ff @(posedge clk) begin
        if (!rst_n)                  pan_lc <= 1'b0;
        else if (vrtc_start)         pan_lc <= 1'b0;
        else if (lc_hit && mode[5])  pan_lc <= 1'b1;
    end

    // ---------------------------------------------- index formation
    logic blink_off;
    assign blink_off = blink[4];

    function automatic logic [35:0] form(input logic [7:0] attr, input logic [2:0] code_hi,
                                         input logic [7:0] font,
                                         input logic gcg, input logic ul, input logic cur,
                                         input logic [35:0] ser);
        logic [35:0] o;
        logic [7:0]  at;
        logic        g, lg;
        logic [3:0]  fg, bg;
        o = 36'd0;
        lg = (code_hi == 3'b110);                     // codes C0h-DFh
        for (int j = 0; j < 9; j++) begin
            at = {attr[7:4], gcg ? ser[4*j +: 4] : attr[3:0]};
            if (mode[0]) begin
                o[4*j +: 4] = at[3:0] | {mode[3] && blink_off, 3'b000};   // EGA E20
            end else begin
                if (j < 8) g = font[7-j];
                else       g = mode[2] && lg && font[0];
                fg = at[3:0];
                bg = mode[3] ? {1'b0, at[6:4]} : at[7:4];
                if (mode[1] && ul && ((at & 8'h77) == 8'h01)) g = 1'b1;   // EGA E22
                if (mode[3] && at[7] && blink_off) g = 1'b0;
                if (cur && !blink[3]) g = 1'b1;                           // EGA E23
                o[4*j +: 4] = g ? fg : bg;
            end
        end
        form = o;
    endfunction

    logic [35:0] cur_idx, nxt_idx, cur_new, nxt_new, cur_use, nxt_use;
    assign cur_new = form(e_attr, e_code_hi, e_font, e_gcg, e_ul, e_cursor, e_ser);
    assign nxt_new = form(n_attr, n_code_hi, n_font, n_gcg, n_ul, n_cursor, n_ser);
    assign cur_use = char_ce ? cur_new : cur_idx;
    assign nxt_use = char_ce ? nxt_new : nxt_idx;

    logic de_c, blank_c, hs_c, vs_c, blank_q, hs_q, vs_q;
    assign de_c    = char_ce ? de_in    : de_out;
    assign blank_c = char_ce ? blank_in : blank_q;
    assign hs_c    = char_ce ? hs_in    : hs_q;
    assign vs_c    = char_ce ? vs_in    : vs_q;

    // ------------------------------------------------------- per dot
    function automatic logic [3:0] at_pos(input logic [4:0] s, input logic [35:0] c,
                                          input logic [35:0] n, input logic [3:0] w);
        logic [3:0] sn;
        sn = s[3:0] - w;                  // s <= 17, w >= 8: modulo 16 exact
        if (s < {1'b0, w}) at_pos = c[4*s[3:0] +: 4];
        else               at_pos = n[4*sn +: 4];
    endfunction

    logic [3:0] pv;
    logic [4:0] sh, s, s0, s1;
    logic [3:0] i0, i1;
    logic [5:0] p0;
    logic [3:0] p1;
    always_comb begin
        pv = pan_lc ? 4'd0 : pan;
        if (w_now == 4'd9) sh = (pv >= 4'd8) ? 5'd0 : {1'b0, pv} + 5'd1;   // Figure 2-88, EGA E24
        else               sh = {2'b00, pv[2:0]};
        s  = {1'b0, dot_idx} + sh;
        s0 = mode[6] ? {s[4:1], 1'b0} : s;
        s1 = {s[4:1], 1'b1};
        i0 = at_pos(s0, cur_use, nxt_use, w_now) & cpe[3:0];
        i1 = at_pos(s1, cur_use, nxt_use, w_now) & cpe[3:0];
        p0 = pal[i0];
        p1 = pal[i1][3:0];
        dac_blank = blank_c || screen_off;                    // p.2-49
        if (!de_c || !idx[5])  dac_addr = overscan;           // EGA E27
        else if (mode[6])      dac_addr = {p0[3:0], p1}; // ASSUMPTION V18
        else                   dac_addr = {colsel[3:2], mode[7] ? colsel[1:0] : p0[5:4], p0[3:0]};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cur_idx <= '0; nxt_idx <= '0;
            de_out <= 1'b0; blank_q <= 1'b0; hs_q <= 1'b0; vs_q <= 1'b0;
            pix_en <= 1'b0; hsync <= 1'b0; vsync <= 1'b0; blank <= 1'b0; de <= 1'b0;
        end else begin
            pix_en <= dot_ce;
            if (char_ce) begin
                cur_idx <= cur_new;
                nxt_idx <= nxt_new;
                de_out  <= de_in;
                blank_q <= blank_in;
                hs_q    <= hs_in;
                vs_q    <= vs_in;
            end
            if (dot_ce) begin
                hsync <= hs_c ^ hpol;
                vsync <= vs_c ^ vpol;
                blank <= dac_blank;
                de    <= de_c;
            end
        end
    end
endmodule
