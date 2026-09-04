`timescale 1ns/1ps

// Intel 8251 / 8251A Universal Synchronous/Asynchronous Receiver Transmitter:
// synchronous, synthesizable functional reconstruction. See spec/spec.md for
// the complete behavioral contract. The historical part derives its internal
// timing from a CLK pin while sampling serial data on the free-running TxC and
// RxC baud clocks and has no register-model reset beyond the RESET pin. This
// core samples every event on `clk`, models TxC and RxC as single-cycle enable
// pulses (`txc_tick`, `rxc_tick`), and adds a synchronous `rst_n` that forces a
// defined un-programmed state.
module intel_8251 (
    input  logic       clk,
    input  logic       rst_n,

    // CPU bus
    input  logic       cs_n,
    input  logic       rd_n,
    input  logic       wr_n,
    input  logic       c_d,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,

    // Baud-rate clock enables, one pulse per historical TxC / RxC edge
    input  logic       txc_tick,
    input  logic       rxc_tick,

    // Serial transmit
    output logic       txd,
    output logic       txrdy,
    output logic       txempty,

    // Serial receive
    input  logic       rxd,
    output logic       rxrdy,

    // Shared sync-detect / break-detect pin
    input  logic       syndet_i,
    output logic       syndet_o,
    output logic       syndet_oe,

    // Modem control
    input  logic       cts_n,
    input  logic       dsr_n,
    output logic       rts_n,
    output logic       dtr_n
);

    // Programming pointer: which control register the next control write hits
    localparam logic [1:0] StMode  = 2'd0;
    localparam logic [1:0] StSync1 = 2'd1;
    localparam logic [1:0] StSync2 = 2'd2;
    localparam logic [1:0] StCmd   = 2'd3;

    // Transmitter phases
    localparam logic [2:0] TxIdle   = 3'd0;
    localparam logic [2:0] TxStart  = 3'd1;
    localparam logic [2:0] TxData   = 3'd2;
    localparam logic [2:0] TxParity = 3'd3;
    localparam logic [2:0] TxStop   = 3'd4;

    // Receiver phases
    localparam logic [2:0] RxIdle   = 3'd0;
    localparam logic [2:0] RxStart  = 3'd1;
    localparam logic [2:0] RxData   = 3'd2;
    localparam logic [2:0] RxParity = 3'd3;
    localparam logic [2:0] RxStop   = 3'd4;
    localparam logic [2:0] RxHunt   = 3'd5;

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    logic [1:0]  prog_state;
    logic [7:0]  mode_reg;
    logic [7:0]  sync_char1;
    logic [7:0]  sync_char2;
    logic [7:0]  cmd_reg;

    logic [7:0]  tx_buf;
    logic        tx_buf_full;
    logic [7:0]  tx_shift;
    logic        tx_parity;
    logic [3:0]  tx_bit_cnt;
    logic [7:0]  tx_div;
    logic [2:0]  tx_state;
    logic        txd_reg;
    logic        tx_underrun;
    logic        tx_sync_phase;

    logic [7:0]  rx_buf;
    logic        rx_buf_full;
    logic [7:0]  rx_shift;
    logic        rx_parity_acc;
    logic        rx_all_zero;
    logic [3:0]  rx_bit_cnt;
    logic [7:0]  rx_div;
    logic [2:0]  rx_state;
    logic [14:0] hunt_shift;

    logic        pe_flag;
    logic        oe_flag;
    logic        fe_flag;
    logic        syndet_flag;
    logic [1:0]  break_run;

    // ---------------------------------------------------------------------
    // Decoded mode instruction
    // ---------------------------------------------------------------------
    logic [1:0] baud_sel;
    logic [1:0] char_len_sel;
    logic       parity_en;
    logic       even_parity;
    logic [1:0] stop_sel;
    logic       ext_sync;
    logic       single_sync;
    logic       async_mode;
    logic       sync_mode;
    logic [3:0] char_bits;
    logic [3:0] char_gap;
    logic [7:0] char_mask;
    logic       configured;

    assign baud_sel     = mode_reg[1:0];
    assign char_len_sel = mode_reg[3:2];
    assign parity_en    = mode_reg[4];
    assign even_parity  = mode_reg[5];
    assign stop_sel     = mode_reg[7:6];
    assign ext_sync     = mode_reg[6];
    assign single_sync  = mode_reg[7];
    assign async_mode   = (baud_sel != 2'b00);
    assign sync_mode    = (baud_sel == 2'b00);
    assign char_bits    = 4'd5 + {2'b00, char_len_sel};
    assign char_gap     = 4'd8 - char_bits;
    assign char_mask    = 8'hff >> char_gap;
    assign configured   = (prog_state == StCmd);

    // ---------------------------------------------------------------------
    // Decoded command instruction
    // ---------------------------------------------------------------------
    logic tx_en;
    logic dtr_assert;
    logic rx_en;
    logic send_break;
    logic rts_assert;

    assign tx_en      = cmd_reg[0];
    assign dtr_assert = cmd_reg[1];
    assign rx_en      = cmd_reg[2];
    assign send_break = cmd_reg[3];
    assign rts_assert = cmd_reg[5];

    // Command bits 4 (error reset), 6 (internal reset), and 7 (enter hunt) are
    // actions taken at the write. The whole command byte is still stored, so
    // those stored bits carry no behavior.
    logic _unused_bits;
    assign _unused_bits = &{1'b0, cmd_reg[7], cmd_reg[6], cmd_reg[4]};

    // ---------------------------------------------------------------------
    // CPU bus decode
    // ---------------------------------------------------------------------
    logic bus_read;
    logic bus_write;
    logic rx_buf_read;
    logic status_read;
    logic ctrl_write;
    logic data_write;
    logic cmd_write;
    logic internal_reset;

    assign bus_read       = !cs_n && !rd_n &&  wr_n;
    assign bus_write      = !cs_n &&  rd_n && !wr_n;
    assign rx_buf_read    = bus_read  && !c_d;
    assign status_read    = bus_read  &&  c_d;
    assign ctrl_write     = bus_write &&  c_d;
    assign data_write     = bus_write && !c_d;
    assign cmd_write      = ctrl_write && (prog_state == StCmd);
    assign internal_reset = cmd_write && data_i[6];

    // ---------------------------------------------------------------------
    // Baud-rate division. `bit_period` and `half_period` count baud-clock
    // enable pulses. Synchronous mode always runs at 1x.
    // ---------------------------------------------------------------------
    logic [7:0] bit_period;
    logic [7:0] half_period;
    logic [7:0] stop_ticks;

    always_comb begin
        case (baud_sel)
            2'b00:   begin bit_period = 8'd1;  half_period = 8'd1;  end
            2'b01:   begin bit_period = 8'd1;  half_period = 8'd1;  end
            2'b10:   begin bit_period = 8'd16; half_period = 8'd8;  end
            default: begin bit_period = 8'd64; half_period = 8'd32; end
        endcase
    end

    // Stop phase length. `00` is documented as illegal and is treated as one
    // stop bit; `10` is one bit plus one half bit.
    always_comb begin
        case (stop_sel)
            2'b10:   stop_ticks = bit_period + half_period;
            2'b11:   stop_ticks = {bit_period[6:0], 1'b0};
            default: stop_ticks = bit_period;
        endcase
    end

    // ---------------------------------------------------------------------
    // Parity of the significant bits of a character
    // ---------------------------------------------------------------------
    function automatic logic char_parity(input logic [7:0] value,
                                        input logic [7:0] mask,
                                        input logic       even);
        begin
            char_parity = even ? ^(value & mask) : ~(^(value & mask));
        end
    endfunction

    // ---------------------------------------------------------------------
    // Transmitter character boundaries
    // ---------------------------------------------------------------------
    logic       tx_can_start;
    logic       tx_launch_ok;
    logic       tx_last_bit;
    logic       tx_boundary;
    logic       tx_do_launch;
    logic [7:0] tx_sync_src;
    logic [7:0] tx_char_src;

    assign tx_can_start = configured && tx_en && !cts_n && !send_break;
    assign tx_launch_ok = tx_can_start && (sync_mode || tx_buf_full);
    assign tx_last_bit  = (tx_div == 8'd0) &&
                          ((tx_state == TxParity) ||
                           ((tx_state == TxData) &&
                            (tx_bit_cnt == char_bits) && !parity_en));
    assign tx_boundary  = (tx_state == TxIdle) || (sync_mode && tx_last_bit);
    assign tx_do_launch = txc_tick && tx_boundary && tx_launch_ok;
    assign tx_sync_src  = tx_sync_phase ? sync_char2 : sync_char1;
    assign tx_char_src  = tx_buf_full ? tx_buf : tx_sync_src;

    // ---------------------------------------------------------------------
    // Receiver sync hunting. The window shifts in from the most significant
    // end, so the oldest bit of a character sits at the low end of the window
    // and a right shift right-aligns it.
    // ---------------------------------------------------------------------
    logic [15:0] hunt_win;
    logic [2:0]  hunt_align;
    logic [15:0] hunt_mask;
    logic [7:0]  hunt_cur;
    logic [15:0] hunt_prev;
    logic        hunt_match;
    logic        rx_active;
    logic        rx_exp_parity;
    logic [7:0]  rx_char;

    assign hunt_win = {rxd, hunt_shift};
    // The previous character sits two padding gaps below the current one. A
    // right shift keeps the alignment free of out-of-range part selects.
    assign hunt_align = {char_gap[1:0], 1'b0};
    assign hunt_mask  = {8'h00, char_mask};
    assign hunt_cur   = hunt_win[15:8] >> char_gap;
    assign hunt_prev  = (hunt_win >> hunt_align) & hunt_mask;
    assign hunt_match = single_sync
                        ? (hunt_cur == (sync_char1 & char_mask))
                        : ((hunt_cur == (sync_char2 & char_mask)) &&
                           (hunt_prev == {8'h00, sync_char1 & char_mask}));

    assign rx_active     = configured && rx_en;
    assign rx_exp_parity = even_parity ? rx_parity_acc : ~rx_parity_acc;
    assign rx_char       = rx_shift >> char_gap;

    // ---------------------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------------------
    logic       break_det;
    logic       syndet_status;
    logic [7:0] status_byte;

    assign break_det     = (break_run == 2'd2);
    assign syndet_status = async_mode ? break_det : syndet_flag;

    assign txd     = send_break ? 1'b0 : txd_reg;
    assign txrdy   = !tx_buf_full && configured && tx_en && !cts_n;
    assign txempty = (!tx_buf_full && (tx_state == TxIdle)) ||
                     (sync_mode && tx_underrun);
    assign rxrdy   = rx_buf_full;

    assign syndet_o  = syndet_status;
    assign syndet_oe = configured && (async_mode || !ext_sync);

    assign rts_n = ~rts_assert;
    assign dtr_n = ~dtr_assert;

    assign status_byte = {~dsr_n, syndet_status, fe_flag, oe_flag,
                          pe_flag, txempty, rx_buf_full, ~tx_buf_full};

    always_comb begin
        data_o  = 8'h00;
        data_oe = 1'b0;
        if (bus_read) begin
            data_oe = 1'b1;
            data_o  = c_d ? status_byte : rx_buf;
        end
    end

    // ---------------------------------------------------------------------
    // Sequential state. Effects are applied in specification order: CPU read
    // side effects, transmitter, receiver, then CPU writes, so a CPU write
    // wins any conflict with an internal update in the same cycle.
    // ---------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n || internal_reset) begin
            prog_state    <= StMode;
            mode_reg      <= 8'h00;
            sync_char1    <= 8'h00;
            sync_char2    <= 8'h00;
            cmd_reg       <= 8'h00;

            tx_buf        <= 8'h00;
            tx_buf_full   <= 1'b0;
            tx_shift      <= 8'h00;
            tx_parity     <= 1'b0;
            tx_bit_cnt    <= 4'd0;
            tx_div        <= 8'd0;
            tx_state      <= TxIdle;
            txd_reg       <= 1'b1;
            tx_underrun   <= 1'b0;
            tx_sync_phase <= 1'b0;

            rx_buf        <= 8'h00;
            rx_buf_full   <= 1'b0;
            rx_shift      <= 8'h00;
            rx_parity_acc <= 1'b0;
            rx_all_zero   <= 1'b0;
            rx_bit_cnt    <= 4'd0;
            rx_div        <= 8'd0;
            rx_state      <= RxIdle;
            hunt_shift    <= 15'h0000;

            pe_flag       <= 1'b0;
            oe_flag       <= 1'b0;
            fe_flag       <= 1'b0;
            syndet_flag   <= 1'b0;
            break_run     <= 2'd0;
        end else begin
            // ---- CPU read side effects ----
            if (rx_buf_read) begin
                rx_buf_full <= 1'b0;
            end
            if (status_read) begin
                syndet_flag <= 1'b0;
            end

            // ---- Transmitter ----
            if (txc_tick) begin
                if (tx_do_launch) begin
                    tx_parity <= char_parity(tx_char_src, char_mask,
                                             even_parity);
                    tx_div    <= bit_period - 8'd1;
                    if (tx_buf_full) begin
                        tx_buf_full   <= 1'b0;
                        tx_underrun   <= 1'b0;
                        tx_sync_phase <= 1'b0;
                    end else begin
                        // Synchronous underrun: send sync-character fill.
                        tx_underrun   <= 1'b1;
                        tx_sync_phase <= single_sync ? 1'b0 : ~tx_sync_phase;
                    end
                    if (async_mode) begin
                        tx_shift   <= tx_char_src;
                        txd_reg    <= 1'b0;
                        tx_bit_cnt <= 4'd0;
                        tx_state   <= TxStart;
                    end else begin
                        tx_shift   <= {1'b0, tx_char_src[7:1]};
                        txd_reg    <= tx_char_src[0];
                        tx_bit_cnt <= 4'd1;
                        tx_state   <= TxData;
                    end
                end else if (tx_state == TxIdle) begin
                    txd_reg <= 1'b1;
                end else if (tx_div != 8'd0) begin
                    tx_div <= tx_div - 8'd1;
                end else begin
                    case (tx_state)
                        TxStart: begin
                            txd_reg    <= tx_shift[0];
                            tx_shift   <= {1'b0, tx_shift[7:1]};
                            tx_bit_cnt <= 4'd1;
                            tx_div     <= bit_period - 8'd1;
                            tx_state   <= TxData;
                        end
                        TxData: begin
                            if (tx_bit_cnt < char_bits) begin
                                txd_reg    <= tx_shift[0];
                                tx_shift   <= {1'b0, tx_shift[7:1]};
                                tx_bit_cnt <= tx_bit_cnt + 4'd1;
                                tx_div     <= bit_period - 8'd1;
                            end else if (parity_en) begin
                                txd_reg  <= tx_parity;
                                tx_div   <= bit_period - 8'd1;
                                tx_state <= TxParity;
                            end else if (async_mode) begin
                                txd_reg  <= 1'b1;
                                tx_div   <= stop_ticks - 8'd1;
                                tx_state <= TxStop;
                            end else begin
                                txd_reg    <= 1'b1;
                                tx_bit_cnt <= 4'd0;
                                tx_state   <= TxIdle;
                            end
                        end
                        TxParity: begin
                            if (async_mode) begin
                                txd_reg  <= 1'b1;
                                tx_div   <= stop_ticks - 8'd1;
                                tx_state <= TxStop;
                            end else begin
                                txd_reg    <= 1'b1;
                                tx_bit_cnt <= 4'd0;
                                tx_state   <= TxIdle;
                            end
                        end
                        TxStop: begin
                            txd_reg    <= 1'b1;
                            tx_bit_cnt <= 4'd0;
                            tx_state   <= TxIdle;
                        end
                        default: begin
                            txd_reg    <= 1'b1;
                            tx_bit_cnt <= 4'd0;
                            tx_state   <= TxIdle;
                        end
                    endcase
                end
            end

            // ---- Receiver ----
            if (!rx_active) begin
                rx_state      <= async_mode ? RxIdle : RxHunt;
                rx_shift      <= 8'h00;
                rx_parity_acc <= 1'b0;
                rx_all_zero   <= 1'b0;
                rx_bit_cnt    <= 4'd0;
                rx_div        <= 8'd0;
                hunt_shift    <= 15'h0000;
                break_run     <= 2'd0;
            end else begin
                // A high on RxD ends any break condition.
                if (async_mode && rxd) begin
                    break_run <= 2'd0;
                end

                if (rxc_tick) begin
                    if (rx_div != 8'd0) begin
                        rx_div <= rx_div - 8'd1;
                    end else begin
                        case (rx_state)
                            RxIdle: begin
                                if (!rxd) begin
                                    rx_div   <= half_period - 8'd1;
                                    rx_state <= RxStart;
                                end
                            end
                            RxStart: begin
                                if (rxd) begin
                                    // False start bit.
                                    rx_state <= RxIdle;
                                end else begin
                                    rx_shift      <= 8'h00;
                                    rx_parity_acc <= 1'b0;
                                    rx_all_zero   <= 1'b1;
                                    rx_bit_cnt    <= 4'd0;
                                    rx_div        <= bit_period - 8'd1;
                                    rx_state      <= RxData;
                                end
                            end
                            RxData: begin
                                rx_shift      <= {rxd, rx_shift[7:1]};
                                rx_parity_acc <= rx_parity_acc ^ rxd;
                                rx_all_zero   <= rx_all_zero && !rxd;
                                rx_bit_cnt    <= rx_bit_cnt + 4'd1;
                                rx_div        <= bit_period - 8'd1;
                                if ((rx_bit_cnt + 4'd1) == char_bits) begin
                                    if (parity_en) begin
                                        rx_state <= RxParity;
                                    end else if (async_mode) begin
                                        rx_state <= RxStop;
                                    end else begin
                                        // Synchronous delivery, then the next
                                        // character starts immediately.
                                        if (rx_buf_full && !rx_buf_read) begin
                                            oe_flag <= 1'b1;
                                        end
                                        rx_buf        <= {rxd, rx_shift[7:1]} >>
                                                         char_gap;
                                        rx_buf_full   <= 1'b1;
                                        rx_shift      <= 8'h00;
                                        rx_parity_acc <= 1'b0;
                                        rx_bit_cnt    <= 4'd0;
                                    end
                                end
                            end
                            RxParity: begin
                                rx_all_zero <= rx_all_zero && !rxd;
                                if (rxd != rx_exp_parity) begin
                                    pe_flag <= 1'b1;
                                end
                                rx_div <= bit_period - 8'd1;
                                if (async_mode) begin
                                    rx_state <= RxStop;
                                end else begin
                                    if (rx_buf_full && !rx_buf_read) begin
                                        oe_flag <= 1'b1;
                                    end
                                    rx_buf        <= rx_char;
                                    rx_buf_full   <= 1'b1;
                                    rx_shift      <= 8'h00;
                                    rx_parity_acc <= 1'b0;
                                    rx_bit_cnt    <= 4'd0;
                                    rx_state      <= RxData;
                                end
                            end
                            RxStop: begin
                                if (!rxd) begin
                                    fe_flag <= 1'b1;
                                end
                                if (rx_all_zero && !rxd) begin
                                    break_run <= (break_run == 2'd2)
                                                 ? 2'd2 : break_run + 2'd1;
                                end else begin
                                    break_run <= 2'd0;
                                end
                                if (rx_buf_full && !rx_buf_read) begin
                                    oe_flag <= 1'b1;
                                end
                                rx_buf      <= rx_char;
                                rx_buf_full <= 1'b1;
                                rx_state    <= RxIdle;
                            end
                            RxHunt: begin
                                hunt_shift <= hunt_win[15:1];
                                if (ext_sync ? syndet_i : hunt_match) begin
                                    syndet_flag   <= 1'b1;
                                    rx_shift      <= 8'h00;
                                    rx_parity_acc <= 1'b0;
                                    rx_bit_cnt    <= 4'd0;
                                    rx_state      <= RxData;
                                end
                            end
                            default: begin
                                rx_state <= async_mode ? RxIdle : RxHunt;
                            end
                        endcase
                    end
                end
            end

            // ---- CPU writes ----
            if (ctrl_write) begin
                case (prog_state)
                    StMode: begin
                        mode_reg   <= data_i;
                        prog_state <= (data_i[1:0] == 2'b00) ? StSync1 : StCmd;
                    end
                    StSync1: begin
                        sync_char1 <= data_i;
                        prog_state <= single_sync ? StCmd : StSync2;
                    end
                    StSync2: begin
                        sync_char2 <= data_i;
                        prog_state <= StCmd;
                    end
                    default: begin
                        cmd_reg <= data_i;
                        if (data_i[4]) begin
                            pe_flag <= 1'b0;
                            oe_flag <= 1'b0;
                            fe_flag <= 1'b0;
                        end
                        if (data_i[7] && sync_mode) begin
                            // Enter hunt: restart the sync search. The bit has
                            // no effect in asynchronous mode.
                            syndet_flag   <= 1'b0;
                            hunt_shift    <= 15'h0000;
                            rx_shift      <= 8'h00;
                            rx_parity_acc <= 1'b0;
                            rx_bit_cnt    <= 4'd0;
                            rx_div        <= 8'd0;
                            rx_state      <= RxHunt;
                        end
                    end
                endcase
            end else if (data_write) begin
                tx_buf      <= data_i;
                tx_buf_full <= 1'b1;
            end
        end
    end

`ifdef FORMAL
`ifdef FORMAL_COVER
    intel_8251_cover formal_coverage (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .c_d           (c_d),
        .data_i        (data_i),
        .txc_tick      (txc_tick),
        .rxc_tick      (rxc_tick),
        .rxd           (rxd),
        .syndet_i      (syndet_i),
        .cts_n         (cts_n),
        .dsr_n         (dsr_n),
        .txd           (txd),
        .txrdy         (txrdy),
        .txempty       (txempty),
        .rxrdy         (rxrdy),
        .syndet_o      (syndet_o),
        .syndet_oe     (syndet_oe),
        .data_oe       (data_oe),
        .prog_state    (prog_state),
        .configured    (configured),
        .async_mode    (async_mode),
        .tx_state      (tx_state),
        .tx_buf_full   (tx_buf_full),
        .tx_underrun   (tx_underrun),
        .rx_state      (rx_state),
        .rx_buf        (rx_buf),
        .rx_buf_full   (rx_buf_full),
        .pe_flag       (pe_flag),
        .oe_flag       (oe_flag),
        .fe_flag       (fe_flag),
        .syndet_flag   (syndet_flag),
        .break_run     (break_run)
    );
`else
    intel_8251_props formal_properties (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .c_d           (c_d),
        .data_i        (data_i),
        .data_o        (data_o),
        .data_oe       (data_oe),
        .txc_tick      (txc_tick),
        .rxc_tick      (rxc_tick),
        .txd           (txd),
        .txrdy         (txrdy),
        .txempty       (txempty),
        .rxd           (rxd),
        .rxrdy         (rxrdy),
        .syndet_i      (syndet_i),
        .syndet_o      (syndet_o),
        .syndet_oe     (syndet_oe),
        .cts_n         (cts_n),
        .dsr_n         (dsr_n),
        .rts_n         (rts_n),
        .dtr_n         (dtr_n),
        .prog_state    (prog_state),
        .mode_reg      (mode_reg),
        .sync_char1    (sync_char1),
        .sync_char2    (sync_char2),
        .cmd_reg       (cmd_reg),
        .tx_buf        (tx_buf),
        .tx_buf_full   (tx_buf_full),
        .tx_shift      (tx_shift),
        .tx_parity     (tx_parity),
        .tx_bit_cnt    (tx_bit_cnt),
        .tx_div        (tx_div),
        .tx_state      (tx_state),
        .txd_reg       (txd_reg),
        .tx_underrun   (tx_underrun),
        .tx_sync_phase (tx_sync_phase),
        .rx_buf        (rx_buf),
        .rx_buf_full   (rx_buf_full),
        .rx_shift      (rx_shift),
        .rx_parity_acc (rx_parity_acc),
        .rx_all_zero   (rx_all_zero),
        .rx_bit_cnt    (rx_bit_cnt),
        .rx_div        (rx_div),
        .rx_state      (rx_state),
        .hunt_shift    (hunt_shift),
        .pe_flag       (pe_flag),
        .oe_flag       (oe_flag),
        .fe_flag       (fe_flag),
        .syndet_flag   (syndet_flag),
        .break_run     (break_run)
    );
`endif
`endif

endmodule
