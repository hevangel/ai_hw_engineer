// Apple IIe IOU self-checking testbench.
//
// The reference model below is an independent encoding of spec/spec.md (TRM
// Tables 7-7/7-9/7-13, the Sather p.5-9 fold, the frozen-signal ground-truth
// address sequences, the soft-switch and keyboard rules). Every cycle is
// compared against the model in four sample windows around the committing
// clock edge; the model state then updates with the same inputs.
//
// Cycle timeline (TCK = one PHI_0 period = one scanner state):
//   negedge: drive CPU half (phi0=1, row phase pras_n=1)
//   +TCK/4 : pre-edge checks (row phase; the decode sees the presented bus)
//   posedge: DUT and model commit (latch, switches, counter, keyboard)
//   +TCK/8 : column phase (decode sees the held latch)
//   phi0=0 : video half, pras_n 1 then 0; video outputs are checked against
//            the post-edge model state.

`timescale 1ns/1ps

module tb_top;

    localparam int TCK = 100;

    logic clk = 1'b0;
    always #(TCK/2) clk = ~clk;

    logic       rst_n;
    logic       phi0;
    logic       q3;
    logic       pras_n;
    logic       rw;
    logic       c0xx_n;
    logic       a6;
    logic       vid6;
    logic       vid7;
    logic       ikstrb;
    logic       iakd;
    logic [6:0] ra_sense;
    wire  [7:0] ra_o;
    wire        h0, sega, segb, vc, gr;
    wire        wndw_n, sync_n, clrgat_n;
    wire        ra9_n, ra10_n, s80vid_n;
    wire        spkr, casso, an0, an1, an2, an3;
    wire        kstrb, akd;
    wire        md7_oe, md7;

    apple_iie_iou dut (
        .clk, .rst_n, .phi0, .q3, .pras_n, .rw, .c0xx_n, .a6,
        .vid6, .vid7, .ikstrb, .iakd,
        .ra_sense, .ra_o,
        .h0, .sega, .segb, .vc, .gr,
        .wndw_n, .sync_n, .clrgat_n,
        .ra9_n, .ra10_n, .s80vid_n,
        .spkr, .casso, .an0, .an1, .an2, .an3,
        .kstrb, .akd,
        .md7_oe, .md7
    );

    // ------------------------------------------------------------------
    // Check accounting
    // ------------------------------------------------------------------
    int checks = 0;
    int errors = 0;

    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) begin
            errors++;
            $display("CHECK FAILED [%s] at %0t: cnt=%h ra_o=%h wndw=%b sync=%b clrgat=%b h0=%b sega=%b segb=%b vc=%b gr=%b ra9=%b ra10=%b s80=%b md7=%b/%b",
                     what, $time, dut.cnt, ra_o, wndw_n, sync_n, clrgat_n, h0,
                     sega, segb, vc, gr, ra9_n, ra10_n, s80vid_n, md7, md7_oe);
        end
    endtask

    // ------------------------------------------------------------------
    // Reference model (spec/spec.md encoding)
    // ------------------------------------------------------------------
    bit [20:0] r_cnt;
    bit        r_gr;
    bit        r_en80, r_80col, r_altch;          // C00x, IOU-used bits
    bit        r_itext, r_mix, r_pg2, r_hires;    // C05x
    bit [3:0]  r_an;                              // AN0..AN3 (AN3 = DHIRES)
    bit        r_ioudis;
    bit        r_spkr, r_casso;
    bit [1:0]  r_kstrb_sh, r_akd_sh;
    bit        r_kstrb_prev, r_m8_3, r_ctc14s_q;
    bit        r_set_delay, r_auto, r_key;
    bit [2:0]  r_n9;
    bit        r_tc14s;                           // pre-delay tick marker

    task automatic m_reset;
        r_cnt = 21'h1F0000;                       // spec A6
        r_gr = 0;
        r_en80 = 0; r_80col = 0; r_altch = 0;
        r_itext = 0; r_mix = 0; r_pg2 = 0; r_hires = 0;   // A4
        r_an = 4'b0000;
        r_ioudis = 0;                             // A4/A5
        r_spkr = 0; r_casso = 0;
        r_kstrb_sh = 0; r_akd_sh = 0; r_kstrb_prev = 0;
        r_m8_3 = 0; r_ctc14s_q = 0;
        r_set_delay = 0; r_n9 = 0; r_auto = 0; r_key = 0;
        r_tc14s = 0;
    endtask

    function automatic bit m_hbl;
        m_hbl = !((r_cnt[3] & r_cnt[4]) | r_cnt[5]);
    endfunction
    function automatic bit m_vblank;
        m_vblank = r_cnt[14] & r_cnt[13];
    endfunction

    function automatic bit [15:0] m_addr;
        bit [3:0]  s;
        bit [15:0] a;
        bit        ha;
        ha = r_gr && r_hires;
        s = 4'd1 + {(!r_cnt[5]), (!r_cnt[5]), r_cnt[4], r_cnt[3]}
              + {r_cnt[14], r_cnt[13], r_cnt[14], r_cnt[13]};
        a = 16'h0;
        a[2:0] = r_cnt[2:0];
        a[6:3] = s;
        a[9:7] = r_cnt[12:10];
        if (!ha) begin
            a[10] = r_en80 || !r_pg2;
            a[11] = !r_en80 && r_pg2;
        end else begin
            a[12:10] = r_cnt[9:7];
            a[13]    = r_en80 || !r_pg2;
            a[14]    = !r_en80 && r_pg2;
        end
        m_addr = a;
    endfunction

    function automatic bit [7:0] m_row_of(input bit [15:0] a16);
        m_row_of = {a16[8], a16[7], a16[5], a16[4],
                    a16[3], a16[2], a16[1], a16[0]};
    endfunction
    function automatic bit [7:0] m_col_of(input bit [15:0] a16);
        m_col_of = {a16[15], a16[14], a16[13], a16[12],
                    a16[11], a16[10], a16[6], a16[9]};
    endfunction

    // MD7 expectation for a presented C0xx access (spec 9).
    task automatic m_md7(input bit acc_i,
                         input bit [15:0] addr, input bit rw_i, input bit q3i,
                         output bit oe, output bit val);
        bit sel00, sel01, sel07;
        oe  = 1'b0;
        val = 1'b0;
        if (!acc_i || q3i || addr[7]) return;
        sel00 = !addr[6] && !addr[5] && !addr[4];
        sel01 = !addr[6] && !addr[5] &&  addr[4];
        sel07 =  addr[6] &&  addr[5] &&  addr[4];
        oe = rw_i && (sel00
            | (sel01 && ((addr[3:0] == 4'h0) || (addr[3:0] >= 4'h9)))
            | (sel07 && addr[3] && addr[2] && addr[1] && (!addr[0] || r_ioudis)));
        if (!oe) return;
        if (sel00) begin
            val = r_key;
        end else if (sel01) begin
            case (addr[3:0])
                4'h0: val = r_akd_sh[1];
                4'h9: val = !m_vblank();
                4'hA: val = r_itext;
                4'hB: val = r_mix;
                4'hC: val = r_pg2;
                4'hD: val = r_hires;
                4'hE: val = r_altch;
                4'hF: val = r_80col;
                default: val = 1'b0;
            endcase
        end else begin
            val = addr[0] ? r_an[3] : !r_ioudis;
        end
    endtask

    // Video-pin expectations from the current model state (spec 6/7).
    task automatic m_video_expect(output bit [7:0] exp_ra,
                                  output bit e_wndw, output bit e_sync,
                                  output bit e_clrgat, output bit e_h0,
                                  output bit e_sega, output bit e_segb,
                                  output bit e_vc, output bit e_gr,
                                  output bit e_ra9, output bit e_ra10,
                                  input bit pras_i);
        bit [15:0] a16;
        a16 = m_addr();
        exp_ra   = pras_i ? m_row_of(a16) : m_col_of(a16);
        e_wndw   = !(!((m_vblank()) | m_hbl()));
        e_sync   = !(((m_hbl()) & !r_cnt[2] & r_cnt[3])
                     | ((!r_cnt[11]) & r_cnt[12] & m_vblank()
                        & !r_cnt[10] & !r_cnt[9]
                        & (r_cnt[3] | r_cnt[4] | r_cnt[5])));
        e_clrgat = !((r_cnt[2] & r_cnt[3] & m_hbl()) && !r_itext);
        e_h0     = r_cnt[0];
        e_sega   = r_gr ? r_cnt[0] : r_cnt[7];
        e_segb   = r_gr ? !(r_gr && r_hires) : r_cnt[8];
        e_vc     = r_cnt[9];
        e_gr     = r_gr;
        e_ra9    = vid6 && (r_gr || r_altch || vid7);
        e_ra10   = (vid6 && !r_altch && !r_cnt[20] && !r_gr) || vid7;
    endtask

    // Model commit — same edge as the DUT. All comb quantities (strble,
    // akstb, keyle, clrkey) are formed from the pre-step state, matching the
    // RTL's pre-edge sampling.
    task automatic m_tick(input bit do_acc, input bit [15:0] addr,
                          input bit rw_i, input bit q3i,
                          input bit ik_i, input bit ak_i);
        bit [20:0] nxt;
        bit strble, akstb, keyle, clrkey, pakst_now, pre_tc14s;
        bit sel00, sel01, sel05, sel07, seldev02, seldev03;
        bit acc_en;

        // comb from the pre-step state
        pakst_now  = r_cnt[17];
        pre_tc14s  = (r_cnt[19:0] == 20'hFFFFF);
        strble     = r_kstrb_sh[1] && !r_kstrb_prev;
        akstb      = pakst_now && r_m8_3;
        keyle      = strble || (akstb && r_auto);

        // access decode
        acc_en  = do_acc && !q3i && !addr[7] && addr[15:8] == 8'hC0;
        sel00   = acc_en && !rw_i && !addr[6] && !addr[5] && !addr[4];
        sel01   = acc_en && !rw_i && !addr[6] && !addr[5] &&  addr[4];
        sel05   = acc_en && !rw_i &&  addr[6] && !addr[5] &&  addr[4];
        sel07   = acc_en && !rw_i &&  addr[6] &&  addr[5] &&  addr[4];
        seldev03 = acc_en && !addr[6] &&  addr[5] &&  addr[4];
        seldev02 = acc_en && !addr[6] &&  addr[5] && !addr[4];
        clrkey  = (acc_en && rw_i && !addr[6] && !addr[5] && addr[4]
                   && (addr[3:0] == 4'h0))
                || (acc_en && !rw_i && !addr[6] && !addr[5] && addr[4]);

        // registered graphics flag (pre-step counter bits)
        r_gr = !((r_mix && r_cnt[12] && r_cnt[14]) || r_itext);

        // counter
        nxt = r_cnt;
        if (!r_cnt[6]) nxt[6:0] = 7'd64;
        else           nxt = r_cnt + 21'd1;
        if (r_cnt[15:0] == 16'hFFFF) begin
            nxt[15]    = 1'b0;
            nxt[14:10] = 5'b11111;
            nxt[9]     = 1'b0;
            nxt[8]     = 1'b1;
        end
        r_cnt = nxt;
        r_tc14s = (r_cnt[19:0] == 20'hFFFFF);

        // soft switches
        if (sel00) begin
            case (addr[3:1])
                3'd0: r_en80  = addr[0];
                3'd6: r_80col = addr[0];
                3'd7: r_altch = addr[0];
                default: ;
            endcase
        end
        if (sel05) begin
            case (addr[3:1])
                3'd0: r_itext = addr[0];
                3'd1: r_mix   = addr[0];
                3'd2: r_pg2   = addr[0];
                3'd3: r_hires = addr[0];
                3'd4: if (!r_ioudis) r_an[0] = addr[0];
                3'd5: if (!r_ioudis) r_an[1] = addr[0];
                3'd6: if (!r_ioudis) r_an[2] = addr[0];
                3'd7: r_an[3] = addr[0];
                default: ;
            endcase
        end
        if (sel07 && addr[3] && addr[2] && addr[1]) r_ioudis = !addr[0];

        // devices
        if (seldev03) r_spkr  = !r_spkr;
        if (seldev02) r_casso = !r_casso;

        // keyboard
        r_kstrb_prev = r_kstrb_sh[1];            // pre-shift value (RTL: <=)
        r_kstrb_sh   = {r_kstrb_sh[0], ik_i};
        r_akd_sh     = {r_akd_sh[0], ak_i};
        r_m8_3       = !pakst_now;
        r_ctc14s_q   = pre_tc14s;
        if (!r_akd_sh[1])           r_set_delay = 1'b0;
        else if (strble)            r_set_delay = 1'b1;
        if (!r_akd_sh[1] || strble) r_n9 = 3'b000;
        else if (r_ctc14s_q)        r_n9 = {r_n9[1:0], r_set_delay};
        if (!r_akd_sh[1] || strble) r_auto = 1'b0;
        else if (r_n9[2])           r_auto = 1'b1;
        if (keyle && !clrkey)       r_key = 1'b1;
        else if (clrkey && !keyle)  r_key = 1'b0;
    endtask

    // ------------------------------------------------------------------
    // One clk period: present an optional C0xx access, check everything.
    // ------------------------------------------------------------------
    task automatic cycle(input bit do_acc = 1'b0,
                         input bit [15:0] addr = 16'hC000,
                         input bit rw_i = 1'b1, input bit q3i = 1'b0);
        bit oe_exp, val_exp;
        bit [7:0] e_ra;
        bit e_wndw, e_sync, e_clrgat, e_h0, e_sega, e_segb, e_vc, e_gr,
            e_ra9, e_ra10;

        // ---- CPU half, row phase ----
        @(negedge clk);
        phi0    = 1'b1;
        q3      = q3i;
        rw      = rw_i;
        c0xx_n  = (do_acc && addr[15:8] == 8'hC0) ? 1'b0 : 1'b1;
        a6      = addr[6];
        ra_sense = {addr[7], addr[5:0]};      // row byte: RA0-5 = A0-A5, RA6 = A7
        pras_n  = 1'b1;
        ikstrb  = m_ik_next;
        iakd    = m_ak_next;
        #(TCK/4);

        // pre-edge checks (row phase; decode sees the presented bus)
        m_md7(do_acc, addr, rw_i, q3i, oe_exp, val_exp);
        last_md7 = md7;
        check(md7_oe == oe_exp, "md7_oe row");
        if (oe_exp) check(md7 == val_exp,
                          $sformatf("md7 row addr=%h exp=%b [dut key=%b clrkey=%b keyle=%b strble=%b auto=%b akstb=%b]",
                                    addr, val_exp, dut.key, dut.clrkey, dut.keyle,
                                    dut.strble, dut.auto_active, dut.akstb));
        check(kstrb == r_kstrb_sh[1], "kstrb pre");
        check(akd == r_akd_sh[1], "akd pre");
        check(spkr == r_spkr, "spkr pre");
        check(casso == r_casso, "casso pre");
        check({an3, an2, an1, an0} == r_an, "an pre");
        check(s80vid_n == !r_80col, "s80vid pre");
        m_video_expect(e_ra, e_wndw, e_sync, e_clrgat, e_h0, e_sega, e_segb,
                       e_vc, e_gr, e_ra9, e_ra10, 1'b1);
        check(ra_o == e_ra, "video row pre");
        check(wndw_n == e_wndw, "wndw pre");
        check(sync_n == e_sync, "sync pre");
        check(clrgat_n == e_clrgat, "clrgat pre");
        check(h0 == e_h0, "h0 pre");
        check(sega == e_sega, "sega pre");
        check(segb == e_segb, "segb pre");
        check(vc == e_vc, "vc pre");
        check(gr == e_gr, "gr pre");
        check(ra9_n == e_ra9, "ra9 pre");
        check(ra10_n == e_ra10, "ra10 pre");

        // ---- commit ----
        @(posedge clk);
        m_tick(do_acc, addr, rw_i, q3i, m_ik_next, m_ak_next);

        // ---- CPU half, column phase (held latch) ----
        #(TCK/8);
        pras_n = 1'b0;
        #(TCK/8);
        m_md7(do_acc, addr, rw_i, q3i, oe_exp, val_exp);
        check(md7_oe == oe_exp, "md7_oe col");
        if (oe_exp) check(md7 == val_exp,
                          $sformatf("md7 col addr=%h exp=%b", addr, val_exp));
        check(spkr == r_spkr, "spkr post");
        check(casso == r_casso, "casso post");
        check({an3, an2, an1, an0} == r_an, "an post");

        // ---- video half ----
        phi0 = 1'b0;
        c0xx_n = 1'b1;
        pras_n = 1'b1;
        #(TCK/8);
        m_video_expect(e_ra, e_wndw, e_sync, e_clrgat, e_h0, e_sega, e_segb,
                       e_vc, e_gr, e_ra9, e_ra10, 1'b1);
        check(ra_o == e_ra, "video row post");
        check(wndw_n == e_wndw, "wndw post");
        check(sync_n == e_sync, "sync post");
        check(clrgat_n == e_clrgat, "clrgat post");
        check(h0 == e_h0, "h0 post");
        check(sega == e_sega, "sega post");
        check(segb == e_segb, "segb post");
        check(vc == e_vc, "vc post");
        check(gr == e_gr, "gr post");
        check(ra9_n == e_ra9, "ra9 post");
        check(ra10_n == e_ra10, "ra10 post");
        pras_n = 1'b0;
        #(TCK/16);
        m_video_expect(e_ra, e_wndw, e_sync, e_clrgat, e_h0, e_sega, e_segb,
                       e_vc, e_gr, e_ra9, e_ra10, 1'b0);
        check(ra_o == e_ra, "video col post");
        #(TCK/16);
    endtask

    // ------------------------------------------------------------------
    // Stimulus helpers
    // ------------------------------------------------------------------
    bit m_ik_next = 1'b0;    // ikstrb level for the next cycle
    bit m_ak_next = 1'b0;    // iakd level for the next cycle
    bit last_md7 = 1'b0;     // MD7 captured in the driven row phase

    task automatic switch_write(input bit [15:0] addr, input bit q3i = 1'b0);
        cycle(1'b1, addr, 1'b0, q3i);
    endtask
    task automatic flag_read(input bit [15:0] addr, output bit value);
        cycle(1'b1, addr, 1'b1, 1'b0);
        value = last_md7;
    endtask

    task automatic run_to(input bit [20:0] target);
        int guard = 0;
        // Match the frame position only (field + H); the FLASH/PAKST counter
        // bits 20:16 free-run and need not equal the target's.
        while ({9'b0, r_cnt[15:0]} != {9'b0, target[15:0]} && guard < 20000) begin
            cycle(1'b0);
            guard++;
        end
        if ({9'b0, r_cnt[15:0]} != {9'b0, target[15:0]})
            $fatal(1, "run_to: target %h not reached (r_cnt=%h)", target, r_cnt);
    endtask

    function automatic bit [20:0] cnt_at(input int line, input int h);
        cnt_at = 21'(((256 + line) << 7) | (64 + h));
    endfunction

    task automatic reset_chip;
        @(negedge clk);
        rst_n = 1'b0;
        phi0 = 0; q3 = 0; pras_n = 1; rw = 1; c0xx_n = 1; a6 = 0;
        ra_sense = 0; vid6 = 0; vid7 = 0; ikstrb = 0; iakd = 0;
        m_ik_next = 0; m_ak_next = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        m_reset();
        // Tick the model across the DUT's first post-reset edge so the
        // registered outputs (gr_q etc.) start in lockstep.
        @(posedge clk);
        m_tick(1'b0, 16'hC000, 1'b1, 1'b0, 1'b0, 1'b0);
        #(TCK/4);
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    bit v;
    int i;

    initial begin
        reset_chip();

        // 1. Reset state readbacks (PG2/HIRES cleared, flags 0, A4)
        flag_read(16'hC01C, v); check(v == 1'b0, "reset pg2");
        flag_read(16'hC01D, v); check(v == 1'b0, "reset hires");
        flag_read(16'hC01A, v); check(v == 1'b0, "reset text");
        flag_read(16'hC01B, v); check(v == 1'b0, "reset mixed");
        flag_read(16'hC01E, v); check(v == 1'b0, "reset altch");
        flag_read(16'hC01F, v); check(v == 1'b0, "reset 80col");
        flag_read(16'hC000, v); check(v == 1'b0, "reset key");
        flag_read(16'hC07E, v); check(v == 1'b1, "reset ioudis off");

        // 2. First frame (512 lines, A6) + one steady 262-line frame, text
        repeat (512 + 262) begin
            repeat (65) cycle(1'b0);
        end

        // 3. Text corner lines (spec 7.5 ground truth)
        run_to(cnt_at(0, 24));   cycle(1'b0);   // $0400
        run_to(cnt_at(7, 24));   cycle(1'b0);   // $0780
        run_to(cnt_at(8, 24));   cycle(1'b0);   // $0428
        run_to(cnt_at(15, 24));  cycle(1'b0);   // $07A8
        run_to(cnt_at(16, 24));  cycle(1'b0);   // $0450
        run_to(cnt_at(23, 24));  cycle(1'b0);   // $07D0

        // 4. Hires: lines 0/1, 8, 64, 191
        switch_write(16'hC057);
        run_to(cnt_at(0, 24));   cycle(1'b0);   // $2000
        run_to(cnt_at(1, 24));   cycle(1'b0);   // $2400
        run_to(cnt_at(8, 24));   cycle(1'b0);   // $2080
        run_to(cnt_at(64, 24));  cycle(1'b0);   // $2028
        run_to(cnt_at(191, 24)); cycle(1'b0);   // $3FF8 area
        switch_write(16'hC056);

        // 5. Text page 2 (main $800)
        switch_write(16'hC055);
        run_to(cnt_at(0, 24));   cycle(1'b0);
        run_to(cnt_at(9, 24));   cycle(1'b0);
        switch_write(16'hC054);

        // 6. 80STORE + PAGE2: aux $400 (A10=1, A11=0)
        switch_write(16'hC001);
        switch_write(16'hC055);
        run_to(cnt_at(0, 24));   cycle(1'b0);
        run_to(cnt_at(9, 24));   cycle(1'b0);
        switch_write(16'hC000);
        switch_write(16'hC054);

        // 7. Mixed + hires: graphics top, text bottom (L >= 160), GR skew
        switch_write(16'hC053);
        switch_write(16'hC057);
        run_to(cnt_at(158, 24)); cycle(1'b0);   // last graphics lines
        run_to(cnt_at(159, 24)); cycle(1'b0);
        run_to(cnt_at(160, 24)); cycle(1'b0);   // boundary: gr flips here
        run_to(cnt_at(161, 24)); cycle(1'b0);   // text region addresses
        run_to(cnt_at(175, 24)); cycle(1'b0);   // $400-based, row 21 = $780
        switch_write(16'hC052);
        switch_write(16'hC056);

        // 8. 80COL switch: 80VID' pin + C01F readback
        switch_write(16'hC00D);
        flag_read(16'hC01F, v); check(v == 1'b1, "80col on");
        check(s80vid_n == 1'b0, "80vid low");
        switch_write(16'hC00C);
        flag_read(16'hC01F, v); check(v == 1'b0, "80col off");
        check(s80vid_n == 1'b1, "80vid high");

        // 9. ALTCHAR: C01E readback + RA9'/RA10' gates
        vid6 = 1'b1; vid7 = 1'b0;
        switch_write(16'hC00F);
        flag_read(16'hC01E, v); check(v == 1'b1, "altch on");
        switch_write(16'hC00E);
        flag_read(16'hC01E, v); check(v == 1'b0, "altch off");

        // 10. Annunciators + IOUDIS/DHIRES (spec 5.2/5.3, A5)
        switch_write(16'hC05A); check(an1 == 1'b0, "an1 clr");
        switch_write(16'hC05D); check(an2 == 1'b1, "an2 set");
        switch_write(16'hC05C); check(an2 == 1'b0, "an2 clr");
        switch_write(16'hC059); check(an0 == 1'b1, "an0 set");
        switch_write(16'hC07E);                        // IOUDIS on
        flag_read(16'hC07E, v); check(v == 1'b0, "ioudis reads 0");
        switch_write(16'hC058); check(an0 == 1'b1, "AN0 clear gated");
        switch_write(16'hC05F); check(an3 == 1'b1, "dhires set");
        flag_read(16'hC07F, v); check(v == 1'b1, "dhires reads 1");
        switch_write(16'hC07F);                        // IOUDIS off
        flag_read(16'hC07E, v); check(v == 1'b1, "ioudis off reads 1");
        switch_write(16'hC058); check(an0 == 1'b0, "AN0 clear live");
        switch_write(16'hC05E); check(an3 == 1'b0, "an3 clr");

        // 11. Speaker / cassette toggles (read AND write)
        cycle(1'b1, 16'hC030, 1'b1);   // read toggles
        check(spkr == 1'b1, "spkr toggle 1");
        cycle(1'b1, 16'hC034, 1'b0);   // write toggles
        check(spkr == 1'b0, "spkr toggle 2");
        cycle(1'b1, 16'hC020, 1'b1);
        check(casso == 1'b1, "casso toggle 1");
        cycle(1'b1, 16'hC02F, 1'b0);
        check(casso == 1'b0, "casso toggle 2");

        // 12. Q3 gating: a switch write with Q3=1 is ignored
        switch_write(16'hC051, 1'b1);  // TEXT on with Q3 high
        flag_read(16'hC01A, v); check(v == 1'b0, "q3-gated write ignored");
        switch_write(16'hC051);        // now lands
        flag_read(16'hC01A, v); check(v == 1'b1, "text on");
        switch_write(16'hC050);
        flag_read(16'hC01A, v); check(v == 1'b0, "text off");

        // 13. LA7 gating: $C0D0-range write (LA7=1) is dead
        switch_write(16'hC0D1);
        flag_read(16'hC01F, v); check(v == 1'b0, "la7 write dead");
        // The MMU-owned flag reads: the IOU never drives MD7 there.
        flag_read(16'hC013, v); check(md7_oe == 1'b0, "C013 IOU oe off");

        // 14. Keyboard flow (spec 5.4/8)
        iakd = 1'b1; m_ak_next = 1'b1;
        ikstrb = 1'b1; m_ik_next = 1'b1;
        cycle(1'b0);
        ikstrb = 1'b0; m_ik_next = 1'b0;
        cycle(1'b0);
        check(kstrb == 1'b1, "kstrb pulse");       // 2-cycle retime
        cycle(1'b0);
        check(kstrb == 1'b0, "kstrb pulse ends");
        check(akd == 1'b1, "akd retimed");
        flag_read(16'hC000, v); check(v == 1'b1, "key set by strobe");
        cycle(1'b1, 16'hC010, 1'b0);               // C010 write clears
        flag_read(16'hC000, v); check(v == 1'b0, "key cleared by C010 write");
        flag_read(16'hC010, v); check(v == 1'b1, "C010 read = AKD");
        cycle(1'b1, 16'hC010, 1'b0);
        flag_read(16'hC000, v); check(v == 1'b0, "key cleared again");
        // C008-C00F readback quirk (A9): strobe flag on any C00x read
        ikstrb = 1'b1; m_ik_next = 1'b1;
        cycle(1'b0);
        ikstrb = 1'b0; m_ik_next = 1'b0;
        cycle(1'b0);
        cycle(1'b0);
        flag_read(16'hC008, v); check(v == 1'b1, "C008 read returns KEY");
        cycle(1'b1, 16'hC010, 1'b0);

        // 15. Auto-repeat: hold the key, 3 CTC14S ticks, then PAKST re-strobes
        iakd = 1'b1; m_ak_next = 1'b1;
        ikstrb = 1'b1; m_ik_next = 1'b1;
        cycle(1'b0);
        ikstrb = 1'b0; m_ik_next = 1'b0;
        repeat (3) begin
            while (!r_tc14s) cycle(1'b0);
            cycle(1'b0);
        end
        i = 0;
        while (!r_auto && i < 40) begin cycle(1'b0); i++; end
        check(r_auto == 1'b1, "auto-repeat active");
        // wait for a PAKST rising edge with auto active: KEY re-sets
        cycle(1'b1, 16'hC010, 1'b0);               // clear the flag first
        i = 0;
        v = 1'b0;
        while (i < 300000 && !v) begin
            flag_read(16'hC000, v);
            i++;
        end
        check(v == 1'b1, "auto-repeat re-strobes KEY");
        iakd = 0; m_ak_next = 0;
        repeat (4) cycle(1'b0);
        check(r_auto == 1'b0, "auto-repeat cleared on key-up");

        // 16. Random soak
        for (i = 0; i < 20000; i++) begin
            bit do_acc;
            bit [15:0] addr;
            bit rw_i;
            do_acc = (1'($urandom_range(0, 9)) != 1'b0);
            addr   = 16'hC000 + 16'($urandom_range(0, 8'hFF));
            rw_i   = 1'($urandom_range(0, 1));
            m_ik_next = (32'($urandom_range(0, 999)) == 0);
            m_ak_next = (1'($urandom_range(0, 3)) != 1'b0);
            vid6 = 1'($urandom_range(0, 1));
            vid7 = 1'($urandom_range(0, 1));
            cycle(do_acc, addr, rw_i, 1'($urandom_range(0, 15)) == 1'b1);
        end
        m_ik_next = 0; m_ak_next = 0;

        if (errors == 0)
            $display("Apple IIe IOU TEST PASSED checks=%0d", checks);
        else
            $fatal(1, "Apple IIe IOU TEST FAILED errors=%0d checks=%0d", errors, checks);
        $finish;
    end

    // Watchdog
    initial begin
        #1_500_000_000;   // 1.5 ms sim time; the TB needs ~0.4 ms (A: 3.5M cycles)
        $fatal(1, "Apple IIe IOU TEST TIMEOUT");
    end
endmodule
