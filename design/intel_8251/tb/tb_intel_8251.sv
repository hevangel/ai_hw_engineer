`timescale 1ns/1ps

// Self-checking testbench for the Intel 8251/8251A reconstruction.
//
// Two independent mechanisms run together. A software-style reference model is
// stepped in lockstep with the DUT and the entire output interface is compared
// every sampled cycle, which proves the outputs are the specified functions of
// the registered state. On top of that, a specification-derived serial monitor
// decodes the frames the transmitter emits, and a specification-derived serial
// driver constructs frames on RxD, so transmit framing, receive framing, parity
// generation and checking, stop-bit length, error flags, break detection, and
// synchronous sync detection are all confirmed at the wire level without
// reference to the model. The design is therefore not accepted solely through a
// structurally similar model.
module tb_intel_8251;

    localparam logic [1:0] StMode  = 2'd0;
    localparam logic [1:0] StSync1 = 2'd1;
    localparam logic [1:0] StSync2 = 2'd2;
    localparam logic [1:0] StCmd   = 2'd3;

    localparam logic [2:0] TxIdle   = 3'd0;
    localparam logic [2:0] TxStart  = 3'd1;
    localparam logic [2:0] TxData   = 3'd2;
    localparam logic [2:0] TxParity = 3'd3;
    localparam logic [2:0] TxStop   = 3'd4;

    localparam logic [2:0] RxIdle   = 3'd0;
    localparam logic [2:0] RxStart  = 3'd1;
    localparam logic [2:0] RxData   = 3'd2;
    localparam logic [2:0] RxParity = 3'd3;
    localparam logic [2:0] RxStop   = 3'd4;
    localparam logic [2:0] RxHunt   = 3'd5;

    // ---------------------------------------------------------------------
    // DUT interface
    // ---------------------------------------------------------------------
    logic       clk;
    logic       rst_n;
    logic       cs_n;
    logic       rd_n;
    logic       wr_n;
    logic       c_d;
    logic [7:0] data_i;
    logic [7:0] data_o;
    logic       data_oe;
    logic       txc_tick;
    logic       rxc_tick;
    logic       txd;
    logic       txrdy;
    logic       txempty;
    logic       rxd;
    logic       rxrdy;
    logic       syndet_i;
    logic       syndet_o;
    logic       syndet_oe;
    logic       cts_n;
    logic       dsr_n;
    logic       rts_n;
    logic       dtr_n;

    // ---------------------------------------------------------------------
    // Reference model state
    // ---------------------------------------------------------------------
    logic [1:0]  ref_prog;
    logic [7:0]  ref_mode;
    logic [7:0]  ref_sync1;
    logic [7:0]  ref_sync2;
    logic [7:0]  ref_cmd;

    logic [7:0]  ref_tx_buf;
    logic        ref_tx_full;
    logic [7:0]  ref_tx_shift;
    logic        ref_tx_par;
    logic [3:0]  ref_tx_cnt;
    logic [7:0]  ref_tx_div;
    logic [2:0]  ref_tx_state;
    logic        ref_txd_reg;
    logic        ref_tx_under;
    logic        ref_tx_phase;

    logic [7:0]  ref_rx_buf;
    logic        ref_rx_full;
    logic [7:0]  ref_rx_shift;
    logic        ref_rx_pacc;
    logic        ref_rx_zero;
    logic [3:0]  ref_rx_cnt;
    logic [7:0]  ref_rx_div;
    logic [2:0]  ref_rx_state;
    logic [14:0] ref_hunt;

    logic        ref_pe;
    logic        ref_oe;
    logic        ref_fe;
    logic        ref_syn;
    logic [1:0]  ref_brun;

    // Expected outputs
    logic [7:0] ref_data_o;
    logic       ref_data_oe;
    logic       ref_txd;
    logic       ref_txrdy;
    logic       ref_txempty;
    logic       ref_rxrdy;
    logic       ref_syndet_o;
    logic       ref_syndet_oe;
    logic       ref_rts_n;
    logic       ref_dtr_n;

    // ---------------------------------------------------------------------
    // Testbench bookkeeping
    // ---------------------------------------------------------------------
    integer cycle_count;
    integer interface_check_count;
    integer field_check_count;
    integer failure_count;
    integer cpu_read_count;
    integer cpu_write_count;
    integer mode_prog_count;
    integer tx_frame_count;
    integer rx_frame_count;
    integer syndet_count;
    integer pe_count;
    integer fe_count;
    integer oe_count;
    integer break_count;

    // Baud-rate enable policy: one tick every `tick_div` core cycles.
    integer tick_div;
    integer tick_phase;

    // Frame geometry currently programmed, tracked independently of the DUT
    integer cfg_bit_period;
    integer cfg_half_period;
    integer cfg_stop_ticks;
    integer cfg_char_bits;
    logic   cfg_parity_en;
    logic   cfg_even;
    logic   cfg_loopback;

    // Intentionally unread model bits: stored command bits 4, 6, and 7 are
    // one-shot actions, matching the RTL.
    logic _unused_tb;
    assign _unused_tb = &{1'b0, ref_cmd[7], ref_cmd[6], ref_cmd[4]};

    intel_8251 dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .cs_n      (cs_n),
        .rd_n      (rd_n),
        .wr_n      (wr_n),
        .c_d       (c_d),
        .data_i    (data_i),
        .data_o    (data_o),
        .data_oe   (data_oe),
        .txc_tick  (txc_tick),
        .rxc_tick  (rxc_tick),
        .txd       (txd),
        .txrdy     (txrdy),
        .txempty   (txempty),
        .rxd       (rxd),
        .rxrdy     (rxrdy),
        .syndet_i  (syndet_i),
        .syndet_o  (syndet_o),
        .syndet_oe (syndet_oe),
        .cts_n     (cts_n),
        .dsr_n     (dsr_n),
        .rts_n     (rts_n),
        .dtr_n     (dtr_n)
    );

    always #5 clk = ~clk;

    // ---------------------------------------------------------------------
    // Shared helper functions
    // ---------------------------------------------------------------------
    function automatic logic [7:0] width_mask(input logic [3:0] bits);
        begin
            width_mask = 8'hff >> (4'd8 - bits);
        end
    endfunction

    function automatic logic char_parity(input logic [7:0] value,
                                         input logic [7:0] mask,
                                         input logic       even);
        begin
            char_parity = even ? ^(value & mask) : ~(^(value & mask));
        end
    endfunction

    function automatic logic [15:0] next_lfsr(input logic [15:0] cur);
        begin
            next_lfsr = {cur[14:0],
                         cur[15] ^ cur[13] ^ cur[12] ^ cur[10]};
        end
    endfunction

    // ---------------------------------------------------------------------
    // Expected outputs, derived from the model state and the live inputs
    // ---------------------------------------------------------------------
    logic [1:0] e_baud;
    logic       e_async;
    logic       e_sync;
    logic       e_conf;
    logic       e_esd;
    logic       e_bread;
    logic       e_break_det;
    logic       e_syndet;
    logic [7:0] e_status;

    always_comb begin
        e_baud      = ref_mode[1:0];
        e_async     = (e_baud != 2'b00);
        e_sync      = (e_baud == 2'b00);
        e_esd       = ref_mode[6];
        e_conf      = (ref_prog == StCmd);
        e_bread     = !cs_n && !rd_n && wr_n;
        e_break_det = (ref_brun == 2'd2);
        e_syndet    = e_async ? e_break_det : ref_syn;

        ref_txd       = ref_cmd[3] ? 1'b0 : ref_txd_reg;
        ref_txrdy     = !ref_tx_full && e_conf && ref_cmd[0] && !cts_n;
        ref_txempty   = (!ref_tx_full && (ref_tx_state == TxIdle)) ||
                        (e_sync && ref_tx_under);
        ref_rxrdy     = ref_rx_full;
        ref_syndet_o  = e_syndet;
        ref_syndet_oe = e_conf && (e_async || !e_esd);
        ref_rts_n     = ~ref_cmd[5];
        ref_dtr_n     = ~ref_cmd[1];

        e_status = {~dsr_n, e_syndet, ref_fe, ref_oe, ref_pe,
                    ref_txempty, ref_rx_full, ~ref_tx_full};

        ref_data_o  = 8'h00;
        ref_data_oe = 1'b0;
        if (e_bread) begin
            ref_data_oe = 1'b1;
            ref_data_o  = c_d ? e_status : ref_rx_buf;
        end
    end

    // ---------------------------------------------------------------------
    // Reference next-state computation, mirroring the RTL always_ff exactly.
    // Every right-hand side reads a snapshot of the previous state so the
    // blocking-assignment model matches non-blocking hardware semantics, while
    // later writes still override earlier ones exactly as in the RTL.
    // ---------------------------------------------------------------------
    task automatic model_step;
        logic [1:0]  o_prog;
        logic [7:0]  o_mode;
        logic [7:0]  o_s1;
        logic [7:0]  o_s2;
        logic [7:0]  o_txbuf;
        logic        o_txfull;
        logic [7:0]  o_txsh;
        logic        o_txpar;
        logic [3:0]  o_txcnt;
        logic [7:0]  o_txdiv;
        logic [2:0]  o_txst;
        logic        o_txph;
        logic        o_rxfull;
        logic [7:0]  o_rxsh;
        logic        o_rxpacc;
        logic        o_rxzero;
        logic [3:0]  o_rxcnt;
        logic [7:0]  o_rxdiv;
        logic [2:0]  o_rxst;
        logic [14:0] o_hunt;
        logic [1:0]  o_brun;

        logic [1:0]  m_baud;
        logic [3:0]  m_cbits;
        logic [3:0]  m_gap;
        logic [7:0]  m_mask;
        logic        m_pen;
        logic        m_ep;
        logic [1:0]  m_stopsel;
        logic        m_esd;
        logic        m_scs;
        logic        m_async;
        logic        m_sync;
        logic        m_conf;
        logic        m_txen;
        logic        m_rxen;
        logic        m_brk;
        logic        m_bread;
        logic        m_bwrite;
        logic        m_rxread;
        logic        m_stread;
        logic        m_cwrite;
        logic        m_dwrite;
        logic        m_cmdw;
        logic        m_ireset;
        logic [7:0]  m_bit;
        logic [7:0]  m_half;
        logic [7:0]  m_stopt;
        logic        m_canstart;
        logic        m_launchok;
        logic        m_lastbit;
        logic        m_boundary;
        logic        m_dolaunch;
        logic [7:0]  m_syncsrc;
        logic [7:0]  m_charsrc;
        logic [15:0] m_huntwin;
        logic [7:0]  m_huntcur;
        logic [15:0] m_huntprev;
        logic        m_huntmatch;
        logic        m_rxactive;
        logic        m_exppar;
        logic [7:0]  m_rxchar;
        begin
            o_prog   = ref_prog;
            o_mode   = ref_mode;
            o_s1     = ref_sync1;
            o_s2     = ref_sync2;
            o_txbuf  = ref_tx_buf;
            o_txfull = ref_tx_full;
            o_txsh   = ref_tx_shift;
            o_txpar  = ref_tx_par;
            o_txcnt  = ref_tx_cnt;
            o_txdiv  = ref_tx_div;
            o_txst   = ref_tx_state;
            o_txph   = ref_tx_phase;
            o_rxfull = ref_rx_full;
            o_rxsh   = ref_rx_shift;
            o_rxpacc = ref_rx_pacc;
            o_rxzero = ref_rx_zero;
            o_rxcnt  = ref_rx_cnt;
            o_rxdiv  = ref_rx_div;
            o_rxst   = ref_rx_state;
            o_hunt   = ref_hunt;
            o_brun   = ref_brun;

            m_baud    = o_mode[1:0];
            m_cbits   = 4'd5 + {2'b00, o_mode[3:2]};
            m_gap     = 4'd8 - m_cbits;
            m_mask    = 8'hff >> m_gap;
            m_pen     = o_mode[4];
            m_ep      = o_mode[5];
            m_stopsel = o_mode[7:6];
            m_esd     = o_mode[6];
            m_scs     = o_mode[7];
            m_async   = (m_baud != 2'b00);
            m_sync    = (m_baud == 2'b00);
            m_conf    = (o_prog == StCmd);
            m_txen    = ref_cmd[0];
            m_rxen    = ref_cmd[2];
            m_brk     = ref_cmd[3];

            m_bread  = !cs_n && !rd_n &&  wr_n;
            m_bwrite = !cs_n &&  rd_n && !wr_n;
            m_rxread = m_bread  && !c_d;
            m_stread = m_bread  &&  c_d;
            m_cwrite = m_bwrite &&  c_d;
            m_dwrite = m_bwrite && !c_d;
            m_cmdw   = m_cwrite && (o_prog == StCmd);
            m_ireset = m_cmdw && data_i[6];

            case (m_baud)
                2'b00:   begin m_bit = 8'd1;  m_half = 8'd1;  end
                2'b01:   begin m_bit = 8'd1;  m_half = 8'd1;  end
                2'b10:   begin m_bit = 8'd16; m_half = 8'd8;  end
                default: begin m_bit = 8'd64; m_half = 8'd32; end
            endcase
            case (m_stopsel)
                2'b10:   m_stopt = m_bit + m_half;
                2'b11:   m_stopt = {m_bit[6:0], 1'b0};
                default: m_stopt = m_bit;
            endcase

            m_canstart = m_conf && m_txen && !cts_n && !m_brk;
            m_launchok = m_canstart && (m_sync || o_txfull);
            m_lastbit  = (o_txdiv == 8'd0) &&
                         ((o_txst == TxParity) ||
                          ((o_txst == TxData) && (o_txcnt == m_cbits) &&
                           !m_pen));
            m_boundary = (o_txst == TxIdle) || (m_sync && m_lastbit);
            m_dolaunch = txc_tick && m_boundary && m_launchok;
            m_syncsrc  = o_txph ? o_s2 : o_s1;
            m_charsrc  = o_txfull ? o_txbuf : m_syncsrc;

            m_huntwin     = {rxd, o_hunt};
            m_huntcur     = m_huntwin[15:8] >> m_gap;
            m_huntprev    = (m_huntwin >> {m_gap[1:0], 1'b0}) &
                            {8'h00, m_mask};
            m_huntmatch   = m_scs
                            ? (m_huntcur == (o_s1 & m_mask))
                            : ((m_huntcur == (o_s2 & m_mask)) &&
                               (m_huntprev == {8'h00, o_s1 & m_mask}));
            m_rxactive    = m_conf && m_rxen;
            m_exppar      = m_ep ? o_rxpacc : ~o_rxpacc;
            m_rxchar      = o_rxsh >> m_gap;

            if (!rst_n || m_ireset) begin
                ref_prog     = StMode;
                ref_mode     = 8'h00;
                ref_sync1    = 8'h00;
                ref_sync2    = 8'h00;
                ref_cmd      = 8'h00;
                ref_tx_buf   = 8'h00;
                ref_tx_full  = 1'b0;
                ref_tx_shift = 8'h00;
                ref_tx_par   = 1'b0;
                ref_tx_cnt   = 4'd0;
                ref_tx_div   = 8'd0;
                ref_tx_state = TxIdle;
                ref_txd_reg  = 1'b1;
                ref_tx_under = 1'b0;
                ref_tx_phase = 1'b0;
                ref_rx_buf   = 8'h00;
                ref_rx_full  = 1'b0;
                ref_rx_shift = 8'h00;
                ref_rx_pacc  = 1'b0;
                ref_rx_zero  = 1'b0;
                ref_rx_cnt   = 4'd0;
                ref_rx_div   = 8'd0;
                ref_rx_state = RxIdle;
                ref_hunt     = 15'h0000;
                ref_pe       = 1'b0;
                ref_oe       = 1'b0;
                ref_fe       = 1'b0;
                ref_syn      = 1'b0;
                ref_brun     = 2'd0;
            end else begin
                // ---- CPU read side effects ----
                if (m_rxread) begin
                    ref_rx_full = 1'b0;
                end
                if (m_stread) begin
                    ref_syn = 1'b0;
                end

                // ---- Transmitter ----
                if (txc_tick) begin
                    if (m_dolaunch) begin
                        ref_tx_par = char_parity(m_charsrc, m_mask, m_ep);
                        ref_tx_div = m_bit - 8'd1;
                        if (o_txfull) begin
                            ref_tx_full  = 1'b0;
                            ref_tx_under = 1'b0;
                            ref_tx_phase = 1'b0;
                        end else begin
                            ref_tx_under = 1'b1;
                            ref_tx_phase = m_scs ? 1'b0 : ~o_txph;
                        end
                        if (m_async) begin
                            ref_tx_shift = m_charsrc;
                            ref_txd_reg  = 1'b0;
                            ref_tx_cnt   = 4'd0;
                            ref_tx_state = TxStart;
                        end else begin
                            ref_tx_shift = {1'b0, m_charsrc[7:1]};
                            ref_txd_reg  = m_charsrc[0];
                            ref_tx_cnt   = 4'd1;
                            ref_tx_state = TxData;
                        end
                    end else if (o_txst == TxIdle) begin
                        ref_txd_reg = 1'b1;
                    end else if (o_txdiv != 8'd0) begin
                        ref_tx_div = o_txdiv - 8'd1;
                    end else begin
                        case (o_txst)
                            TxStart: begin
                                ref_txd_reg  = o_txsh[0];
                                ref_tx_shift = {1'b0, o_txsh[7:1]};
                                ref_tx_cnt   = 4'd1;
                                ref_tx_div   = m_bit - 8'd1;
                                ref_tx_state = TxData;
                            end
                            TxData: begin
                                if (o_txcnt < m_cbits) begin
                                    ref_txd_reg  = o_txsh[0];
                                    ref_tx_shift = {1'b0, o_txsh[7:1]};
                                    ref_tx_cnt   = o_txcnt + 4'd1;
                                    ref_tx_div   = m_bit - 8'd1;
                                end else if (m_pen) begin
                                    ref_txd_reg  = o_txpar;
                                    ref_tx_div   = m_bit - 8'd1;
                                    ref_tx_state = TxParity;
                                end else if (m_async) begin
                                    ref_txd_reg  = 1'b1;
                                    ref_tx_div   = m_stopt - 8'd1;
                                    ref_tx_state = TxStop;
                                end else begin
                                    ref_txd_reg  = 1'b1;
                                    ref_tx_cnt   = 4'd0;
                                    ref_tx_state = TxIdle;
                                end
                            end
                            TxParity: begin
                                if (m_async) begin
                                    ref_txd_reg  = 1'b1;
                                    ref_tx_div   = m_stopt - 8'd1;
                                    ref_tx_state = TxStop;
                                end else begin
                                    ref_txd_reg  = 1'b1;
                                    ref_tx_cnt   = 4'd0;
                                    ref_tx_state = TxIdle;
                                end
                            end
                            TxStop: begin
                                ref_txd_reg  = 1'b1;
                                ref_tx_cnt   = 4'd0;
                                ref_tx_state = TxIdle;
                            end
                            default: begin
                                ref_txd_reg  = 1'b1;
                                ref_tx_cnt   = 4'd0;
                                ref_tx_state = TxIdle;
                            end
                        endcase
                    end
                end

                // ---- Receiver ----
                if (!m_rxactive) begin
                    ref_rx_state = m_async ? RxIdle : RxHunt;
                    ref_rx_shift = 8'h00;
                    ref_rx_pacc  = 1'b0;
                    ref_rx_zero  = 1'b0;
                    ref_rx_cnt   = 4'd0;
                    ref_rx_div   = 8'd0;
                    ref_hunt     = 15'h0000;
                    ref_brun     = 2'd0;
                end else begin
                    if (m_async && rxd) begin
                        ref_brun = 2'd0;
                    end

                    if (rxc_tick) begin
                        if (o_rxdiv != 8'd0) begin
                            ref_rx_div = o_rxdiv - 8'd1;
                        end else begin
                            case (o_rxst)
                                RxIdle: begin
                                    if (!rxd) begin
                                        ref_rx_div   = m_half - 8'd1;
                                        ref_rx_state = RxStart;
                                    end
                                end
                                RxStart: begin
                                    if (rxd) begin
                                        ref_rx_state = RxIdle;
                                    end else begin
                                        ref_rx_shift = 8'h00;
                                        ref_rx_pacc  = 1'b0;
                                        ref_rx_zero  = 1'b1;
                                        ref_rx_cnt   = 4'd0;
                                        ref_rx_div   = m_bit - 8'd1;
                                        ref_rx_state = RxData;
                                    end
                                end
                                RxData: begin
                                    ref_rx_shift = {rxd, o_rxsh[7:1]};
                                    ref_rx_pacc  = o_rxpacc ^ rxd;
                                    ref_rx_zero  = o_rxzero && !rxd;
                                    ref_rx_cnt   = o_rxcnt + 4'd1;
                                    ref_rx_div   = m_bit - 8'd1;
                                    if ((o_rxcnt + 4'd1) == m_cbits) begin
                                        if (m_pen) begin
                                            ref_rx_state = RxParity;
                                        end else if (m_async) begin
                                            ref_rx_state = RxStop;
                                        end else begin
                                            if (o_rxfull && !m_rxread) begin
                                                ref_oe = 1'b1;
                                            end
                                            ref_rx_buf   = {rxd, o_rxsh[7:1]} >>
                                                           m_gap;
                                            ref_rx_full  = 1'b1;
                                            ref_rx_shift = 8'h00;
                                            ref_rx_pacc  = 1'b0;
                                            ref_rx_cnt   = 4'd0;
                                        end
                                    end
                                end
                                RxParity: begin
                                    ref_rx_zero = o_rxzero && !rxd;
                                    if (rxd != m_exppar) begin
                                        ref_pe = 1'b1;
                                    end
                                    ref_rx_div = m_bit - 8'd1;
                                    if (m_async) begin
                                        ref_rx_state = RxStop;
                                    end else begin
                                        if (o_rxfull && !m_rxread) begin
                                            ref_oe = 1'b1;
                                        end
                                        ref_rx_buf   = m_rxchar;
                                        ref_rx_full  = 1'b1;
                                        ref_rx_shift = 8'h00;
                                        ref_rx_pacc  = 1'b0;
                                        ref_rx_cnt   = 4'd0;
                                        ref_rx_state = RxData;
                                    end
                                end
                                RxStop: begin
                                    if (!rxd) begin
                                        ref_fe = 1'b1;
                                    end
                                    if (o_rxzero && !rxd) begin
                                        ref_brun = (o_brun == 2'd2)
                                                   ? 2'd2 : o_brun + 2'd1;
                                    end else begin
                                        ref_brun = 2'd0;
                                    end
                                    if (o_rxfull && !m_rxread) begin
                                        ref_oe = 1'b1;
                                    end
                                    ref_rx_buf   = m_rxchar;
                                    ref_rx_full  = 1'b1;
                                    ref_rx_state = RxIdle;
                                end
                                RxHunt: begin
                                    ref_hunt = m_huntwin[15:1];
                                    if (m_esd ? syndet_i : m_huntmatch) begin
                                        ref_syn      = 1'b1;
                                        ref_rx_shift = 8'h00;
                                        ref_rx_pacc  = 1'b0;
                                        ref_rx_cnt   = 4'd0;
                                        ref_rx_state = RxData;
                                    end
                                end
                                default: begin
                                    ref_rx_state = m_async ? RxIdle : RxHunt;
                                end
                            endcase
                        end
                    end
                end

                // ---- CPU writes ----
                if (m_cwrite) begin
                    case (o_prog)
                        StMode: begin
                            ref_mode = data_i;
                            ref_prog = (data_i[1:0] == 2'b00) ? StSync1 : StCmd;
                        end
                        StSync1: begin
                            ref_sync1 = data_i;
                            ref_prog  = m_scs ? StCmd : StSync2;
                        end
                        StSync2: begin
                            ref_sync2 = data_i;
                            ref_prog  = StCmd;
                        end
                        default: begin
                            ref_cmd = data_i;
                            if (data_i[4]) begin
                                ref_pe = 1'b0;
                                ref_oe = 1'b0;
                                ref_fe = 1'b0;
                            end
                            if (data_i[7] && m_sync) begin
                                ref_syn      = 1'b0;
                                ref_hunt     = 15'h0000;
                                ref_rx_shift = 8'h00;
                                ref_rx_pacc  = 1'b0;
                                ref_rx_cnt   = 4'd0;
                                ref_rx_div   = 8'd0;
                                ref_rx_state = RxHunt;
                            end
                        end
                    endcase
                end else if (m_dwrite) begin
                    ref_tx_buf  = data_i;
                    ref_tx_full = 1'b1;
                end
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Checking primitives
    // ---------------------------------------------------------------------
    task automatic record_mismatch(input string      field_name,
                                   input logic [7:0] actual_value,
                                   input logic [7:0] expected_value);
        begin
            field_check_count = field_check_count + 1;
            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d %s: actual=%02h expected=%02h",
                         cycle_count, field_name, actual_value,
                         expected_value);
            end
        end
    endtask

    task automatic check_outputs;
        begin
            interface_check_count = interface_check_count + 1;
            record_mismatch("data_o", data_o, ref_data_o);
            record_mismatch("data_oe", {7'h00, data_oe}, {7'h00, ref_data_oe});
            record_mismatch("txd", {7'h00, txd}, {7'h00, ref_txd});
            record_mismatch("txrdy", {7'h00, txrdy}, {7'h00, ref_txrdy});
            record_mismatch("txempty", {7'h00, txempty}, {7'h00, ref_txempty});
            record_mismatch("rxrdy", {7'h00, rxrdy}, {7'h00, ref_rxrdy});
            record_mismatch("syndet_o", {7'h00, syndet_o},
                            {7'h00, ref_syndet_o});
            record_mismatch("syndet_oe", {7'h00, syndet_oe},
                            {7'h00, ref_syndet_oe});
            record_mismatch("rts_n", {7'h00, rts_n}, {7'h00, ref_rts_n});
            record_mismatch("dtr_n", {7'h00, dtr_n}, {7'h00, ref_dtr_n});
        end
    endtask

    task automatic check_condition(input logic  condition_value,
                                   input string description);
        begin
            field_check_count = field_check_count + 1;
            if (condition_value !== 1'b1) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d: %s", cycle_count, description);
            end
        end
    endtask

    task automatic check_byte(input logic [7:0] actual_value,
                              input logic [7:0] expected_value,
                              input string      description);
        begin
            field_check_count = field_check_count + 1;
            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d %s: actual=%02h expected=%02h",
                         cycle_count, description, actual_value,
                         expected_value);
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Cycle stepping and bus access
    // ---------------------------------------------------------------------
    task automatic step_cycle;
        begin
            if (tick_div <= 1) begin
                txc_tick   = 1'b1;
                rxc_tick   = 1'b1;
                tick_phase = 0;
            end else begin
                txc_tick   = (tick_phase == 0);
                rxc_tick   = (tick_phase == 0);
                // A `>=` wrap keeps the phase live when `tick_div` shrinks.
                tick_phase = (tick_phase >= (tick_div - 1))
                             ? 0 : (tick_phase + 1);
            end
            if (cfg_loopback) begin
                rxd = txd;
            end
            model_step();
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (cfg_loopback) begin
                rxd = txd;
            end
            check_outputs();
        end
    endtask

    task automatic set_idle_bus;
        begin
            cs_n   = 1'b1;
            rd_n   = 1'b1;
            wr_n   = 1'b1;
            c_d    = 1'b0;
            data_i = 8'h00;
        end
    endtask

    task automatic cpu_write(input logic wcd, input logic [7:0] wdata);
        begin
            @(negedge clk);
            cs_n   = 1'b0;
            rd_n   = 1'b1;
            wr_n   = 1'b0;
            c_d    = wcd;
            data_i = wdata;
            cpu_write_count = cpu_write_count + 1;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic cpu_read(input logic rcd, output logic [7:0] rdata);
        begin
            @(negedge clk);
            cs_n   = 1'b0;
            rd_n   = 1'b0;
            wr_n   = 1'b1;
            c_d    = rcd;
            data_i = 8'h00;
            cpu_read_count = cpu_read_count + 1;
            // The CPU latches the value presented during the active read cycle,
            // before the sampling edge commits any read side effect.
            #1;
            rdata = data_o;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic idle_cycle;
        begin
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic run_cycles(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                idle_cycle();
            end
        end
    endtask

    // Advance until `n` baud-rate enable pulses have been consumed.
    task automatic run_ticks(input integer n);
        integer k;
        begin
            k = 0;
            while (k < n) begin
                @(negedge clk);
                set_idle_bus();
                step_cycle();
                if (rxc_tick) begin
                    k = k + 1;
                end
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // Programming helpers. The frame geometry is recomputed here from the
    // instruction fields, independently of the DUT.
    // ---------------------------------------------------------------------
    task automatic program_async(input logic [1:0] baud,
                                 input logic [1:0] len,
                                 input logic       pen,
                                 input logic       ep,
                                 input logic [1:0] stopb);
        begin
            cpu_write(1'b1, {stopb, ep, pen, len, baud});
            cfg_char_bits = 32'd5 + {30'd0, len};
            cfg_parity_en = pen;
            cfg_even      = ep;
            case (baud)
                2'b01:   begin cfg_bit_period = 1;  cfg_half_period = 1;  end
                2'b10:   begin cfg_bit_period = 16; cfg_half_period = 8;  end
                default: begin cfg_bit_period = 64; cfg_half_period = 32; end
            endcase
            case (stopb)
                2'b10:   cfg_stop_ticks = cfg_bit_period + cfg_half_period;
                2'b11:   cfg_stop_ticks = 2 * cfg_bit_period;
                default: cfg_stop_ticks = cfg_bit_period;
            endcase
            mode_prog_count = mode_prog_count + 1;
        end
    endtask

    task automatic program_sync(input logic [1:0] len,
                                input logic       pen,
                                input logic       ep,
                                input logic       esd,
                                input logic       scs,
                                input logic [7:0] s1,
                                input logic [7:0] s2);
        begin
            cpu_write(1'b1, {scs, esd, pen, ep, len, 2'b00});
            cpu_write(1'b1, s1);
            if (!scs) begin
                cpu_write(1'b1, s2);
            end
            cfg_char_bits   = 32'd5 + {30'd0, len};
            cfg_parity_en   = pen;
            cfg_even        = ep;
            cfg_bit_period  = 1;
            cfg_half_period = 1;
            cfg_stop_ticks  = 1;
            mode_prog_count = mode_prog_count + 1;
        end
    endtask

    task automatic internal_reset;
        begin
            cpu_write(1'b1, 8'h40);
        end
    endtask

    // ---------------------------------------------------------------------
    // Wire-level serial driver and monitor, both derived from the frame
    // definition in the specification rather than from the RTL.
    // ---------------------------------------------------------------------
    task automatic drive_rx_bit(input logic v, input integer ticks);
        integer k;
        begin
            k = 0;
            while (k < ticks) begin
                @(negedge clk);
                set_idle_bus();
                rxd = v;
                step_cycle();
                if (rxc_tick) begin
                    k = k + 1;
                end
            end
        end
    endtask

    task automatic drive_rx_frame(input logic [7:0] ch,
                                  input logic       bad_parity,
                                  input logic       bad_stop);
        integer     b;
        logic [2:0] bsel;
        logic       p;
        begin
            drive_rx_bit(1'b0, cfg_bit_period);
            for (b = 0; b < cfg_char_bits; b = b + 1) begin
                bsel = b[2:0];
                drive_rx_bit(ch[bsel], cfg_bit_period);
            end
            if (cfg_parity_en) begin
                p = char_parity(ch, width_mask(cfg_char_bits[3:0]), cfg_even);
                drive_rx_bit(bad_parity ? ~p : p, cfg_bit_period);
            end
            drive_rx_bit(bad_stop ? 1'b0 : 1'b1, cfg_stop_ticks);
            rx_frame_count = rx_frame_count + 1;
        end
    endtask

    // Decode one asynchronous frame from TxD. The monitor finds the start bit,
    // then samples at the centre of every bit using the programmed geometry.
    task automatic capture_tx_frame(output logic [7:0] ch,
                                    output logic       parity_ok,
                                    output logic       stop_ok,
                                    output logic       found);
        integer b;
        integer guard;
        logic [7:0] acc;
        logic       p_bit;
        begin
            ch        = 8'h00;
            parity_ok = 1'b1;
            stop_ok   = 1'b1;
            found     = 1'b0;
            acc       = 8'h00;
            guard     = 0;
            while ((txd !== 1'b0) && (guard < 8000)) begin
                idle_cycle();
                guard = guard + 1;
            end
            if (txd === 1'b0) begin
                found = 1'b1;
                run_ticks(cfg_half_period);
                stop_ok = (txd === 1'b0);
                for (b = 0; b < cfg_char_bits; b = b + 1) begin
                    run_ticks(cfg_bit_period);
                    acc[b[2:0]] = txd;
                end
                if (cfg_parity_en) begin
                    run_ticks(cfg_bit_period);
                    p_bit = char_parity(acc, width_mask(cfg_char_bits[3:0]),
                                        cfg_even);
                    parity_ok = (txd === p_bit);
                end
                run_ticks(cfg_bit_period);
                stop_ok = stop_ok && (txd === 1'b1);
                ch = acc & width_mask(cfg_char_bits[3:0]);
                tx_frame_count = tx_frame_count + 1;
            end
        end
    endtask

    // A frame delivered with a low stop bit leaves RxD low past the point where
    // the receiver samples it, so the receiver immediately re-triggers on the
    // remainder of that stop bit exactly as the historical part does. Holding
    // RxD at the mark for more than a character time lets the spurious frame
    // drain and returns the receiver to start-bit search. The pending character
    // and error flags are then discarded.
    task automatic rx_resync(input logic [7:0] cmd_word);
        logic [7:0] drained;
        integer     guard;
        begin
            drive_rx_bit(1'b1, (cfg_char_bits + 4) * cfg_bit_period);
            drained = 8'h00;
            guard   = 0;
            while (rxrdy && (guard < 4)) begin
                cpu_read(1'b0, drained);
                guard = guard + 1;
            end
            check_condition(!rxrdy,
                            "receive buffer drains after resynchronization");
            check_byte(drained, 8'hff & width_mask(cfg_char_bits[3:0]),
                       "spurious frame over an idle line reads as all ones");
            cpu_write(1'b1, cmd_word | 8'h10);
        end
    endtask

    // Send one character and confirm the wire-level frame carries it.
    task automatic send_and_check_frame(input logic [7:0] ch);
        logic [7:0] got;
        logic       p_ok;
        logic       s_ok;
        logic       found;
        begin
            cpu_write(1'b0, ch);
            capture_tx_frame(got, p_ok, s_ok, found);
            check_condition(found, "transmitter must start a frame");
            check_byte(got, ch & width_mask(cfg_char_bits[3:0]),
                       "transmitted character");
            check_condition(p_ok, "transmitted parity bit must be correct");
            check_condition(s_ok, "transmitted start and stop bits");
        end
    endtask

    // ---------------------------------------------------------------------
    // Directed stimulus
    // ---------------------------------------------------------------------
    initial begin
        integer idx;
        logic [7:0] status;
        logic [7:0] rdata;
        logic [7:0] got;
        logic       p_ok;
        logic       s_ok;
        logic       found;
        logic       seen;
        logic [15:0] lfsr;
        logic [2:0]  op;
        logic [7:0]  rnd;

        clk      = 1'b0;
        rst_n    = 1'b0;
        cs_n     = 1'b1;
        rd_n     = 1'b1;
        wr_n     = 1'b1;
        c_d      = 1'b0;
        data_i   = 8'h00;
        txc_tick = 1'b0;
        rxc_tick = 1'b0;
        rxd      = 1'b1;
        syndet_i = 1'b0;
        cts_n    = 1'b0;
        dsr_n    = 1'b1;

        cycle_count           = 0;
        interface_check_count = 0;
        field_check_count     = 0;
        failure_count         = 0;
        cpu_read_count        = 0;
        cpu_write_count       = 0;
        mode_prog_count       = 0;
        tx_frame_count        = 0;
        rx_frame_count        = 0;
        syndet_count          = 0;
        pe_count              = 0;
        fe_count              = 0;
        oe_count              = 0;
        break_count           = 0;

        tick_div        = 1;
        tick_phase      = 0;
        cfg_bit_period  = 1;
        cfg_half_period = 1;
        cfg_stop_ticks  = 1;
        cfg_char_bits   = 8;
        cfg_parity_en   = 1'b0;
        cfg_even        = 1'b0;
        cfg_loopback    = 1'b0;

        ref_prog     = StMode;
        ref_mode     = 8'h00;
        ref_sync1    = 8'h00;
        ref_sync2    = 8'h00;
        ref_cmd      = 8'h00;
        ref_tx_buf   = 8'h00;
        ref_tx_full  = 1'b0;
        ref_tx_shift = 8'h00;
        ref_tx_par   = 1'b0;
        ref_tx_cnt   = 4'd0;
        ref_tx_div   = 8'd0;
        ref_tx_state = TxIdle;
        ref_txd_reg  = 1'b1;
        ref_tx_under = 1'b0;
        ref_tx_phase = 1'b0;
        ref_rx_buf   = 8'h00;
        ref_rx_full  = 1'b0;
        ref_rx_shift = 8'h00;
        ref_rx_pacc  = 1'b0;
        ref_rx_zero  = 1'b0;
        ref_rx_cnt   = 4'd0;
        ref_rx_div   = 8'd0;
        ref_rx_state = RxIdle;
        ref_hunt     = 15'h0000;
        ref_pe       = 1'b0;
        ref_oe       = 1'b0;
        ref_fe       = 1'b0;
        ref_syn      = 1'b0;
        ref_brun     = 2'd0;

        $display("--- reset and un-programmed state ---");
        run_cycles(4);
        check_condition(txd === 1'b1, "TxD idles high out of reset");
        check_condition(!syndet_oe, "SYNDET is not driven before programming");
        check_condition(rts_n === 1'b1, "RTS is inactive out of reset");
        check_condition(dtr_n === 1'b1, "DTR is inactive out of reset");
        @(negedge clk);
        rst_n = 1'b1;
        step_cycle();
        run_cycles(2);
        cpu_read(1'b1, status);
        check_condition(status[0], "TxRDY status is set with an empty buffer");
        check_condition(!status[1], "RxRDY status is clear out of reset");
        check_condition(status[2], "TxEMPTY status is set out of reset");
        check_condition(status[5:3] == 3'b000, "error flags clear out of reset");
        check_condition(!status[7], "DSR status follows an inactive dsr_n");

        $display("--- asynchronous 16x, 8 data bits, even parity, 1 stop ---");
        program_async(2'b10, 2'b11, 1'b1, 1'b1, 2'b01);
        check_condition(syndet_oe,
                        "SYNDET is driven as break detect in async mode");
        cpu_write(1'b1, 8'h27);            // TxEN, DTR, RxE, RTS
        check_condition(rts_n === 1'b0, "RTS follows the command word");
        check_condition(dtr_n === 1'b0, "DTR follows the command word");
        check_condition(txrdy === 1'b1, "TxRDY asserts once TxEN is set");
        send_and_check_frame(8'ha5);
        send_and_check_frame(8'h00);
        send_and_check_frame(8'hff);
        send_and_check_frame(8'h5a);
        send_and_check_frame(8'h81);

        $display("--- transmit buffer handshake and CTS gating ---");
        cpu_read(1'b1, status);
        check_condition(status[0], "TxRDY status set after the buffer drains");
        cpu_write(1'b0, 8'h3c);
        cpu_read(1'b1, status);
        check_condition(!status[2],
                        "TxEMPTY status clears while a character is in flight");
        run_ticks(cfg_bit_period * 12);
        cpu_read(1'b1, status);
        check_condition(status[2], "TxEMPTY status returns after the frame");
        @(negedge clk);
        cts_n = 1'b1;
        step_cycle();
        check_condition(!txrdy, "TxRDY deasserts while CTS is inactive");
        cpu_write(1'b0, 8'h11);
        run_ticks(4);
        check_condition(txd === 1'b1,
                        "no frame starts while CTS is inactive");
        @(negedge clk);
        cts_n = 1'b0;
        step_cycle();
        capture_tx_frame(got, p_ok, s_ok, found);
        check_condition(found, "frame starts once CTS returns");
        check_byte(got, 8'h11, "character held through CTS backpressure");
        check_condition(p_ok, "parity is correct after CTS backpressure");
        check_condition(s_ok, "framing is correct after CTS backpressure");

        $display("--- receive path with wire-level frames ---");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h96, 1'b0, 1'b0);
        check_condition(rxrdy, "RxRDY asserts after a received frame");
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h96, "received character");
        check_condition(!rxrdy, "RxRDY clears when the character is read");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h3c, 1'b0, 1'b0);
        cpu_read(1'b1, status);
        check_condition(status[1], "RxRDY status set with a waiting character");
        check_condition(status[5:3] == 3'b000,
                        "no error flags on a clean frame");
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h3c, "second received character");

        $display("--- parity, framing, and overrun errors ---");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h55, 1'b1, 1'b0);
        cpu_read(1'b1, status);
        check_condition(status[3], "parity error flag set on a bad parity bit");
        pe_count = pe_count + 1;
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h55,
                   "character delivered despite the parity error");
        cpu_write(1'b1, 8'h37);            // error reset with TxEN/RxE/RTS/DTR
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h33, 1'b0, 1'b1);
        cpu_read(1'b1, status);
        check_condition(status[5], "framing error flag set on a low stop bit");
        fe_count = fe_count + 1;
        rx_resync(8'h27);
        cpu_read(1'b1, status);
        check_condition(status[5:3] == 3'b000,
                        "error reset clears parity, overrun, and framing");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h33, 1'b0, 1'b0);
        check_condition(rxrdy, "first of two frames waits unread");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h0f, 1'b0, 1'b0);
        cpu_read(1'b1, status);
        check_condition(status[4],
                        "overrun error flag set on an unread character");
        oe_count = oe_count + 1;
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h0f, "overrun keeps the newest character");
        cpu_write(1'b1, 8'h37);
        cpu_read(1'b1, status);
        check_condition(status[5:3] == 3'b000,
                        "error reset clears the overrun flag");

        $display("--- break detection and break transmission ---");
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h00, 1'b0, 1'b1);
        cpu_read(1'b1, status);
        check_condition(!status[6],
                        "one all-zero frame does not signal a break");
        drive_rx_frame(8'h00, 1'b0, 1'b1);
        check_condition(syndet_o && syndet_oe,
                        "break detect drives the shared pin");
        cpu_read(1'b1, status);
        check_condition(status[6], "break detect appears in status");
        break_count = break_count + 1;
        drive_rx_bit(1'b1, 4);
        cpu_read(1'b1, status);
        check_condition(!status[6], "break clears when RxD returns high");
        rx_resync(8'h27);
        cpu_write(1'b1, 8'h3f);            // add SBRK to the command word
        run_cycles(2);
        check_condition(txd === 1'b0, "send break forces TxD low");
        cpu_write(1'b1, 8'h37);
        run_cycles(2);
        check_condition(txd === 1'b1, "TxD returns to mark after the break");
        cpu_write(1'b1, 8'h17);            // clear the error flags the break set

        $display("--- modem status and short character lengths ---");
        @(negedge clk);
        dsr_n = 1'b0;
        step_cycle();
        cpu_read(1'b1, status);
        check_condition(status[7], "DSR status follows an active dsr_n");
        @(negedge clk);
        dsr_n = 1'b1;
        step_cycle();
        internal_reset();
        check_condition(!syndet_oe,
                        "internal reset returns to the un-programmed state");
        program_async(2'b10, 2'b00, 1'b0, 1'b0, 2'b11);   // 5 bits, 2 stop
        cpu_write(1'b1, 8'h05);
        send_and_check_frame(8'h1b);
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h1b, 1'b0, 1'b0);
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h1b, "5-bit character right-aligned and zero-filled");
        internal_reset();
        program_async(2'b10, 2'b01, 1'b1, 1'b0, 2'b10);   // 6 bits, odd, 1.5
        cpu_write(1'b1, 8'h05);
        send_and_check_frame(8'h2d);
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h2d, 1'b0, 1'b0);
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h2d, "6-bit character with odd parity");
        internal_reset();
        program_async(2'b11, 2'b10, 1'b0, 1'b0, 2'b01);   // 64x, 7 bits
        cpu_write(1'b1, 8'h05);
        send_and_check_frame(8'h49);
        internal_reset();

        $display("--- sparse baud-rate enables ---");
        tick_div = 3;
        program_async(2'b10, 2'b11, 1'b0, 1'b0, 2'b01);
        cpu_write(1'b1, 8'h05);
        send_and_check_frame(8'h7e);
        drive_rx_bit(1'b1, 4);
        drive_rx_frame(8'h7e, 1'b0, 1'b0);
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h7e, "character received with sparse baud enables");
        tick_div = 1;
        internal_reset();

        $display("--- asynchronous 1x division ---");
        program_async(2'b01, 2'b11, 1'b0, 1'b0, 2'b01);
        cpu_write(1'b1, 8'h05);
        cpu_write(1'b0, 8'hc3);
        // At 1x the start bit occupies a single baud enable, so it is visible
        // immediately after the write cycle that queued the character.
        check_condition(txd === 1'b0, "1x frame starts with a low start bit");
        run_ticks(12);
        cpu_read(1'b1, status);
        check_condition(status[2], "1x frame completes and TxEMPTY returns");
        internal_reset();

        $display("--- synchronous single sync character ---");
        program_sync(2'b11, 1'b0, 1'b0, 1'b0, 1'b1, 8'h16, 8'h00);
        check_condition(syndet_oe,
                        "SYNDET is driven with internal sync detection");
        cfg_loopback = 1'b1;
        cpu_write(1'b1, 8'h05);            // TxEN, RxE
        run_ticks(4);
        cpu_read(1'b1, status);
        check_condition(status[2],
                        "TxEMPTY flags synchronous transmitter underrun");
        run_ticks(40);
        check_condition(syndet_o, "sync pattern detected in loopback");
        syndet_count = syndet_count + 1;
        cpu_read(1'b1, status);
        check_condition(status[6], "sync detect appears in status");
        cpu_read(1'b1, status);
        check_condition(!status[6], "status read clears the sync detect flag");
        run_ticks(16);
        cpu_read(1'b0, rdata);
        check_byte(rdata, 8'h16, "sync fill character is delivered once synced");
        // The underrun flag clears only for the character time in which the
        // buffered character is actually being shifted out, so poll for it.
        cpu_write(1'b0, 8'h5c);
        seen = 1'b0;
        for (idx = 0; idx < 12; idx = idx + 1) begin
            cpu_read(1'b1, status);
            if (!status[2]) begin
                seen = 1'b1;
            end
        end
        check_condition(seen, "underrun clears once a character is buffered");
        cpu_read(1'b0, rdata);
        check_condition((rdata === 8'h5c) || (rdata === 8'h16),
                        "synchronous stream delivers buffered or fill data");
        cpu_write(1'b1, 8'h85);            // enter hunt
        run_cycles(2);
        cpu_read(1'b1, status);
        check_condition(!status[6], "enter hunt clears the sync detect flag");
        run_ticks(40);
        check_condition(syndet_o, "sync is re-acquired after enter hunt");
        cfg_loopback = 1'b0;
        internal_reset();

        $display("--- synchronous double sync character ---");
        program_sync(2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 8'h16, 8'h27);
        cfg_loopback = 1'b1;
        cpu_write(1'b1, 8'h05);
        run_ticks(64);
        check_condition(syndet_o, "double sync pattern detected in loopback");
        syndet_count = syndet_count + 1;
        run_ticks(16);
        cpu_read(1'b0, rdata);
        check_condition((rdata === 8'h16) || (rdata === 8'h27),
                        "double sync fill alternates between both characters");
        cfg_loopback = 1'b0;
        internal_reset();

        $display("--- synchronous external sync detection ---");
        program_sync(2'b11, 1'b0, 1'b0, 1'b1, 1'b1, 8'h16, 8'h00);
        check_condition(!syndet_oe,
                        "SYNDET is an input with external sync detection");
        cpu_write(1'b1, 8'h05);
        run_ticks(4);
        cpu_read(1'b1, status);
        check_condition(!status[6], "no sync detect before the external pulse");
        @(negedge clk);
        syndet_i = 1'b1;
        step_cycle();
        run_ticks(2);
        cpu_read(1'b1, status);
        check_condition(status[6], "external sync sets the sync detect flag");
        syndet_count = syndet_count + 1;
        @(negedge clk);
        syndet_i = 1'b0;
        step_cycle();
        run_ticks(16);
        cpu_read(1'b0, rdata);
        check_condition(rdata === 8'hff,
                        "idle mark assembles as an all-ones character");
        internal_reset();

        $display("--- synchronous framing with parity ---");
        program_sync(2'b11, 1'b1, 1'b1, 1'b0, 1'b1, 8'h7e, 8'h00);
        cfg_loopback = 1'b1;
        cpu_write(1'b1, 8'h05);
        run_ticks(80);
        check_condition(syndet_o, "sync detected with parity enabled");
        run_ticks(20);
        cpu_read(1'b1, status);
        check_condition(!status[3],
                        "no parity error on a self-generated sync stream");
        cfg_loopback = 1'b0;
        internal_reset();

        $display("--- deterministic pseudorandom regression ---");
        $display("Pseudorandom seed: 0x8251, operations: 2048");
        lfsr = 16'h8251;
        set_idle_bus();
        for (idx = 0; idx < 2048; idx = idx + 1) begin
            lfsr = next_lfsr(lfsr);
            op   = lfsr[2:0];
            rnd  = lfsr[10:3];
            case (op)
                3'd0: begin
                    // Reprogram from scratch with a pseudorandom mode word
                    internal_reset();
                    cpu_write(1'b1, rnd);
                    if (rnd[1:0] == 2'b00) begin
                        cpu_write(1'b1, {rnd[3:0], rnd[7:4]});
                        if (!rnd[7]) begin
                            cpu_write(1'b1, ~rnd);
                        end
                    end
                    mode_prog_count = mode_prog_count + 1;
                end
                3'd1: begin
                    cpu_write(1'b0, rnd);
                end
                3'd2: begin
                    cpu_read(1'b1, status);
                end
                3'd3: begin
                    cpu_read(1'b0, rdata);
                end
                3'd4: begin
                    // Command word with the internal-reset bit masked off
                    cpu_write(1'b1, {rnd[7], 1'b0, rnd[5:0]});
                end
                3'd5: begin
                    @(negedge clk);
                    set_idle_bus();
                    rxd = rnd[0];
                    step_cycle();
                    run_ticks({29'h0, rnd[3:1]} + 32'd1);
                end
                3'd6: begin
                    @(negedge clk);
                    set_idle_bus();
                    cts_n    = rnd[4];
                    dsr_n    = rnd[5];
                    syndet_i = rnd[6];
                    step_cycle();
                end
                default: begin
                    tick_div = {30'h0, rnd[1:0]} + 32'd1;
                    run_cycles({29'h0, rnd[6:4]} + 32'd1);
                end
            endcase
        end
        tick_div = 1;
        @(negedge clk);
        cts_n    = 1'b0;
        dsr_n    = 1'b1;
        syndet_i = 1'b0;
        rxd      = 1'b1;
        step_cycle();
        run_cycles(4);

        // ---- Coverage accounting ----
        check_condition(mode_prog_count >= 12,
                        "at least 12 mode programmings required");
        check_condition(tx_frame_count >= 10,
                        "at least 10 transmit frames decoded at the wire");
        check_condition(rx_frame_count >= 10,
                        "at least 10 receive frames driven at the wire");
        check_condition(syndet_count >= 3,
                        "at least 3 sync detections required");
        check_condition(pe_count >= 1, "a parity error must be observed");
        check_condition(fe_count >= 1, "a framing error must be observed");
        check_condition(oe_count >= 1, "an overrun error must be observed");
        check_condition(break_count >= 1, "a break must be detected");
        check_condition(cpu_read_count >= 60, "at least 60 CPU reads required");
        check_condition(cpu_write_count >= 60,
                        "at least 60 CPU writes required");
        check_condition(interface_check_count >= 12000,
                        "at least 12000 whole-interface comparisons required");

        $display("8251 simulation result: %0d cycles, %0d interface checks, %0d field checks",
                 cycle_count, interface_check_count, field_check_count);
        $display("CPU reads: %0d, CPU writes: %0d, mode programmings: %0d",
                 cpu_read_count, cpu_write_count, mode_prog_count);
        $display({"TX frames decoded: %0d, RX frames driven: %0d, ",
                  "sync detections: %0d"},
                 tx_frame_count, rx_frame_count, syndet_count);
        $display("Error events: parity %0d, framing %0d, overrun %0d, break %0d",
                 pe_count, fe_count, oe_count, break_count);
        $display("Failures: %0d", failure_count);

        if (failure_count == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "TEST FAILED with %0d failures", failure_count);
        end
    end

endmodule
