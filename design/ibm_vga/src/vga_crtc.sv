// IBM VGA CRT controller (VGAXGA p.2-55 to 2-77, HITR p.51-73).
//
// Copied from ega_crtc.sv and extended to the VGA: all 25 registers
// readable, the Protect bit, HT+5 characters per line, 10-bit vertical
// values, 6-bit horizontal blank end, 8-bit vertical blank end, double
// scan, doubleword addressing and count by 4, cursor off, byte panning.
// No light pen (indices 10h/11h are the retrace registers).
//
// At each character boundary (char_ce) the flags of the current character
// are presented combinationally (f_*) with the display address, and the
// counters then advance (spec "CRTC timing").
module vga_crtc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        reset_drv,
    input  logic        addr_we,
    input  logic        data_we,
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata_idx,      // 3x4 read
    output logic [7:0]  rdata,          // 3x5 read
    input  logic        char_ce,
    output logic        f_de,
    output logic        f_blank,
    output logic        f_hs,
    output logic        f_cursor,
    output logic        f_ul,
    output logic        f_hcodd,
    output logic        vs_line,        // vertical retrace state
    output logic [15:0] disp_addr,
    output logic [4:0]  rs,
    output logic        vint,
    output logic        vrtc_start,     // with char_ce: vertical retrace starts now
    output logic        lc_hit,         // with char_ce: line compare matches now
    output logic [1:0]  de_skew,
    output logic [1:0]  cur_skew,
    output logic [1:0]  hr_delay,
    output logic        retrace_en,
    output logic [199:0] dbg_regs,
    output logic [4:0]  idx
);
    logic [7:0] regs [0:24];
    always_comb
        for (int i = 0; i < 25; i++) dbg_regs[8*i +: 8] = regs[i];

    logic [8:0]  hc;
    logic [9:0]  vc;
    logic [15:0] ma, row_start;
    logic        hb_q, hs_q, vb_q, vdiv, dphase;

    // register fields (Figure 2-48, 2-50)
    logic [9:0] vt, vde, vrs, vbs, lc;
    logic [15:0] start_addr, cursor_loc;
    assign vt  = {regs[7][5], regs[7][0], regs[6]};
    assign vde = {regs[7][6], regs[7][1], regs[5'h12]};
    assign vrs = {regs[7][7], regs[7][2], regs[5'h10]};
    assign vbs = {regs[9][5], regs[7][3], regs[5'h15]};
    assign lc  = {regs[9][6], regs[7][4], regs[5'h18]};
    assign start_addr = {regs[5'h0C], regs[5'h0D]};
    assign cursor_loc = {regs[5'h0E], regs[5'h0F]};
    assign de_skew  = regs[3][6:5];
    assign cur_skew = regs[5'h0B][6:5];
    assign hr_delay = regs[5][6:5];
    assign retrace_en = regs[5'h17][7];

    // ASSUMPTION V7: bits marked "Set to 0" are not stored
    logic [7:0] wmask;
    always_comb begin
        unique case (idx)
            5'h08:   wmask = 8'h7F;
            5'h0A:   wmask = 8'h3F;
            5'h0B:   wmask = 8'h7F;
            5'h14:   wmask = 8'h7F;
            5'h17:   wmask = 8'hEF;
            default: wmask = 8'hFF;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 5'd0;
`ifndef FORMAL
            for (int i = 0; i < 25; i++) regs[i] <= 8'h00;
`endif
        end else begin
            if (addr_we) idx <= wdata[4:0];
            if (data_we && idx <= 5'd24) begin
                // p.2-70: Protect blocks 00-07 except Overflow bit 4
                if (regs[5'h11][7] && idx <= 5'd7) begin
                    if (idx == 5'd7) regs[7] <= {regs[7][7:5], wdata[4], regs[7][3:0]};
                end else begin
                    regs[idx] <= wdata & wmask;
                end
            end
        end
    end

    assign rdata_idx = {3'd0, idx};
    assign rdata = (idx <= 5'd24) ? regs[idx] : 8'h00;     // ASSUMPTION V7

    // ------------------------------------------- current character flags
    logic hb_cur, hs_cur;
    logic [5:0] ehb;
    assign ehb = {regs[5][7], regs[3][4:0]};
    assign hb_cur = (hc == {1'b0, regs[2]}) || (hb_q && (hc[5:0] != ehb));
    assign hs_cur = (hc == {1'b0, regs[4]}) || (hs_q && (hc[4:0] != regs[5][4:0]));

    assign f_de     = (hc <= {1'b0, regs[1]}) && (vc <= vde);
    assign f_blank  = hb_cur || vb_q;
    assign f_hs     = hs_cur;
    // ASSUMPTION V25 (EGA E16): cursor rows CS <= rs < CE, off by 0A bit 5
    assign f_cursor = (ma == cursor_loc) && !regs[5'h0A][5] &&
                      (rs >= regs[5'h0A][4:0]) && (rs < regs[5'h0B][4:0]);
    assign f_ul     = (rs == regs[5'h14][4:0]);
    assign f_hcodd  = hc[0];

    // Output multiplexer (Figure 2-65) and row-scan substitution.
    always_comb begin
        if (regs[5'h14][6])      disp_addr = {ma[13:0], ma[13:12]};
        else if (!regs[5'h17][6]) disp_addr = {ma[14:0], regs[5'h17][5] ? ma[15] : ma[13]};
        else                     disp_addr = ma;
        if (!regs[5'h17][0]) disp_addr[13] = rs[0];
        if (!regs[5'h17][1]) disp_addr[14] = rs[1];
    end

    // ----------------------------------------------------- counter step
    logic        adv_line, go_line, restart, rs_tick, lc_now;
    logic [9:0]  vc_n;
    logic [4:0]  rs_n;
    logic [15:0] rs_row_n;
    logic        vb_n, vs_n, dphase_n;
    logic [8:0]  hc_n;
    logic [15:0] ma_n;

    // EGA E13: the vertical counter advances where horizontal retrace starts
    assign adv_line = (hc == {1'b0, regs[4]});
    assign go_line  = adv_line && (!regs[5'h17][2] || vdiv);
    assign restart  = (vc == vt + 10'd1);
    assign lc_now   = !restart && (vc == lc);

    always_comb begin
        vc_n = vc;
        rs_n = rs;
        rs_row_n = row_start;
        dphase_n = dphase;
        rs_tick = 1'b0;
        if (restart) begin
            // VT+2 lines per frame (p.2-61)
            vc_n = 10'd0;
            rs_n = regs[8][4:0];
            rs_row_n = start_addr + {14'd0, regs[8][6:5]};   // ASSUMPTION V11
            dphase_n = 1'b0;
        end else begin
            vc_n = vc + 10'd1;
            // ASSUMPTION V9: double scan divides the row-scan clock by 2
            rs_tick = !regs[9][7] || dphase;
            dphase_n = regs[9][7] ? !dphase : 1'b0;
            if (rs_tick) rs_n = (rs == regs[9][4:0]) ? 5'd0 : rs + 5'd1;
            if (lc_now) begin
                rs_row_n = 16'd0;                         // screen B (p.2-103)
                dphase_n = 1'b0;
            end else if (rs_tick && rs == regs[9][4:0]) begin
                rs_row_n = row_start + {7'd0, regs[5'h13], 1'b0};
            end
        end
        // ASSUMPTION V10: blank end on 8 bits, retrace end on 4 bits
        vb_n = (vc_n == vbs) || (vb_q && (vc_n[7:0] != regs[5'h16]));
        vs_n = (vc_n == vrs) || (vs_line && (vc_n[3:0] != regs[5'h11][3:0]));
    end

    // combinational so that the attribute controller's blink counter and
    // panning reset take effect for the character of this boundary
    assign vrtc_start = rst_n && !reset_drv && char_ce && go_line && vs_n && !vs_line;
    assign lc_hit     = rst_n && !reset_drv && char_ce && go_line && lc_now;

    assign hc_n = (hc == {1'b0, regs[0]} + 9'd4) ? 9'd0 : hc + 9'd1;   // HT+5 (p.2-56)
    always_comb begin
        if (hc_n == 9'd0)                       ma_n = go_line ? rs_row_n : row_start;
        else if (regs[5'h14][5])                ma_n = (hc[1:0] == 2'd3) ? ma + 16'd1 : ma;
        else if (!regs[5'h17][3] || hc[0])      ma_n = ma + 16'd1;
        else                                    ma_n = ma;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || reset_drv) begin
            // ASSUMPTION V2 (EGA E2): RESET DRV holds the counters
            hc <= 9'd0; vc <= 10'd0; rs <= 5'd0;
            ma <= 16'd0; row_start <= 16'd0;
            hb_q <= 1'b0; hs_q <= 1'b0; vb_q <= 1'b0; vs_line <= 1'b0;
            vdiv <= 1'b0; vint <= 1'b0; dphase <= 1'b0;
        end else begin
            if (char_ce) begin
                hb_q <= hb_cur;
                hs_q <= hs_cur;
                if (adv_line) begin
                    if (regs[5'h17][2]) vdiv <= !vdiv;
                    if (go_line) begin
                        vc <= vc_n;
                        rs <= rs_n;
                        row_start <= rs_row_n;
                        dphase <= dphase_n;
                        vb_q <= vb_n;
                        vs_line <= vs_n;
                        if (vs_n && !vs_line) begin
                            if (!regs[5'h11][5] && regs[5'h11][4]) vint <= 1'b1;
                        end
                    end
                end
                hc <= hc_n;
                ma <= ma_n;
            end
            // p.2-70: Vertical Retrace End bit 4 = 0 clears the interrupt
            if (!regs[5'h11][4]) vint <= 1'b0;
        end
    end
`ifdef FORMAL
    // Formal checks (formal/vga_crtc.sby). Registers are arbitrary
    // constants (no reset of regs under FORMAL, no data write).
    logic f_init = 1'b1;
    always_ff @(posedge clk) f_init <= 1'b0;
    always_comb begin
        if (f_init) assume (!rst_n);
        assume (!data_we);
        assume (!reset_drv);
    end
    logic [8:0] f_ht5;
    logic [5:0] f_hw;
    logic [4:0] f_vw;
    assign f_ht5 = {1'b0, regs[0]} + 9'd5;
    assign f_hw  = ((regs[5][4:0] - regs[4][4:0]) == 5'd0) ? 6'd32
                 : {1'b0, regs[5][4:0] - regs[4][4:0]};
    assign f_vw  = ((regs[5'h11][3:0] - vrs[3:0]) == 4'd0) ? 5'd16
                 : {1'b0, regs[5'h11][3:0] - vrs[3:0]};

`ifdef FORMAL_PROVE_H
    always_comb begin
        assume (regs[0] <= 8'd48);
        assume ({1'b0, regs[4]} + 9'd33 <= f_ht5);
        assume (vt <= 10'd3);
    end
`elsif FORMAL_PROVE_V
    always_comb begin
        assume (regs[0] <= 8'd2);
        assume (vt <= 10'd30);
        assume (vrs + 10'd17 <= vt);
        assume (!regs[5'h17][2]);
    end
`else
    always_comb begin
        assume (regs[0] <= 8'd3);
        assume (vt <= 10'd5);
    end
`endif

    logic [6:0] f_hcnt;
    logic [5:0] f_vcnt;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            f_hcnt <= 7'd0;
            f_vcnt <= 6'd0;
        end else if (char_ce) begin
            if (hs_cur) f_hcnt <= (hs_q ? f_hcnt : 7'd0) + 7'd1;
            if (go_line && vs_n) f_vcnt <= (vs_line ? f_vcnt : 6'd0) + 6'd1;
        end
    end

    always_comb begin
        if (rst_n && !f_init) begin
            assert (hc < f_ht5);
            assert (vc <= vt + 10'd1);
`ifdef FORMAL_PROVE_H
            if (char_ce && hs_q && !hs_cur) assert (f_hcnt == {1'b0, f_hw});
            assert (f_hcnt <= 7'd32);
            if (hs_q) assert ({2'b00, f_hcnt} == hc - {1'b0, regs[4]});
            if (hs_q) assert (hc > {1'b0, regs[4]});
            if (hs_q) assert (f_hcnt <= {1'b0, f_hw});
`endif
`ifdef FORMAL_PROVE_V
            if (char_ce && go_line && vs_line && !vs_n) assert (f_vcnt == {1'b0, f_vw});
            if (vs_line) assert ({4'd0, f_vcnt} == vc - vrs + 10'd1);
            if (vs_line) assert (vc >= vrs);
            if (vs_line) assert (f_vcnt <= {1'b0, f_vw});
`endif
            if (!regs[5'h11][4]) assert (!vint);
            // double scan: without bit 7 the phase stays 0
            if (!regs[9][7]) assert (!dphase);
        end
    end

    always_ff @(posedge clk) begin
        if ($past(rst_n) && rst_n && !f_init) begin
            if (vint && !$past(vint))
                assert ($past(vs_n && !vs_line && go_line && char_ce) && !$past(regs[5'h11][5]));
            if (vs_line && !$past(vs_line)) assert (vc == vrs);
            // the row scan changes only at a row-scan tick or a frame restart
            if (rs != $past(rs)) assert ($past(char_ce && go_line && (rs_tick || restart)));
`ifdef FORMAL_COVER
            cover ($past(vc) == vt + 10'd1 && vc == 10'd0 && $past(go_line));
            cover ($past(vrtc_start) && vint);
            cover (regs[9][7] && rs == 5'd1 && vc == 10'd3);
`endif
        end
    end
`endif
endmodule
