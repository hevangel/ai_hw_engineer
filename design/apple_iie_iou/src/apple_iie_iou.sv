// Apple IIe IOU (Synertek 341-0267) — functional reconstruction.
// One clk edge = one PHI_0 period = one horizontal scanner state (spec A2).
// All behavior per spec/spec.md; ASSUMPTION markers reference its ledger.
`timescale 1ns/1ps

module apple_iie_iou (
    input  logic       clk,
    input  logic       rst_n,      // RESET' (A3)
    // CPU-cycle side
    input  logic       phi0,       // PH0: 1 = CPU phase
    input  logic       q3,         // timing qualifier (switch selects need 0)
    input  logic       pras_n,     // PRAS': 1 = row half, 0 = column half
    input  logic       rw,         // R/W': 1 = read
    input  logic       c0xx_n,     // C0XX': 0 = $C0xx cycle
    input  logic       a6,         // dedicated address bit 6
    // Video data bus (character code bits 6/7)
    input  logic       vid6,
    input  logic       vid7,
    // Keyboard
    input  logic       ikstrb,     // raw AY-3600 key-press strobe
    input  logic       iakd,       // raw any-key-down level
    output logic       kstrb,      // retimed strobe
    output logic       akd,        // retimed any-key-down
    // RA bus (A8 split of the bidirectional pins)
    input  logic [6:0] ra_sense,   // bus during CPU row phase: A0..A5,A7
    output logic [7:0] ra_o,       // IOU video address (video phase)
    // Video pins
    output logic       h0,
    output logic       sega,
    output logic       segb,
    output logic       vc,
    output logic       gr,
    output logic       wndw_n,
    output logic       sync_n,
    output logic       clrgat_n,
    output logic       ra9_n,
    output logic       ra10_n,
    output logic       s80vid_n,
    // Misc I/O
    output logic       spkr,
    output logic       casso,
    output logic       an0,
    output logic       an1,
    output logic       an2,
    output logic       an3,
    // Flag readback
    output logic       md7_oe,
    output logic       md7
);

    // ------------------------------------------------------------------
    // 1. Video scanner counter (spec 6)
    // ------------------------------------------------------------------
    logic [20:0] cnt;

`ifdef FORMAL
    (* anyconst *) logic [20:0] cnt_init;   // formal start-state hook (A6)
`endif

    logic tc;
    assign tc = (cnt[15:0] == 16'hFFFF);

    logic [20:0] cnt_nxt;
    always_comb begin
        cnt_nxt = cnt;
        if (!cnt[6]) begin
            cnt_nxt[6:0] = 7'd64;            // HPE' reload: H=0, HPE'=1
        end else begin
            cnt_nxt = cnt + 21'd1;
        end
        if (tc) begin                        // vertical load values (NTSC, A1)
            cnt_nxt[15]     = 1'b0;          // V5
            cnt_nxt[14:10]  = 5'b11111;      // V4..V0
            cnt_nxt[9]      = 1'b0;          // VC
            cnt_nxt[8]      = 1'b1;          // VB (VA falls through carry)
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
`ifdef FORMAL
            cnt <= cnt_init;
