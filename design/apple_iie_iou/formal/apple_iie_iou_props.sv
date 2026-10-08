// Apple IIe IOU formal properties.
// Included inside apple_iie_iou.sv under `ifdef FORMAL. Immediate asserts in
// clocked blocks only. Expected values are restated from spec/spec.md (TRM
// Tables 7-7/7-9/7-13, Sather p.5-9 fold, frozen-signal ground-truth
// sequences) with independent encodings, not copied from the RTL.
//
// Reachability: a frame is 262*65 cycles, so the scanner reset value is an
// anyconst (cnt_init in the RTL): every property is exercised around an
// arbitrary scanner state, and the counter update rules are proven
// separately as local transitions.

`ifdef FORMAL

logic f_past_valid;
initial f_past_valid = 1'b0;

// Shadow registers for transition checks (all sampled pre-edge).
logic        f_rst_d;
logic        f_rst_d2;          // two edges of reset history (retime flush)
logic        f_phi0_pras_d;     // phi0 && pras_n of the previous cycle
logic [6:0]  f_ra_sense_d;
logic        f_ik_d1, f_ik_d2;  // ikstrb delay shadows
logic        f_akd_d1, f_akd_d2;
logic        f_mix_d, f_itext_d, f_v2_d, f_v4_d;
logic        f_sel_c02x_d, f_sel_c03x_d;
logic        f_an0_d, f_an1_d, f_an2_d;   // AN latch hold-check shadows

always_ff @(posedge clk) begin
    f_rst_d         <= rst_n;
    f_rst_d2        <= f_rst_d;
    f_phi0_pras_d   <= phi0 && pras_n;
    f_ra_sense_d    <= ra_sense;
    f_ik_d1         <= ikstrb;
    f_ik_d2         <= f_ik_d1;
    f_akd_d1        <= iakd;
    f_akd_d2        <= f_akd_d1;
    f_mix_d         <= mix;
    f_itext_d       <= itext;
    f_v2_d          <= cnt[12];
    f_v4_d          <= cnt[14];
    f_sel_c02x_d    <= sel_c02x;
    f_sel_c03x_d    <= sel_c03x;
    f_an0_d         <= an0_q;
    f_an1_d         <= an1_q;
    f_an2_d         <= an2_q;
end

// ---- Independent decode helpers (explicit compares, spec 4 table) --------
function automatic logic f_sel00(input logic a6v, l5, l4);
    f_sel00 = !a6v && !l5 && !l4;
endfunction
function automatic logic f_sel01(input logic a6v, l5, l4);
    f_sel01 = !a6v && !l5 &&  l4;
endfunction
function automatic logic f_sel05(input logic a6v, l5, l4);
    f_sel05 =  a6v && !l5 &&  l4;
endfunction
function automatic logic f_sel07(input logic a6v, l5, l4);
    f_sel07 =  a6v &&  l5 &&  l4;
endfunction

// ---- Display address: closed-form logical address (spec 7.5) -------------
// L = scanline index (field-256), H = horizontal state. The Sigma term is
// evaluated in the alternative algebraic form 13 + H3 + 2*H4 + 4*H5
// + 5*V3 + 10*V4 (mod 16) — 1 + 12*!H5 == 13 + 4*H5 (mod 16) — which equals
// Sather's 1 + {H5',H5',H4,H3} + {V4,V3,V4,V3} exactly, so a transcription
// error cannot hide.
function automatic logic [15:0] f_addr(input logic [20:0] c,
                                       input logic        hires_act,
                                       input logic        pg2v,
                                       input logic        en80v);
    logic [3:0]  s;
    logic [15:0] a;
    s = 4'd13 + (c[3] ? 4'd1 : 4'd0) + (c[4] ? 4'd2 : 4'd0)
              + (c[5] ? 4'd4 : 4'd0)
              + (c[13] ? 4'd5 : 4'd0) + (c[14] ? 4'd10 : 4'd0);
    a = 16'h0000;
    a[2:0] = c[2:0];                    // H0..H2 = column low bits
    a[6:3] = s;                         // Sigma fold
    a[9:7] = c[12:10];                  // V0..V2
    if (!hires_act) begin               // text / lo-res page bits (Table 7-13)
        a[10]    = en80v || !pg2v;      // 80STORE + PAGE2'
        a[11]    = !en80v && pg2v;      // 80STORE' * PAGE2
        a[15:12] = 4'b0;
    end else begin                      // hires / double-hires page bits
        a[12:10] = c[9:7];              // VA..VC
        a[13]    = en80v || !pg2v;      // aux select
        a[14]    = !en80v && pg2v;      // hires page 2 (80STORE')
        a[15]    = 1'b0;
    end
    f_addr = a;
endfunction

// TRM Table 7-9: which logical address bit each RA pin carries per phase.
function automatic logic [7:0] f_row_of(input logic [15:0] a);
    f_row_of = {a[8], a[7], a[5], a[4], a[3], a[2], a[1], a[0]};
endfunction
function automatic logic [7:0] f_col_of(input logic [15:0] a);
    f_col_of = {a[15], a[14], a[13], a[12], a[11], a[10], a[6], a[9]};
endfunction

// ---- Window helpers (spec 6) ---------------------------------------------
function automatic logic f_hbl(input logic [20:0] c);
    f_hbl = !(((c[3] & c[4]) | c[5]));
endfunction
function automatic logic f_vbl(input logic [20:0] c);
    f_vbl = (c[14] & c[13]);            // 1 = vertical blank region
endfunction

logic [15:0] f_exp_addr;
logic [7:0]  f_exp_ra;

always_comb begin
    f_exp_addr = f_addr(cnt, gr_q && hires, pg2, en80vid);
    f_exp_ra   = pras_n ? f_row_of(f_exp_addr) : f_col_of(f_exp_addr);
end

always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) assume(!rst_n);

    if (rst_n && f_past_valid) begin
        // ---- 1. Scanner counter transitions (spec 6) ----
        if (!cnt[6]) begin
            assert(cnt_nxt[6:0] == 7'd64);                    // HPE reload
            assert(cnt_nxt[20:7] == cnt[20:7]);
        end else if (!tc) begin
            assert(cnt_nxt == cnt + 21'd1);
        end else begin
            assert(cnt[15:0] == 16'hFFFF);
            assert(cnt_nxt[15:0] == 16'h7D00);                // field 250, H=0
            assert(cnt_nxt[20:16] == cnt[20:16] + 5'd1);      // FLASH/PAKST keep counting
        end
        // HPE' is low for exactly one state: the reload always raises it.
        if (!cnt[6]) assert(cnt_nxt[6]);

        // ---- 2. Display address (spec 7.3/7.4/7.5) ----
        // Pure function of the scanner state and the mode latches, in both
        // PRAS phases; the closed form covers visible and blanked regions.
        assert(ra_o == f_exp_ra);

        // ---- 3. Window/timing pins (spec 6) ----
        assert(hbl    == f_hbl(cnt));
        assert(vbl_n  == !f_vbl(cnt));
        assert(wndw_n == !(!((cnt[14] & cnt[13]) | f_hbl(cnt))));
        assert(h0     == cnt[0]);
        assert(sync_n == !(((f_hbl(cnt)) & !cnt[2] & cnt[3])
                           | ((!cnt[11]) & cnt[12] & ((cnt[14] & cnt[13])
                              & !cnt[10] & !cnt[9] & (cnt[3] | cnt[4] | cnt[5])))));
        assert(clrgat_n == !((cnt[2] & cnt[3] & f_hbl(cnt)) && !itext));

        // ---- 4. Registered mode flag (spec 7.1) ----
        // Guarded on the previous edge also being out of reset: gr_q is
        // cleared by reset, and its first post-reset update happens one
        // edge later from the reset latch values.
        if (f_rst_d) begin
            assert(gr_q == !((f_mix_d && f_v2_d && f_v4_d) || f_itext_d));
        end

        // ---- 5. Character line selects (spec 7.7) ----
        assert(sega == (gr_q ? cnt[0] : cnt[7]));
        assert(segb == (gr_q ? !(gr_q && hires) : cnt[8]));
        assert(vc   == cnt[9]);

        // ---- 6. Character-ROM mode selects (spec 7.6) ----
        assert(ra9_n  == (vid6 && (gr_q || paymar || vid7)));
        assert(ra10_n == ((vid6 && !paymar && !flash && !gr_q) || vid7));
        assert(s80vid_n == !s80col);

        // ---- 7. CPU address latch (spec 2/4, A8): registered hold value ----
        if (f_rst_d && f_phi0_pras_d) begin
            assert(la0_q == f_ra_sense_d[0]);
            assert(la1_q == f_ra_sense_d[1]);
            assert(la2_q == f_ra_sense_d[2]);
            assert(la3_q == f_ra_sense_d[3]);
            assert(la4_q == f_ra_sense_d[4]);
            assert(la5_q == f_ra_sense_d[5]);
            assert(la7_q == f_ra_sense_d[6]);
        end

        // ---- 8. Switch latch next-states (spec 5, independent decode) ----
        if (f_rst_d) begin
            // C00x shared latch: IOU-visible bits (spec 5.1)
            if (f_sel00($past(a6), $past(la5), $past(la4)) && $past(c0xx_n) == 1'b0
                && $past(la7) == 1'b0 && $past(q3) == 1'b0
                && $past(phi0) == 1'b1 && $past(rw) == 1'b0) begin
                case ($past(la[3:1]))
                    3'd0: assert(en80vid == $past(la0));
                    3'd6: assert(s80col  == $past(la0));
                    3'd7: assert(paymar  == $past(la0));
                    default: ;          // selects 1-5: no IOU-visible change
                endcase
            end
            // C05x video latch with IOUDIS gating (spec 5.2)
            if (f_sel05($past(a6), $past(la5), $past(la4)) && $past(c0xx_n) == 1'b0
                && $past(la7) == 1'b0 && $past(q3) == 1'b0
                && $past(phi0) == 1'b1 && $past(rw) == 1'b0) begin
                case ($past(la[3:1]))
                    3'd0: assert(itext == $past(la0));
                    3'd1: assert(mix   == $past(la0));
                    3'd2: assert(pg2   == $past(la0));
                    3'd3: assert(hires == $past(la0));
                    3'd4: assert(an0_q == ($past(ioudis) ? f_an0_d : $past(la0)));
                    3'd5: assert(an1_q == ($past(ioudis) ? f_an1_d : $past(la0)));
                    3'd6: assert(an2_q == ($past(ioudis) ? f_an2_d : $past(la0)));
                    3'd7: assert(an3_q == $past(la0));
                    default: assert(0);
                endcase
            end
            // C07E/C07F IOUDIS latch (spec 5.3, A5)
            if (f_sel07($past(a6), $past(la5), $past(la4)) && $past(c0xx_n) == 1'b0
                && $past(la7) == 1'b0 && $past(q3) == 1'b0
                && $past(phi0) == 1'b1 && $past(rw) == 1'b0
                && $past(la[3]) && $past(la[2]) && $past(la[1])) begin
                assert(ioudis == !$past(la0));
            end
        end

        // ---- 9. MD7 readback (spec 9) ----
        // OE: reads only, decoded ranges, LA7=0 and Q3=0 required.
        assert(md7_oe == (rw && !c0xx_n && !la7 && !q3 && (
              f_sel00(a6, la5, la4)
            | (f_sel01(a6, la5, la4) && ((la == 4'h0) || (la >= 4'h9)))
            | (f_sel07(a6, la5, la4) && la[3] && la[2] && la[1]
               && (!la[0] || ioudis)))));
        if (md7_oe) begin
            if (f_sel00(a6, la5, la4)) begin
                assert(md7 == key);
            end else if (f_sel01(a6, la5, la4)) begin
                case (la)
                    4'h0: assert(md7 == akd);
                    4'h9: assert(md7 == !f_vbl(cnt));
                    4'hA: assert(md7 == itext);
                    4'hB: assert(md7 == mix);
                    4'hC: assert(md7 == pg2);
                    4'hD: assert(md7 == hires);
                    4'hE: assert(md7 == paymar);
                    4'hF: assert(md7 == s80col);
                    default: assert(0);        // $C011-$C018 never OE
                endcase
            end else begin
                assert(md7 == (la[0] ? an3_q : !ioudis));
            end
        end
        // The MMU owns $C011-$C018: the IOU must stay off the bus there.
        if (f_sel01(a6, la5, la4) && rw && la >= 4'h1 && la <= 4'h8)
            assert(!md7_oe);

        // ---- 10. Keyboard (spec 5.4/8) ----
        // Transition checks need the previous edge out of reset (the RTL
        // clears its shift registers; the shadow pipeline does not).
        if (f_rst_d) begin
            if (f_rst_d2) begin
                assert(kstrb == f_ik_d2);
                assert(akd   == f_akd_d2);
            end
            if (!$past(akd))                      assert(!set_delay);
            else if ($past(strble))               assert(set_delay);
            if (!$past(akd) || $past(strble))     assert(n9 == 3'b000);
            else if ($past(ctc14s_q))
                assert(n9 == {$past(n9[1:0]), $past(set_delay)});
            if (!$past(akd) || $past(strble))     assert(!auto_active);
            else if ($past(n9[2]))                assert(auto_active);
            // KEY: set on KEYLE, clear on CLRKEY, hold when both.
            if ($past(keyle) && !$past(clrkey))       assert(key);
            else if ($past(clrkey) && !$past(keyle))  assert(!key);
        end

        // ---- 11. Speaker / cassette toggles (spec 5.5) ----
        if (f_rst_d) begin
            if ($past(sel_c03x)) assert(spkr  == !$past(spkr));
            else                 assert(spkr  == $past(spkr));
            if ($past(sel_c02x)) assert(casso == !$past(casso));
            else                 assert(casso == $past(casso));
        end

        // ---- 12. No response outside the IOU ranges (spec 4, A7) ----
        if (la7 || q3) begin
            assert(!md7_oe);
        end
    end
end

`endif
