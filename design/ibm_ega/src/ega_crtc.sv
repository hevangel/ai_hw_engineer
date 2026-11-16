// IBM EGA CRT controller LSI (U32, TR p.24-44, sheet 3).
//
// Not an MC6845: 25 registers with horizontal/vertical blanking start and
// end, retrace delay and skews, a 9-bit vertical counter with an overflow
// register, preset row scan, line compare (split screen), underline row,
// a mode control register (word/byte address output, count by two, row-scan
// substitution for MA13/MA14, HRTC/2), light-pen latch and the vertical
// interrupt. Read/write: 0Ch-0Fh; read only: light pen 10h/11h.
//
// At each character boundary (char_ce) the flags of the current character
// are presented combinationally (f_*) together with the display address,
// and the counters then advance (spec "CRTC timing").
module ega_crtc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        reset_drv,
    // processor
    input  logic        addr_we,
    input  logic        data_we,
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata,          // 3x5 read value
    // timing
    input  logic        char_ce,
    input  logic        lpff,           // light-pen flip-flop (U18)
    // current-character flags (valid with char_ce)
    output logic        f_de,
    output logic        f_blank,
    output logic        f_hs,
    output logic        f_cursor,
    output logic        f_ul,
    output logic        f_hcodd,
    output logic        vs_line,        // vertical retrace state (status, F.vs)
    output logic [15:0] disp_addr,      // MA through the output multiplexer
    output logic [4:0]  rs,
    output logic        vint,           // vertical interrupt latch (CRTINT)
    output logic        vrtc_start,     // pulse: vertical retrace started
    output logic [1:0]  de_skew,
    output logic [1:0]  cur_skew,
    output logic [1:0]  hr_delay,
    output logic        retrace_en,     // Mode Control bit 7
    output logic [199:0] dbg_regs,      // register 24..0, 8 bits each
    output logic [4:0]  idx,
    output logic [15:0] lp
);
    logic [7:0] regs [0:24];
    always_comb
        for (int i = 0; i < 25; i++) dbg_regs[8*i +: 8] = regs[i];

    logic [8:0]  hc;
    logic [9:0]  vc;
    logic [15:0] ma, row_start;
    logic        hb_q, hs_q, vb_q, vdiv;
    logic        lp_prev;

    // register fields
    logic [8:0] vt, vde, vrs, vbs, lc;
    logic [15:0] start_addr, cursor_loc;
    assign vt  = {regs[7][0], regs[6]};
    assign vde = {regs[7][1], regs[5'h12]};
    assign vrs = {regs[7][2], regs[5'h10]};
    assign vbs = {regs[7][3], regs[5'h15]};
    assign lc  = {regs[7][4], regs[5'h18]};
    assign start_addr = {regs[5'h0C], regs[5'h0D]};
    assign cursor_loc = {regs[5'h0E], regs[5'h0F]};
    assign de_skew  = regs[3][6:5];
    assign cur_skew = regs[5'h0B][6:5];
    assign hr_delay = regs[5][6:5];
    assign retrace_en = regs[5'h17][7];

    // ---------------------------------------------------------- registers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 5'd0;
`ifndef FORMAL
            for (int i = 0; i < 25; i++) regs[i] <= 8'h00;
`endif
        end else begin
            if (addr_we) idx <= wdata[4:0];
            if (data_we && idx <= 5'd24) regs[idx] <= wdata;
        end
    end

    // ASSUMPTION E4: write-only indices read FFh (BD bus pull-ups).
    always_comb begin
        unique case (idx)
            5'h0C, 5'h0D, 5'h0E, 5'h0F: rdata = regs[idx];
            5'h10:  rdata = lp[15:8];
            5'h11:  rdata = lp[7:0];
            default: rdata = 8'hFF;
        endcase
    end

    // ------------------------------------------- current character flags
    logic hb_cur, hs_cur;
    assign hb_cur = (hc == {1'b0, regs[2]}) || (hb_q && (hc[4:0] != regs[3][4:0]));
    assign hs_cur = (hc == {1'b0, regs[4]}) || (hs_q && (hc[4:0] != regs[5][4:0]));

    assign f_de     = (hc <= {1'b0, regs[1]}) && (vc <= {1'b0, vde});
    assign f_blank  = hb_cur || vb_q;
    assign f_hs     = hs_cur;
    // ASSUMPTION E16: cursor rows CS <= rs < CE; underline row rs == UL.
    assign f_cursor = (ma == cursor_loc) && (rs >= regs[5'h0A][4:0]) && (rs < regs[5'h0B][4:0]);
    assign f_ul     = (rs == regs[5'h14][4:0]);
    assign f_hcodd  = hc[0];

    // Output multiplexer (TR p.43) and row-scan substitution (TR p.41-42).
    always_comb begin
        if (regs[5'h17][6]) disp_addr = ma;
        else       disp_addr = {ma[14:0], regs[5'h17][5] ? ma[15] : ma[13]};
        if (!regs[5'h17][0]) disp_addr[13] = rs[0];
        if (!regs[5'h17][1]) disp_addr[14] = rs[1];
    end

    // ----------------------------------------------------- counter step
    logic        adv_line, go_line;
    logic [9:0]  vc_n;
    logic [4:0]  rs_n;
    logic [15:0] rs_row_n;
    logic        vb_n, vs_n;
    logic [8:0]  hc_n;
    logic [15:0] ma_n;

    // ASSUMPTION E13: the vertical counter is clocked where horizontal
    // retrace starts, every time or every second time (Mode Control bit 2).
    assign adv_line = (hc == {1'b0, regs[4]});
    assign go_line  = adv_line && (!regs[5'h17][2] || vdiv);

    always_comb begin
        vc_n = vc;
        rs_n = rs;
        rs_row_n = row_start;
        if ({1'b0, vc} == {1'b0, vt} + 11'd1) begin
            // ASSUMPTION E8: VT+2 lines (vc runs 0..VT+1)
            vc_n = 10'd0;
            rs_n = regs[8][4:0];
            rs_row_n = start_addr;
        end else begin
            vc_n = vc + 10'd1;
            rs_n = (rs == regs[9][4:0]) ? 5'd0 : rs + 5'd1;
            if (vc == {1'b0, lc})
                rs_row_n = 16'd0;                      // ASSUMPTION E14
            else if (rs == regs[9][4:0])
                rs_row_n = row_start + {7'd0, regs[5'h13], 1'b0};
        end
        vb_n = (vc_n == {1'b0, vbs}) || (vb_q && (vc_n[4:0] != regs[5'h16][4:0]));
        vs_n = (vc_n == {1'b0, vrs}) || (vs_line && (vc_n[3:0] != regs[5'h11][3:0]));
    end

    assign hc_n = (hc == {1'b0, regs[0]} + 9'd1) ? 9'd0 : hc + 9'd1;
    always_comb begin
        if (hc_n == 9'd0)               ma_n = (go_line ? rs_row_n : row_start) + {15'd0, regs[5][7]};
        else if (!regs[5'h17][3] || hc[0])       ma_n = ma + 16'd1;
        else                            ma_n = ma;
    end

    always_ff @(posedge clk) begin
        vrtc_start <= 1'b0;
        if (!rst_n || reset_drv) begin
            // ASSUMPTION E2: RESET DRV holds the counters and the interrupt
            hc <= 9'd0; vc <= 10'd0; rs <= 5'd0;
            ma <= 16'd0; row_start <= 16'd0;
            hb_q <= 1'b0; hs_q <= 1'b0; vb_q <= 1'b0; vs_line <= 1'b0;
            vdiv <= 1'b0; vint <= 1'b0;
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
                        vb_q <= vb_n;
                        vs_line <= vs_n;
                        if (vs_n && !vs_line) begin
                            vrtc_start <= 1'b1;
                            if (!regs[5'h11][5] && regs[5'h11][4]) vint <= 1'b1;
                        end
                    end
                end
                hc <= hc_n;
                ma <= ma_n;
            end
            // TR p.37: Vertical Retrace End bit 4 = 0 clears the interrupt
            if (!regs[5'h11][4]) vint <= 1'b0;
        end
    end

    // Light pen (TR p.36/38): latch the address counter at the first
    // character boundary after the flip-flop rises.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lp <= 16'd0;
            lp_prev <= 1'b0;
        end else if (char_ce) begin
            lp_prev <= lpff;
            if (lpff && !lp_prev) lp <= ma;
        end
    end
`ifdef FORMAL
    // Formal checks (formal/ega_crtc.sby). Registers are arbitrary
    // constants: rst_n does not clear them under FORMAL and no data write
    // happens. Bounds keep the counters small (see plans/formal_plan.md).
    logic f_init = 1'b1;
    always_ff @(posedge clk) f_init <= 1'b0;
    always_comb begin
        if (f_init) assume (!rst_n);
        assume (!data_we);
        assume (!reset_drv);
    end
    logic [8:0] f_ht2;
    logic [5:0] f_hw;
    logic [4:0] f_vw;
    assign f_ht2 = {1'b0, regs[0]} + 9'd2;
    assign f_hw  = ((regs[5][4:0] - regs[4][4:0]) == 5'd0) ? 6'd32
                 : {1'b0, regs[5][4:0] - regs[4][4:0]};
    assign f_vw  = ((regs[5'h11][3:0] - vrs[3:0]) == 4'd0) ? 5'd16
                 : {1'b0, regs[5'h11][3:0] - vrs[3:0]};

`ifdef FORMAL_PROVE
    // horizontal retrace never wraps the line; vertical retrace never
    // wraps the frame; counters bounded
    always_comb begin
        assume (regs[0] <= 8'd70);
        assume ({1'b0, regs[4]} + 9'd33 <= f_ht2);
        assume (vt <= 9'd40);
        assume (vrs + 9'd17 <= vt);
        assume (!regs[5'h17][2]);
    end
`else
    always_comb begin
        assume (regs[0] <= 8'd3);
        assume (vt <= 9'd3);
    end
`endif

    // width of the horizontal retrace in characters (TR p.29 algorithm)
    logic [6:0] f_hcnt;
    logic [5:0] f_vcnt;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            f_hcnt <= 7'd0;
            f_vcnt <= 6'd0;
        end else if (char_ce) begin
            if (hs_cur) f_hcnt <= (hs_q ? f_hcnt : 7'd0) + 7'd1;
            if (go_line) begin
                if (vs_n) f_vcnt <= (vs_line ? f_vcnt : 6'd0) + 6'd1;
            end
        end
    end

    always_comb begin
        if (rst_n && !f_init) begin
            assert (hc <= f_ht2);
`ifdef FORMAL_PROVE
            assert (hc < f_ht2);
            assert (vc <= {1'b0, vt} + 10'd1);
            // a retrace that ends had exactly the programmed width
            if (char_ce && hs_q && !hs_cur) assert (f_hcnt == {1'b0, f_hw});
            if (char_ce && go_line && vs_line && !vs_n) assert (f_vcnt == {1'b0, f_vw});
            assert (f_hcnt <= 7'd32);
`endif
            // the interrupt latch is held clear by VRE bit 4 = 0 (TR p.37)
            if (!regs[5'h11][4]) assert (!vint);
        end
    end

    always_ff @(posedge clk) begin
        if ($past(rst_n) && rst_n && !f_init) begin
            // the latch only rises at the start of vertical retrace, enabled
            if (vint && !$past(vint))
                assert ($past(vs_n && !vs_line && go_line && char_ce) && !$past(regs[5'h11][5]));
            // vertical retrace starts only on the programmed line
            if (vs_line && !$past(vs_line)) assert (vc == {1'b0, vrs});
`ifndef FORMAL_PROVE
            // a complete frame: the counter wraps after the last line
            cover ($past(vc) == {1'b0, vt} + 10'd1 && vc == 10'd0 && $past(go_line));
            cover (vrtc_start && vint);
`endif
        end
    end
`endif
endmodule