`else
            cnt <= 21'h1F0000;               // A6: deterministic stand-in
`endif
        end else begin
            cnt <= cnt_nxt;
        end
    end

    // Scanner bit aliases (vertical field = cnt[15:7], VA = LSB; spec 6/7)
    logic h0i, h1i, h2i, h3i, h4i, h5i;
    logic va_i, vb_i, vc_i, v0i, v1i, v2i, v3i, v4i;
    assign {h5i, h4i, h3i, h2i, h1i, h0i} = cnt[5:0];
    assign {v4i, v3i, v2i, v1i, v0i, vc_i, vb_i, va_i} = cnt[14:7];

    logic tc14s, pakst, flash;
    assign tc14s = (cnt[19:0] == 20'hFFFFF);
    assign pakst = cnt[17];
    assign flash = cnt[20];

    // ------------------------------------------------------------------
    // 2. Windows and video timing (spec 6; combinational per A2)
    // ------------------------------------------------------------------
    logic hbl, bl_n, vbl_n, serr;
    logic v1_nv5_n, v2_v2_n, r9_6;
    logic psync_n, pclrgat;
    assign hbl   = !((h3i & h4i) | h5i);
    assign bl_n  = !((v3i & v4i) | hbl);
    assign vbl_n = !(v3i & v4i);
    assign serr  = !(h3i | h4i | h5i);

    assign v1_nv5_n = !v1i;                  // NTSC branch (A1)
    assign v2_v2_n  = v2i;                   // NTSC: PAL xor V2 with PAL=0
    assign r9_6     = (v3i & v4i) & !v0i & !vc_i & !serr;
    assign psync_n  = !((hbl & !h2i & h3i) | (v1_nv5_n & v2_v2_n & r9_6));
    assign pclrgat  = h2i & h3i & hbl;       // gated by !ITEXT at the pin

    assign h0      = h0i;
    assign wndw_n  = !bl_n;                  // 0 = display window open
    assign sync_n  = psync_n;

    // ------------------------------------------------------------------
    // 3. CPU address latch (spec 2/4; A8). The real latch is transparent
    // around the PH0 rising edge (P_PHI_2): during the row phase the
    // decode sees the bus directly; the register holds the value for the
    // column half of the same cycle.
    // ------------------------------------------------------------------
    logic la0_q, la1_q, la2_q, la3_q, la4_q, la5_q, la7_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            {la0_q, la1_q, la2_q, la3_q, la4_q, la5_q, la7_q} <= 7'b0;
        end else if (phi0 && pras_n) begin
            la0_q <= ra_sense[0];            // A0
            la1_q <= ra_sense[1];            // A1
            la2_q <= ra_sense[2];            // A2
            la3_q <= ra_sense[3];            // A3
            la4_q <= ra_sense[4];            // A4
            la5_q <= ra_sense[5];            // A5
            la7_q <= ra_sense[6];            // A7 (no LA6: A6 has its own pin)
        end
    end

    logic la0, la1, la2, la3, la4, la5, la7;
    assign la0 = (phi0 && pras_n) ? ra_sense[0] : la0_q;
    assign la1 = (phi0 && pras_n) ? ra_sense[1] : la1_q;
    assign la2 = (phi0 && pras_n) ? ra_sense[2] : la2_q;
    assign la3 = (phi0 && pras_n) ? ra_sense[3] : la3_q;
    assign la4 = (phi0 && pras_n) ? ra_sense[4] : la4_q;
    assign la5 = (phi0 && pras_n) ? ra_sense[5] : la5_q;
    assign la7 = (phi0 && pras_n) ? ra_sense[6] : la7_q;

    logic [3:0] la;
    assign la = {la3, la2, la1, la0};

    // ------------------------------------------------------------------
    // 4. Range decode (spec 4; 74LS138 on LA4/LA5/A6)
    // C04x ($C040-$C04F) and C06x ($C060-$C06F) produce no IOU response
    // ('138 Y4/Y6 unused at the IOU; board-level decode, A7).
    // ------------------------------------------------------------------
    logic iou_en, sel_c00x, sel_c01x, sel_c02x, sel_c03x, sel_c05x, sel_c07x;
    assign iou_en   = !c0xx_n && !la7 && !q3;
    assign sel_c00x = iou_en && !a6 && !la5 && !la4;
    assign sel_c01x = iou_en && !a6 && !la5 &&  la4;
    assign sel_c02x = iou_en && !a6 &&  la5 && !la4;
    assign sel_c03x = iou_en && !a6 &&  la5 &&  la4;
    assign sel_c05x = iou_en &&  a6 && !la5 &&  la4;
    assign sel_c07x = iou_en &&  a6 &&  la5 &&  la4;

    // ------------------------------------------------------------------
    // 5. Soft switches (spec 5)
    // ------------------------------------------------------------------
    logic en80vid, s80col, paymar;           // C00x latch, IOU-used bits
    logic itext, mix, pg2, hires;            // C05x latch
    logic an0_q, an1_q, an2_q, an3_q;        // AN3 shared with DHIRES (A5)
    logic ioudis;

    logic wr_act, c00x_wr, c05x_wr, c07ef_wr;
    assign wr_act   = phi0 && !rw;
    assign c00x_wr  = sel_c00x && wr_act;
    assign c05x_wr  = sel_c05x && wr_act;
    assign c07ef_wr = sel_c07x && wr_act && la[3] && la[2] && la[1];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // 9334 async-clear equivalent (spec 5.1); ITEXT/MIX cleared per A4
            en80vid <= 1'b0; s80col <= 1'b0; paymar <= 1'b0;
            itext   <= 1'b0; mix    <= 1'b0; pg2    <= 1'b0; hires <= 1'b0;
            an0_q   <= 1'b0; an1_q  <= 1'b0; an2_q  <= 1'b0; an3_q <= 1'b0;
            ioudis  <= 1'b0;         // A4/A5
        end else begin
            // $C000-$C00F shared latch: IOU-used selects 0/6/7 (spec 5.1)
            if (c00x_wr) begin
                case (la[3:1])
                    3'd0: en80vid <= la0;
                    3'd6: s80col  <= la0;
                    3'd7: paymar  <= la0;
                    default: ;       // $C002-$C00B: MMU-side bits, no IOU output
                endcase
            end
            // $C050-$C05F video latch (spec 5.2): a 74LS259-style bank of
            // eight latches, select = la[3:1], D = la0.
            if (c05x_wr) begin
                if (la[3:1] == 3'd0)      itext <= la0;
                else if (la[3:1] == 3'd1) mix   <= la0;
                else if (la[3:1] == 3'd2) pg2   <= la0;
                else if (la[3:1] == 3'd3) hires <= la0;
                else if (la[3:1] == 3'd4) begin
                    if (!ioudis) an0_q <= la0;   // IOUDIS gates C058-$C05D
                end else if (la[3:1] == 3'd5) begin
                    if (!ioudis) an1_q <= la0;
                end else if (la[3:1] == 3'd6) begin
                    if (!ioudis) an2_q <= la0;
                end else begin
                    an3_q <= la0;                // select 111 always live
                end
            end
            // $C07E/$C07F IOUDIS latch (spec 5.3, A5)
            if (c07ef_wr) ioudis <= !la0;      // C07E (D=0) = on, C07F = off
        end
    end

    assign an0 = an0_q;
    assign an1 = an1_q;
    assign an2 = an2_q;
    assign an3 = an3_q;
    assign s80vid_n = !s80col;

    // ------------------------------------------------------------------
    // 6. Mode flag and display address (spec 7)
    // ------------------------------------------------------------------
    logic gr_q;                               // graphics region flag (registered)
    always_ff @(posedge clk) begin
        if (!rst_n) gr_q <= 1'b0;
        else gr_q <= !((mix && v2i && v4i) || itext);   // pre-edge V2/V4
    end
    assign gr = gr_q;

    logic hiresen_n, vid_pg2_n;
    assign hiresen_n = !(gr_q && hires);      // HIRES': 0 = hires active
    assign vid_pg2_n = !pg2 || en80vid;       // 80STORE gates PAGE2

    logic za, zb, zc, zd, ze;
    always_comb begin
        if (!hiresen_n) begin                 // hires active (spec 7.4)
            za = va_i;
            zb = vb_i;
            zc = vc_i;
            zd = vid_pg2_n;
        end else begin                        // text / lo-res
            za = vid_pg2_n;
            zb = !vid_pg2_n;
            zc = 1'b0;
            zd = 1'b0;
        end
        ze = !hiresen_n && !vid_pg2_n;        // hires page2 (80STORE')
    end

    // Sigma fold (spec 7.2): 4-bit sum, carry discarded
    logic [3:0] sum4;
    logic h5n;
    assign h5n  = !h5i;
    assign sum4 = 4'd1 + {h5n, h5n, h4i, h3i} + {v4i, v3i, v4i, v3i};

    // RA bytes (spec 7.3): row half = A0..A5,A7,A8; column half = A9,A6,A10..A15
    logic [7:0] row_byte, col_byte;
    assign row_byte = {v1i, v0i, sum4[2], sum4[1], sum4[0], h2i, h1i, h0i};
    assign col_byte = {1'b0, ze, zd, zc, zb, za, sum4[3], v2i};
    assign ra_o     = pras_n ? row_byte : col_byte;

    // Character-ROM mode selects (spec 7.6)
    assign ra9_n  = vid6 && (gr_q || paymar || vid7);
    assign ra10_n = (vid6 && !paymar && !flash && !gr_q) || vid7;

    // Character line selects (spec 7.7): comb mux off the registered GR
    assign sega = gr_q ? h0i : va_i;
    assign segb = gr_q ? hiresen_n : vb_i;
    assign vc   = vc_i;
    assign clrgat_n = !(pclrgat && !itext);

    // ------------------------------------------------------------------
    // 7. Speaker / cassette (spec 5.5)
    // ------------------------------------------------------------------
    logic spkr_q, casso_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            spkr_q  <= 1'b0;
            casso_q <= 1'b0;
        end else begin
            if (sel_c03x) spkr_q  <= !spkr_q;
            if (sel_c02x) casso_q <= !casso_q;
        end
    end
    assign spkr  = spkr_q;
    assign casso = casso_q;

    // ------------------------------------------------------------------
    // 8. Keyboard (spec 5.4/8)
    // ------------------------------------------------------------------
    logic [1:0] kstrb_sh, akd_sh;
    logic kstrb_prev, m8_3, ctc14s_q;
    logic set_delay, auto_active, key;
    logic [2:0] n9;
    logic strble, akstb, keyle, clrkey;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            kstrb_sh    <= 2'b00;
            akd_sh      <= 2'b00;
            kstrb_prev  <= 1'b0;
            m8_3        <= 1'b0;
            ctc14s_q    <= 1'b0;
            set_delay   <= 1'b0;
            n9          <= 3'b000;
            auto_active <= 1'b0;
            key         <= 1'b0;
        end else begin
            kstrb_sh   <= {kstrb_sh[0], ikstrb};   // 2-stage retime (A2)
            akd_sh     <= {akd_sh[0], iakd};
            kstrb_prev <= kstrb_sh[1];
            m8_3       <= !pakst;
            ctc14s_q   <= tc14s;
            // SET_DELAY RS: cleared on key-up, set by the strobe pulse
            if (!akd_sh[1])           set_delay <= 1'b0;
            else if (strble)          set_delay <= 1'b1;
            // N9 auto-repeat counter: 3 CTC14S ticks while key held
            if (!akd_sh[1] || strble) n9 <= 3'b000;
            else if (ctc14s_q)        n9 <= {n9[1:0], set_delay};
            // AUTOREPEAT_ACTIVE RS
            if (!akd_sh[1] || strble) auto_active <= 1'b0;
            else if (n9[2])           auto_active <= 1'b1;
            // KEY flag (spec 5.4): set on KEYLE, clear on CLRKEY, hold if both
            if (keyle && !clrkey)      key <= 1'b1;
            else if (clrkey && !keyle) key <= 1'b0;
        end
    end

    assign kstrb   = kstrb_sh[1];
    assign akd     = akd_sh[1];
    assign strble  = kstrb && !kstrb_prev;            // KSTRB rising pulse
    assign akstb   = pakst && m8_3;                   // PAKST rising
    assign keyle   = strble || (akstb && auto_active);
    // CLRKEY: read of $C010, or write to any $C010-$C01F (spec 5.4)
    assign clrkey  = (sel_c01x && rw && (la == 4'b0000)) || (sel_c01x && !rw);

    // ------------------------------------------------------------------
    // 9. MD7 readback (spec 9)
    // ------------------------------------------------------------------
    logic md7_c01x_oe, md7_c07x_oe;
    logic c07ef;
    assign c07ef        = la[3] && la[2] && la[1];    // $C07E/$C07F only
    // OE: $C000-$C00F, $C010, $C019-$C01F, $C07E/$C07F. $C011-$C018 belong
    // to the MMU and never drive the bus from here.
    assign md7_c01x_oe  = sel_c01x && rw && ((la == 4'h0) || (la >= 4'h9));
    assign md7_c07x_oe  = sel_c07x && rw && c07ef && (!la[0] || ioudis);
    assign md7_oe       = rw && (sel_c00x || md7_c01x_oe || md7_c07x_oe);

    // Value mux: computed for every C01x read (the $C011-$C018 default arm
    // evaluates even though OE is off).
    always_comb begin
        md7 = 1'b0;
        if (sel_c00x && rw) begin
            md7 = key;                            // any $C000-$C00F read
        end else if (sel_c01x && rw) begin
            case (la)
                4'h0:    md7 = akd;               // $C010 any-key-down
                4'h9:    md7 = vbl_n;             // $C019 VBL'
                4'hA:    md7 = itext;
                4'hB:    md7 = mix;
                4'hC:    md7 = pg2;
                4'hD:    md7 = hires;
                4'hE:    md7 = paymar;
                4'hF:    md7 = s80col;
                default: md7 = 1'b0;              // $C011-$C018: MMU's
            endcase
        end else if (md7_c07x_oe) begin
            md7 = la[0] ? an3_q : !ioudis;        // $C07F DHIRES / $C07E
        end
    end

`ifdef FORMAL
    `include "apple_iie_iou_props.sv"
    `include "apple_iie_iou_cover_setup.sv"
`endif
endmodule
