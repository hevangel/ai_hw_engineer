// IBM EGA attribute controller LSI (U24, TR p.56-61, sheet 8).
//
// Registers: address (with the address/data flip-flop and the palette
// address source bit), 16 palette registers, Mode Control, Overscan Color,
// Color Plane Enable, Horizontal Pel Panning. Turns a fetched character
// (text: glyph byte + attribute; graphics: serialized C0-C3) into palette
// indices, applies panning, plane enable, palette, border and blanking, and
// produces one registered 6-bit dot per dot clock. Also holds the blink
// counter (clocked by the start of vertical retrace, VRTC pin).
module ega_attribute_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    // processor
    input  logic        we,             // 3C0 write event
    input  logic        ff_reset,       // Input Status 1 read event
    input  logic [5:0]  wdata,          // bits 7-6 not used (TR p.56-61)
    // timing
    input  logic        dot_ce,
    input  logic        char_ce,
    input  logic [3:0]  dot_idx,
    input  logic [3:0]  w_now,          // 8 or 9 for this character
    input  logic        vrtc_start,
    // character data, E = displayed, N = next (for panning)
    input  logic [7:0]  e_attr, n_attr,       // plane 1 byte
    input  logic [2:0]  e_code_hi, n_code_hi, // plane 0 bits 7-5 (line graphics)
    input  logic [7:0]  e_font, n_font,
    input  logic        e_gcg, n_gcg,
    input  logic        e_ul, n_ul,
    input  logic        e_cursor, n_cursor,
    input  logic [35:0] e_ser, n_ser,   // dot j: [4j+3:4j] = C3..C0
    // CRTC flags for this character (already delayed, ASSUMPTION E18)
    input  logic        de_in,
    input  logic        blank_in,
    input  logic        hs_in,
    input  logic        vs_in,
    // board
    input  logic        hpol,           // Misc Output bit 6
    input  logic        vpol,           // Misc Output bit 7
    input  logic        drivers_off,    // Misc Output bit 4
    input  logic        p1,
    // outputs
    output logic        pix_en,
    output logic [5:0]  video,
    output logic        hsync,
    output logic        vsync,
    output logic        blank,
    output logic        de,
    output logic        video_oe,
    output logic [5:0]  last_color,
    output logic        de_out,         // display enable of this character
    // registers
    output logic [5:0]  idx,
    output logic        ff,
    output logic [95:0] pal_flat,       // palette 15..0, 6 bits each
    output logic [3:0]  mode,
    output logic [5:0]  overscan,
    output logic [5:0]  cpe,
    output logic [3:0]  pan,
    output logic [4:0]  blink
);
    logic [5:0] pal [0:15];
    always_comb
        for (int i = 0; i < 16; i++) pal_flat[6*i +: 6] = pal[i];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 6'd0; ff <= 1'b0;
            mode <= 4'd0; overscan <= 6'd0; cpe <= 6'd0; pan <= 4'd0;
            for (int i = 0; i < 16; i++) pal[i] <= 6'd0;
        end else if (ff_reset) begin
            ff <= 1'b0;                              // TR p.56
        end else if (we) begin
            ff <= !ff;
            if (!ff) idx <= wdata[5:0];
            else begin
                if (idx[4] == 1'b0) begin
                    // ASSUMPTION E27: palette loads only while bit 5 = 0
                    if (!idx[5]) pal[idx[3:0]] <= wdata[5:0];
                end else begin
                    unique case (idx[3:0])
                        4'h0: mode     <= wdata[3:0];
                        4'h1: overscan <= wdata[5:0];
                        4'h2: cpe      <= wdata[5:0];
                        4'h3: pan      <= wdata[3:0];
                        default: ;
                    endcase
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) blink <= 5'd0;
        else if (vrtc_start) blink <= blink + 5'd1;
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
                o[4*j +: 4] = at[3:0] | {mode[3] && blink_off, 3'b000};   // ASSUMPTION E20
            end else begin
                if (j < 8) g = font[7-j];
                else       g = mode[2] && lg && font[0];
                fg = at[3:0];
                bg = mode[3] ? {1'b0, at[6:4]} : at[7:4];
                if (mode[1] && ul && ((at & 8'h77) == 8'h01)) g = 1'b1;   // E22
                if (mode[3] && at[7] && blink_off) g = 1'b0;
                if (cur && !blink[3]) g = 1'b1;                           // E23
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

    logic de_c, blank_c, hs_c, vs_c;
    assign de_c    = char_ce ? de_in    : de_out;
    logic blank_q, hs_q, vs_q;
    assign blank_c = char_ce ? blank_in : blank_q;
    assign hs_c    = char_ce ? hs_in    : hs_q;
    assign vs_c    = char_ce ? vs_in    : vs_q;

    // ------------------------------------------------------- per dot
    logic [4:0] sh, s;
    logic [3:0] sn;
    logic [3:0] pidx;
    logic [5:0] col;
    always_comb begin
        if (w_now == 4'd9) sh = (pan >= 4'd8) ? 5'd0 : {1'b0, pan} + 5'd1;   // TR p.61, E24
        else               sh = {2'b00, pan[2:0]};
        s  = {1'b0, dot_idx} + sh;
        sn = s[3:0] - w_now;              // s <= 16: modulo 16 is exact
        if (s < {1'b0, w_now}) pidx = cur_use[4*s[3:0] +: 4];
        else                   pidx = nxt_use[4*sn +: 4];
        pidx = pidx & cpe[3:0];
        if (blank_c)                 col = 6'd0;
        else if (!de_c || !idx[5])   col = overscan;                         // E27
        else                         col = pal[pidx];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cur_idx <= '0; nxt_idx <= '0;
            de_out <= 1'b0; blank_q <= 1'b0; hs_q <= 1'b0; vs_q <= 1'b0;
            pix_en <= 1'b0; video <= '0; hsync <= 1'b0; vsync <= 1'b0;
            blank <= 1'b0; de <= 1'b0; video_oe <= 1'b0; last_color <= '0;
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
                last_color <= col;
                video    <= p1 ? col : {1'b0, col[4:0]};
                hsync    <= hs_c ^ hpol;
                vsync    <= vs_c ^ vpol;
                blank    <= blank_c;
                de       <= de_c;
                video_oe <= !drivers_off;
            end
        end
    end
endmodule
