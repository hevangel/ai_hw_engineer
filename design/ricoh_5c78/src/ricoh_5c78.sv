// Ricoh 5C78 (S-PPU2): SNES picture processor, second half. Generates the
// video timing, owns CGRAM, windows, layer priority, colour math, master
// brightness and the H/V counter latches, and composes the line that S-PPU1
// rendered on the previous line. See spec/spec.md.
module ricoh_5c78 #(
    parameter bit PAL = 1'b0
) (
    input  logic clk,
    input  logic rst_n,
    // B bus.
    input  logic [7:0] b_addr,
    input  logic b_rd, b_wr, bus_ce,
    input  logic [7:0] b_data_i,
    output logic [7:0] rdata,
    output logic hit,
    input  logic [7:0] cpu_mdr,      // CPU open bus (for $2137)
    input  logic wrio7,              // 5A22 WRIO bit 7 (counter latch)
    input  logic ext_latch,          // light-gun latch input
    // Timing to S-PPU1 and the board.
    output logic line_start,
    output logic [8:0] line,
    output logic [10:0] hcount,
    output logic vblank,
    output logic field,
    output logic interlace_o, overscan_o,
    // S-PPU1 layer port.
    output logic [9:0] px_x,
    output logic px_bank,
    input  logic [47:0] bg_px,
    input  logic [8:0] obj_px,
    input  logic [7:0] bgmode,
    input  logic hires_mode,
    // Video out: one pixel per strobe, row 0 is display line 1.
    output logic pix_valid,
    output logic [9:0] pix_x,        // 0-255, or 0-511 when pix_hires
    output logic [8:0] pix_y,
    output logic [14:0] pix_rgb,     // BGR555
    output logic pix_hires,
    output logic frame_o             // pulse at the start of each frame
);
    // Register bits the hardware ignores and wide arithmetic temporaries
    // whose upper bits are deliberately dropped.
    /* verilator lint_off UNUSEDSIGNAL */
    // ---------------- Video timing ----------------
    logic [10:0] hcnt;
    logic [8:0] vcnt;
    logic [7:0] setini, inidisp;
    wire interlace = setini[0];
    wire overscan = setini[2];
    wire [8:0] vdisp = overscan ? 9'd239 : 9'd224;
    logic [10:0] line_len;
    logic [8:0] frame_lines;
    always_comb begin
        line_len = 11'd1364;
        if (!PAL && !interlace && field && vcnt == 9'd240) line_len = 11'd1360;
        if (PAL && interlace && field && vcnt == 9'd311) line_len = 11'd1368;
        frame_lines = PAL ? 9'd312 : 9'd262;
        if (interlace && !field) frame_lines = frame_lines + 9'd1;
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hcnt <= 11'd0;
            vcnt <= 9'd0;
            field <= 1'b0;
        end else if (hcnt == line_len - 11'd1) begin
            hcnt <= 11'd0;
            if (vcnt == frame_lines - 9'd1) begin
                vcnt <= 9'd0;
                field <= !field;
            end else vcnt <= vcnt + 9'd1;
        end else hcnt <= hcnt + 11'd1;
    end
    assign line_start = hcnt == 11'd0;
    assign line = vcnt;
    assign hcount = hcnt;
    assign vblank = vcnt > vdisp;
    assign interlace_o = interlace;
    assign overscan_o = overscan;
    assign frame_o = line_start && vcnt == 9'd0;

    // Dot counter (dots 323 and 327 are six master clocks long).
    logic [8:0] hdot;
    always_comb begin
        if (hcnt < 11'd1292) hdot = hcnt[10:2];
        else if (hcnt < 11'd1298) hdot = 9'd323;
        else if (hcnt < 11'd1310) hdot = 9'd324 + 9'((hcnt - 11'd1298) >> 2);
        else if (hcnt < 11'd1316) hdot = 9'd327;
        else hdot = 9'd328 + 9'((hcnt - 11'd1316) >> 2);
    end

    // ---------------- Registers ----------------
    logic [7:0] cgadd_r, cg_latch, mdr;
    logic [8:0] cg_addr;               // word address << 1 | byte
    logic [14:0] cgram [256];
    // Display copy, one line behind CGRAM: every CGRAM write reaches it
    // exactly one line (CG_DELAY clocks) later. Line N is composed during
    // line N+1 at the dot times of line N, so each pixel sees the palette as
    // it stood when hardware would have drawn it, including writes made
    // during active display or spread over the horizontal blank.
    localparam logic [15:0] CG_DELAY = 16'd1364;
    logic [14:0] cgram_d [256];
    logic [15:0] tclk;
    logic [38:0] cg_fifo [128];        // {time, index, colour}
    logic [6:0] cg_wp, cg_rp;
    logic [7:0] w12sel, w34sel, wobjsel, wh0, wh1, wh2, wh3, wbglog, wobjlog;
    logic [7:0] tm, ts, tmw, tsw, cgwsel, cgadsub;
    logic [14:0] coldata;
    logic [8:0] ophct, opvct;
    logic hct_hi, vct_hi, latch_flag, wrio7_q;

    always_comb begin
        hit = 1'b1;
        rdata = mdr;
        case (b_addr)
            8'h37: rdata = cpu_mdr;
            8'h3b: rdata = cg_addr[0] ? {mdr[7], cgram[cg_addr[8:1]][14:8]} : cgram[cg_addr[8:1]][7:0];
            8'h3c: rdata = hct_hi ? {mdr[7:1], ophct[8]} : ophct[7:0];
            8'h3d: rdata = vct_hi ? {mdr[7:1], opvct[8]} : opvct[7:0];
            8'h3f: rdata = {field, latch_flag, mdr[5], PAL, 4'h3};
            default: hit = 1'b0;
        endcase
    end

    wire do_latch = (bus_ce && b_rd && b_addr == 8'h37) || (wrio7_q && !wrio7) || ext_latch;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            inidisp <= 8'h80; setini <= 8'h00;
            cgadd_r <= 8'h00; cg_addr <= 9'h0; cg_latch <= 8'h00; mdr <= 8'h00; cg_wp <= 7'd0;
            w12sel <= 8'h00; w34sel <= 8'h00; wobjsel <= 8'h00;
            wh0 <= 8'h00; wh1 <= 8'h00; wh2 <= 8'h00; wh3 <= 8'h00;
            wbglog <= 8'h00; wobjlog <= 8'h00;
            tm <= 8'h00; ts <= 8'h00; tmw <= 8'h00; tsw <= 8'h00;
            cgwsel <= 8'h00; cgadsub <= 8'h00; coldata <= 15'h0;
            ophct <= 9'h1ff; opvct <= 9'h1ff;
            hct_hi <= 1'b0; vct_hi <= 1'b0; latch_flag <= 1'b0; wrio7_q <= 1'b1;
        end else begin
            wrio7_q <= wrio7;
            if (do_latch && wrio7) begin
                ophct <= hdot;
                opvct <= vcnt;
                latch_flag <= 1'b1;
            end
            if (bus_ce && b_wr) begin
                case (b_addr)
                    8'h00: inidisp <= b_data_i;
                    8'h21: begin cgadd_r <= b_data_i; cg_addr <= {b_data_i, 1'b0}; end
                    8'h22: begin
                        if (!cg_addr[0]) cg_latch <= b_data_i;
                        else begin
                            cgram[cg_addr[8:1]] <= {b_data_i[6:0], cg_latch};
                            cg_fifo[cg_wp] <= {tclk, cg_addr[8:1], b_data_i[6:0], cg_latch};
                            cg_wp <= cg_wp + 7'd1;
                        end
                        cg_addr <= cg_addr + 9'd1;
                    end
                    8'h23: w12sel <= b_data_i;
                    8'h24: w34sel <= b_data_i;
                    8'h25: wobjsel <= b_data_i;
                    8'h26: wh0 <= b_data_i;
                    8'h27: wh1 <= b_data_i;
                    8'h28: wh2 <= b_data_i;
                    8'h29: wh3 <= b_data_i;
                    8'h2a: wbglog <= b_data_i;
                    8'h2b: wobjlog <= b_data_i;
                    8'h2c: tm <= b_data_i;
                    8'h2d: ts <= b_data_i;
                    8'h2e: tmw <= b_data_i;
                    8'h2f: tsw <= b_data_i;
                    8'h30: cgwsel <= b_data_i;
                    8'h31: cgadsub <= b_data_i;
                    8'h32: begin
                        if (b_data_i[5]) coldata[4:0] <= b_data_i[4:0];
                        if (b_data_i[6]) coldata[9:5] <= b_data_i[4:0];
                        if (b_data_i[7]) coldata[14:10] <= b_data_i[4:0];
                    end
                    8'h33: setini <= b_data_i;
                    default: ;
                endcase
            end
            if (bus_ce && b_rd && hit) begin
                if (b_addr != 8'h37) mdr <= rdata;
                case (b_addr)
                    8'h3b: cg_addr <= cg_addr + 9'd1;
                    8'h3c: hct_hi <= !hct_hi;
                    8'h3d: vct_hi <= !vct_hi;
                    8'h3f: begin
                        hct_hi <= 1'b0;
                        vct_hi <= 1'b0;
                        if (wrio7) latch_flag <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end

    // ---------------- Per-line register snapshots ----------------
    // S-PPU1 renders line N during line N and this chip composes it during
    // line N+1, so the composition registers are captured at the start of
    // the line they apply to and used one line later.
    typedef struct packed {
        logic [7:0] inidisp, setini, bgmode;
        logic [7:0] w12sel, w34sel, wobjsel, wh0, wh1, wh2, wh3, wbglog, wobjlog;
        logic [7:0] tm, ts, tmw, tsw, cgwsel, cgadsub;
        logic [14:0] coldata;
        logic hires;
    } regs_t;
    regs_t live, pend, r;
    always_comb begin
        live.inidisp = inidisp; live.setini = setini; live.bgmode = bgmode;
        live.w12sel = w12sel; live.w34sel = w34sel; live.wobjsel = wobjsel;
        live.wh0 = wh0; live.wh1 = wh1; live.wh2 = wh2; live.wh3 = wh3;
        live.wbglog = wbglog; live.wobjlog = wobjlog;
        live.tm = tm; live.ts = ts; live.tmw = tmw; live.tsw = tsw;
        live.cgwsel = cgwsel; live.cgadsub = cgadsub; live.coldata = coldata;
        live.hires = hires_mode || setini[3];
    end

    // ---------------- Composition ----------------
    // Line N is composed during line N+1 at line N's dot times: pixel x at
    // hcnt 88 + 4x (88 + 2x per half pixel in high resolution).
    localparam logic [10:0] H_FIRST = 11'd88;
    logic composing, active;
    logic [9:0] cx;
    logic [1:0] cdiv;
    logic [8:0] crow;
    wire [2:0] mode = r.bgmode[2:0];
    wire wide = r.hires;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            composing <= 1'b0;
            active <= 1'b0;
            cx <= 10'd0;
            cdiv <= 2'd0;
        end else if (line_start) begin
            r <= pend;
            pend <= live;
            active <= vcnt >= 9'd2 && vcnt <= vdisp + 9'd1;
            composing <= 1'b0;
            crow <= vcnt - 9'd2;
            cx <= 10'd0;
            cdiv <= 2'd0;
        end else if (active && hcnt == H_FIRST) begin
            composing <= 1'b1;
        end else if (composing) begin
            cdiv <= cdiv + 2'd1;
            if (wide ? cdiv[0] : cdiv == 2'd3) begin
                cx <= cx + 10'd1;
                cdiv <= 2'd0;
                if (cx == (wide ? 10'd511 : 10'd255)) begin
                    composing <= 1'b0;
                    active <= 1'b0;
                end
            end
        end
    end
    // Pseudo high resolution: both halves of a pixel read the same S-PPU1
    // column (the sub screen in the left half, the main screen in the right).
    assign px_x = (wide && !hires_mode) ? {1'b0, cx[9:1]} : cx;
    assign px_bank = !vcnt[0];

    // Window test for a layer: sel = 4 setting bits, lg = 2 logic bits.
    function automatic logic win(input logic [3:0] sel, input logic [1:0] lg,
                                 input logic w1, input logic w2);
        logic a, b;
        a = w1 ^ sel[0];
        b = w2 ^ sel[2];
        case (sel[3:0] & 4'b1010)
            4'b0000: win = 1'b0;
            4'b0010: win = a;
            4'b1000: win = b;
            default:
                case (lg)
                    2'd0: win = a | b;
                    2'd1: win = a & b;
                    2'd2: win = a ^ b;
                    default: win = !(a ^ b);
                endcase
        endcase
    endfunction

    // Depth rank of a layer pixel (0 = front, 15 = not displayed).
    function automatic logic [3:0] rank(input logic [2:0] m, input logic bg3p, input logic extbg,
                                        input logic [2:0] layer, input logic [1:0] pr);
        rank = 4'hf;
        case (m)
            3'd0:
                case (layer)
                    3'd4: rank = pr == 2'd3 ? 4'd0 : (pr == 2'd2 ? 4'd3 : (pr == 2'd1 ? 4'd6 : 4'd9));
                    3'd0: rank = pr[0] ? 4'd1 : 4'd4;
                    3'd1: rank = pr[0] ? 4'd2 : 4'd5;
                    3'd2: rank = pr[0] ? 4'd7 : 4'd10;
                    default: rank = pr[0] ? 4'd8 : 4'd11;
                endcase
            3'd1:
                if (bg3p)
                    case (layer)
                        3'd4: rank = pr == 2'd3 ? 4'd1 : (pr == 2'd2 ? 4'd4 : (pr == 2'd1 ? 4'd7 : 4'd8));
                        3'd0: rank = pr[0] ? 4'd2 : 4'd5;
                        3'd1: rank = pr[0] ? 4'd3 : 4'd6;
                        3'd2: rank = pr[0] ? 4'd0 : 4'd9;
                        default: ;
                    endcase
                else
                    case (layer)
                        3'd4: rank = pr == 2'd3 ? 4'd0 : (pr == 2'd2 ? 4'd3 : (pr == 2'd1 ? 4'd6 : 4'd8));
                        3'd0: rank = pr[0] ? 4'd1 : 4'd4;
                        3'd1: rank = pr[0] ? 4'd2 : 4'd5;
                        3'd2: rank = pr[0] ? 4'd7 : 4'd9;
                        default: ;
                    endcase
            3'd6:
                case (layer)
                    3'd4: rank = pr == 2'd3 ? 4'd0 : (pr == 2'd2 ? 4'd2 : (pr == 2'd1 ? 4'd3 : 4'd5));
                    3'd0: rank = pr[0] ? 4'd1 : 4'd4;
                    default: ;
                endcase
            3'd7:
                case (layer)
                    3'd4: rank = pr == 2'd3 ? 4'd0 : (pr == 2'd2 ? 4'd1 : (pr == 2'd1 ? 4'd3 : 4'd5));
                    3'd0: rank = 4'd4;
                    3'd1: rank = extbg ? (pr[0] ? 4'd2 : 4'd6) : 4'hf;
                    default: ;
                endcase
            default: // modes 2-5
                case (layer)
                    3'd4: rank = pr == 2'd3 ? 4'd0 : (pr == 2'd2 ? 4'd2 : (pr == 2'd1 ? 4'd4 : 4'd6));
                    3'd0: rank = pr[0] ? 4'd1 : 4'd5;
                    3'd1: rank = pr[0] ? 4'd3 : 4'd7;
                    default: ;
                endcase
        endcase
    endfunction

    // Bits per pixel (for palette indexing) of each background in a mode.
    function automatic logic [3:0] bpp_of(input logic [2:0] m, input logic [1:0] n);
        case (m)
            3'd0: bpp_of = 4'd2;
            3'd1: bpp_of = n == 2'd2 ? 4'd2 : 4'd4;
            3'd2: bpp_of = 4'd4;
            3'd3: bpp_of = n == 2'd0 ? 4'd8 : 4'd4;
            3'd4: bpp_of = n == 2'd0 ? 4'd8 : 4'd2;
            3'd5: bpp_of = n == 2'd0 ? 4'd4 : 4'd2;
            3'd6: bpp_of = 4'd4;
            default: bpp_of = 4'd8;
        endcase
    endfunction

    // Resolve one screen (main or sub) at this pixel. Returns
    // {found, layer[2:0], obj_math_ok, cgram index[7:0], direct, direct_rgb[14:0]}.
    typedef struct packed {
        logic found;
        logic [2:0] layer;      // 0-3 BG, 4 OBJ, 5 backdrop
        logic math_ok;          // OBJ palettes 0-3 never take part in colour math
        logic direct;
        logic [7:0] idx;
        logic [14:0] drgb;
    } pick_t;

    logic w1, w2;
    always_comb begin
        logic [7:0] xs;
        xs = wide ? cx[8:1] : cx[7:0];
        w1 = xs >= r.wh0 && xs <= r.wh1;
        w2 = xs >= r.wh2 && xs <= r.wh3;
    end
    logic [5:0] win_l;          // BG1-4, OBJ, colour window
    always_comb begin
        win_l[0] = win(r.w12sel[3:0], r.wbglog[1:0], w1, w2);
        win_l[1] = win(r.w12sel[7:4], r.wbglog[3:2], w1, w2);
        win_l[2] = win(r.w34sel[3:0], r.wbglog[5:4], w1, w2);
        win_l[3] = win(r.w34sel[7:4], r.wbglog[7:6], w1, w2);
        win_l[4] = win(r.wobjsel[3:0], r.wobjlog[1:0], w1, w2);
        win_l[5] = win(r.wobjsel[7:4], r.wobjlog[3:2], w1, w2);
    end

    function automatic logic [28:0] pick(input logic [7:0] en, input logic [7:0] wen,
                                   input logic [5:0] wl, input logic [47:0] bgp,
                                   input logic [8:0] objp, input logic [7:0] rr_bgmode, input logic [7:0] rr_setini, input logic [7:0] rr_cgwsel);
        logic [3:0] best, rk;
        logic [2:0] bl;
        logic pk_found, pk_math_ok, pk_direct;
        logic [2:0] pk_layer;
        logic [14:0] pk_drgb;
        logic [7:0] idx;
        logic [3:0] b;
        logic [11:0] pi, ps, p0;
        best = 4'hf;
        bl = 3'd5;
        for (int i = 0; i < 4; i++) begin
            pi = bgp[i * 12 +: 12];
            if (en[i] && !(wen[i] && wl[i]) && pi[7:0] != 8'h00) begin
                rk = rank(rr_bgmode[2:0], rr_bgmode[3], rr_setini[6], 3'(i), {1'b0, pi[11]});
                if (rk < best) begin best = rk; bl = 3'(i); end
            end
        end
        if (en[4] && !(wen[4] && wl[4]) && objp[3:0] != 4'h0) begin
            rk = rank(rr_bgmode[2:0], rr_bgmode[3], rr_setini[6], 3'd4, objp[8:7]);
            if (rk < best) begin best = rk; bl = 3'd4; end
        end
        pk_found = bl != 3'd5;
        pk_layer = bl;
        pk_math_ok = 1'b1;
        pk_direct = 1'b0;
        pk_drgb = 15'h0000;
        idx = 8'h00;
        if (bl == 3'd4) begin
            idx = {1'b1, objp[6:4], objp[3:0]};
            pk_math_ok = objp[6];
        end else if (bl != 3'd5) begin
            b = bpp_of(rr_bgmode[2:0], bl[1:0]);
            ps = bgp[bl[1:0] * 12 +: 12];
            p0 = bgp[11:0];
            case (b)
                4'd2: idx = rr_bgmode[2:0] == 3'd0 ? {1'b0, bl[1:0], ps[10:8], ps[1:0]}
                                                   : {3'b000, ps[10:8], ps[1:0]};
                4'd4: idx = {1'b0, ps[10:8], ps[3:0]};
                default: idx = ps[7:0];
            endcase
            // Direct colour: 8-bit pixels of BG1 in modes 3, 4 and 7.
            pk_direct = rr_cgwsel[0] && bl == 3'd0 && b == 4'd8;
            pk_drgb = {p0[7:6], p0[10], 2'b00,
                          p0[5:3], p0[9], 1'b0,
                          p0[2:0], p0[8], 1'b0};
        end
        pick = {pk_found, pk_layer, pk_math_ok, pk_direct, idx, pk_drgb};
    endfunction

    pick_t main_p, sub_p;
    always_comb begin
        main_p = pick(r.tm, r.tmw, win_l, bg_px, obj_px, r.bgmode, r.setini, r.cgwsel);
        sub_p = pick(r.ts, r.tsw, win_l, bg_px, obj_px, r.bgmode, r.setini, r.cgwsel);
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tclk <= 16'd0;
            cg_rp <= 7'd0;
        end else begin
            tclk <= tclk + 16'd1;
            // Both halves of a high-resolution pixel read CGRAM at one instant.
            if (cg_rp != cg_wp && tclk - cg_fifo[cg_rp][38:23] >= CG_DELAY &&
                !(composing && wide && cx[0])) begin
                cgram_d[cg_fifo[cg_rp][22:15]] <= cg_fifo[cg_rp][14:0];
                cg_rp <= cg_rp + 7'd1;
            end
        end
    end
    wire [14:0] main_c = main_p.direct ? main_p.drgb : cgram_d[main_p.idx];
    wire [14:0] sub_c = sub_p.direct ? sub_p.drgb : cgram_d[sub_p.idx];

    // Colour math and brightness.
    function automatic logic [14:0] bright(input logic [14:0] c, input logic [3:0] lv);
        logic [8:0] rr, gg, bb;
        rr = {4'h0, c[4:0]} * {5'h00, lv} + {4'h0, c[4:0]};
        gg = {4'h0, c[9:5]} * {5'h00, lv} + {4'h0, c[9:5]};
        bb = {4'h0, c[14:10]} * {5'h00, lv} + {4'h0, c[14:10]};
        bright = {bb[8:4], gg[8:4], rr[8:4]};
    endfunction

    function automatic logic [14:0] cmath(input logic [14:0] a, input logic [14:0] b,
                                          input logic subtract, input logic halve);
        for (int i = 0; i < 3; i++) begin
            logic [5:0] sum;
            if (!subtract) sum = {1'b0, a[i * 5 +: 5]} + {1'b0, b[i * 5 +: 5]};
            else sum = (a[i * 5 +: 5] >= b[i * 5 +: 5]) ? {1'b0, a[i * 5 +: 5]} - {1'b0, b[i * 5 +: 5]} : 6'h00;
            if (halve) sum = {1'b0, sum[5:1]};
            else if (sum[5]) sum = 6'h1f;
            cmath[i * 5 +: 5] = sum[4:0];
        end
    endfunction

    logic [14:0] main_rgb, sub_rgb, out_rgb, m_cur, m_prev;
    always_ff @(posedge clk)
        if (pix_valid && cx[0]) m_prev <= m_cur;
    always_comb begin
        logic cw, clip, nomath, use_math, halve, sub_is_fixed;
        logic [14:0] m, s;
        cw = win_l[5];
        case (r.cgwsel[7:6])
            2'd0: clip = 1'b0;
            2'd1: clip = !cw;
            2'd2: clip = cw;
            default: clip = 1'b1;
        endcase
        case (r.cgwsel[5:4])
            2'd0: nomath = 1'b0;
            2'd1: nomath = !cw;
            2'd2: nomath = cw;
            default: nomath = 1'b1;
        endcase
        m = clip ? 15'h0000 : main_c;
        m_cur = m;
        sub_is_fixed = !r.cgwsel[1] || !sub_p.found;
        s = sub_is_fixed ? r.coldata : sub_c;
        use_math = !nomath && main_p.math_ok &&
                   (main_p.layer == 3'd5 ? r.cgadsub[5] : r.cgadsub[main_p.layer]);
        halve = r.cgadsub[6] && !clip && !(r.cgwsel[1] && !sub_p.found);
        main_rgb = use_math ? cmath(m, s, r.cgadsub[7], halve) : m;
        // A transparent sub-screen pixel shows the backdrop colour (CGRAM 0).
        sub_rgb = sub_p.found ? sub_c : cgram_d[0];
        // High resolution: the left half shows the sub screen, blended with
        // the previous main screen pixel by the same colour-math rule.
        // The first pixel of a line has no previous one and uses its own
        // (assumption A5: the reference differs in this column on some lines).
        if (use_math) sub_rgb = cmath(sub_rgb, cx == 10'd0 ? m : m_prev, r.cgadsub[7], halve);
        if (r.inidisp[7]) out_rgb = 15'h0000;
        else if (wide && !cx[0]) out_rgb = bright(sub_rgb, r.inidisp[3:0]);
        else out_rgb = bright(main_rgb, r.inidisp[3:0]);
    end

    assign pix_valid = composing && (wide ? cdiv[0] : cdiv == 2'd3);
    assign pix_x = cx;
    assign pix_y = crow;
    assign pix_rgb = out_rgb;
    assign pix_hires = wide;
    /* verilator lint_on UNUSEDSIGNAL */
endmodule
