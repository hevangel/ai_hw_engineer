// Apple IIe IOU cover properties (non-vacuity).
// Included under `ifdef FORMAL (active only when FORMAL_COVER is also
// defined, per the .sby cover task). With the anyconst scanner start state
// these prove the property set is exercised across the whole counter space;
// deep from-reset frame reachability is the simulation's job (testplan).

`ifdef FORMAL_COVER

always_ff @(posedge clk) begin
    if (rst_n && f_past_valid) begin
        // --- display map corners (spec 7.5) ---
        // Band 0 (row block 0): text row 0 at $400
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && !cnt[14] && !cnt[13] && cnt[12:10] == 3'd0
              && !f_hbl(cnt) && f_exp_addr == 16'h0400);
        // Text row 7 ($780): band 7 of pass 0
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && !cnt[14] && !cnt[13] && cnt[12:10] == 3'd7
              && cnt[2:0] == 3'd0 && !f_hbl(cnt) && f_exp_addr == 16'h0780);
        // Text row 8 ($428): band 0 of pass 1 (V3=1)
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && !cnt[14] && cnt[13] && cnt[12:10] == 3'd0
              && cnt[2:0] == 3'd0 && !f_hbl(cnt) && f_exp_addr == 16'h0428);
        // Text row 15 ($7A8)
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && !cnt[14] && cnt[13] && cnt[12:10] == 3'd7
              && cnt[2:0] == 3'd0 && !f_hbl(cnt) && f_exp_addr == 16'h07A8);
        // Text row 16 ($450): pass 2 (V4=1)
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && cnt[14] && !cnt[13] && cnt[12:10] == 3'd0
              && cnt[2:0] == 3'd0 && !f_hbl(cnt) && f_exp_addr == 16'h0450);
        // Text row 23 ($7D0)
        cover(rst_n && f_past_valid && !gr_q && !hires && cnt[15]
              && cnt[14] && !cnt[13] && cnt[12:10] == 3'd7
              && cnt[2:0] == 3'd0 && !f_hbl(cnt) && f_exp_addr == 16'h07D0);
        // Hires line 0 ($2000)
        cover(rst_n && f_past_valid && gr_q && hires && cnt[15]
              && !cnt[14] && !cnt[13] && cnt[12:10] == 3'd0
              && cnt[9:7] == 3'd0 && cnt[2:0] == 3'd0 && !f_hbl(cnt)
              && f_exp_addr == 16'h2000);
        // Hires line 1 ($2400): VA=1 (cnt[7]), VB=VC=0
        cover(rst_n && f_past_valid && gr_q && hires && cnt[15]
              && !cnt[14] && !cnt[13] && cnt[12:10] == 3'd0
              && cnt[7] && !cnt[8] && !cnt[9] && cnt[2:0] == 3'd0
              && !f_hbl(cnt) && f_exp_addr == 16'h2400);
        // Hires line 8 ($2080): group 1
        cover(rst_n && f_past_valid && gr_q && hires && cnt[15]
              && !cnt[14] && !cnt[13] && cnt[12:10] == 3'd1
              && cnt[9:7] == 3'd0 && cnt[2:0] == 3'd0 && !f_hbl(cnt)
              && f_exp_addr == 16'h2080);
        // Hires line 64 ($2028): pass 1
        cover(rst_n && f_past_valid && gr_q && hires && cnt[15]
              && !cnt[14] && cnt[13] && cnt[12:10] == 3'd0
              && cnt[9:7] == 3'd0 && cnt[2:0] == 3'd0 && !f_hbl(cnt)
              && f_exp_addr == 16'h2028);
        // Hires line 191 ($3FF8-ish corner: group 7 of pass 2, col 0)
        cover(rst_n && f_past_valid && gr_q && hires && cnt[15]
              && cnt[14] && !cnt[13] && cnt[12:10] == 3'd7
              && cnt[9:7] == 3'd7 && cnt[2:0] == 3'd0 && !f_hbl(cnt));

        // --- windows / timing (spec 6) ---
        cover(!cnt[6]);                                        // HPE' reload state
        cover(cnt[15:0] == 16'hFFFF);                          // TC pending
        cover(cnt[15] && f_vbl(cnt) && f_hbl(cnt));            // double blank
        cover(hbl && !cnt[2] && cnt[3] && !sync_n);            // horizontal sync
        cover(cnt[14] && cnt[13] && cnt[12] && !cnt[11] && !cnt[10]
              && !cnt[9] && (cnt[3] | cnt[4] | cnt[5]) && !sync_n);  // vsync serration
        cover(cnt[2] && cnt[3] && f_hbl(cnt) && !itext && !clrgat_n); // burst window
        cover(cnt[15] && !f_vbl(cnt) && f_hbl(cnt)
              && !gr_q && !hires && f_exp_addr[6:3] == 4'd13
              && f_exp_addr[2:0] == 3'b000);                   // start-of-line +0x68

        // --- page/mode bit corners (Table 7-13) ---
        cover(pg2 && !en80vid && cnt[15] && !f_vbl(cnt) && !f_hbl(cnt)
              && !gr_q && f_exp_addr[11]);                     // main $800 text page 2
        cover(pg2 && en80vid && cnt[15] && !f_vbl(cnt) && !f_hbl(cnt)
              && !gr_q && f_exp_addr[10]);                     // 80-store'd page 2 = aux $400
        cover(pg2 && !en80vid && gr_q && hires && cnt[15]
              && !f_vbl(cnt) && !f_hbl(cnt) && f_exp_addr[14]); // hires page 2 aux

        // --- MD7 readbacks (spec 9) ---
        cover(md7_oe && sel_c00x && md7 == key);               // keyboard strobe flag
        cover(md7_oe && sel_c01x && la == 4'h0);               // $C010 AKD
        cover(md7_oe && la == 4'h9 && vbl_n);                  // $C019 not blanked
        cover(md7_oe && la == 4'h9 && !vbl_n);                 // $C019 blanked
        cover(md7_oe && la == 4'hF);                           // $C01F 80COL
        cover(md7_oe && la[3] && la[2] && la[1] && !la[0]);    // $C07E !IOUDIS
        cover(md7_oe && la[3] && la[2] && la[1] && la[0] && ioudis); // $C07F DHIRES
        cover(ioudis);                                         // IOUDIS latched on
        cover(sel_c07x && wr_act && la[3] && la[2] && la[1] && !la[0]); // C07E write

        // --- keyboard flow (spec 8) ---
        cover(strble);                                         // retimed strobe pulse
        // NOTE: the full auto-repeat re-strobe (keyle && !strble) needs three
        // CTC14S ticks = 3*2^20 cycles and is simulation-verified only; the
        // formal covers the local pieces (delay armed, tick observed).
        cover(clrkey && key);                                  // strobe clear on $C010
        cover(set_delay && akd && !strble);                    // delay armed
        cover(ctc14s_q && akd && set_delay);                   // N9 tick (one tick;
                                                               //  full 3-tick activation is sim-only)
        // --- switches / devices (spec 5) ---
        cover(ioudis && sel_c05x && wr_act && la[3:1] == 3'd4); // gated AN0 write
        cover(!ioudis && sel_c05x && wr_act && la[3:1] == 3'd7); // AN3 write
        cover(ioudis && sel_c05x && wr_act && la[3:1] == 3'd7); // DHIRES write
        cover(sel_c03x && spkr);                               // speaker toggled high
        cover(sel_c02x && casso);                              // cassette toggled high
    end
end

`endif
