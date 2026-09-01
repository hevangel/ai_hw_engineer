// Formal safety and equivalence properties for the Intel 8251/8251A
// reconstruction.
//
// The combinational block re-derives every output as a pure function of the
// registered state and the current bus inputs, then asserts equality with the
// DUT. That proves the outputs carry no hidden state dependence and follow the
// derivation given in the specification. The sequential block proves the
// programming-pointer transitions, the register-write contract, error-flag
// behavior, buffer-fill provenance, and a set of state-space invariants that
// bound the transmitter and receiver phase machines and their bit and division
// counters. Reset is assumed only in the initial formal cycle; it is otherwise
// unconstrained, so synchronous reset priority is checked rather than assumed.
module intel_8251_props (
    input logic        clk,
    input logic        rst_n,
    input logic        cs_n,
    input logic        rd_n,
    input logic        wr_n,
    input logic        c_d,
    input logic [7:0]  data_i,
    input logic [7:0]  data_o,
    input logic        data_oe,
    input logic        txc_tick,
    input logic        rxc_tick,
    input logic        txd,
    input logic        txrdy,
    input logic        txempty,
    input logic        rxd,
    input logic        rxrdy,
    input logic        syndet_i,
    input logic        syndet_o,
    input logic        syndet_oe,
    input logic        cts_n,
    input logic        dsr_n,
    input logic        rts_n,
    input logic        dtr_n,
    input logic [1:0]  prog_state,
    input logic [7:0]  mode_reg,
    input logic [7:0]  sync_char1,
    input logic [7:0]  sync_char2,
    input logic [7:0]  cmd_reg,
    input logic [7:0]  tx_buf,
    input logic        tx_buf_full,
    input logic [7:0]  tx_shift,
    input logic        tx_parity,
    input logic [3:0]  tx_bit_cnt,
    input logic [7:0]  tx_div,
    input logic [2:0]  tx_state,
    input logic        txd_reg,
    input logic        tx_underrun,
    input logic        tx_sync_phase,
    input logic [7:0]  rx_buf,
    input logic        rx_buf_full,
    input logic [7:0]  rx_shift,
    input logic        rx_parity_acc,
    input logic        rx_all_zero,
    input logic [3:0]  rx_bit_cnt,
    input logic [7:0]  rx_div,
    input logic [2:0]  rx_state,
    input logic [14:0] hunt_shift,
    input logic        pe_flag,
    input logic        oe_flag,
    input logic        fe_flag,
    input logic        syndet_flag,
    input logic [1:0]  break_run
);

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

    // Decoded mode instruction, re-derived independently of the DUT
    logic [1:0] baud_sel;
    logic       parity_en;
    logic       even_parity;
    logic [1:0] stop_sel;
    logic       ext_sync;
    logic       single_sync;
    logic       async_mode;
    logic       sync_mode;
    logic [3:0] char_bits;
    logic       configured;

    assign baud_sel    = mode_reg[1:0];
    assign parity_en   = mode_reg[4];
    assign even_parity = mode_reg[5];
    assign stop_sel    = mode_reg[7:6];
    assign ext_sync    = mode_reg[6];
    assign single_sync = mode_reg[7];
    assign async_mode  = (baud_sel != 2'b00);
    assign sync_mode   = (baud_sel == 2'b00);
    assign char_bits   = 4'd5 + {2'b00, mode_reg[3:2]};
    assign configured  = (prog_state == StCmd);

    logic tx_en;
    logic rx_en;
    logic send_break;
    logic rx_active;

    assign tx_en      = cmd_reg[0];
    assign rx_en      = cmd_reg[2];
    assign send_break = cmd_reg[3];
    assign rx_active  = configured && rx_en;

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

    always_comb begin
        case (stop_sel)
            2'b10:   stop_ticks = bit_period + half_period;
            2'b11:   stop_ticks = {bit_period[6:0], 1'b0};
            default: stop_ticks = bit_period;
        endcase
    end

    // Expected outputs
    logic       exp_break_det;
    logic       exp_syndet;
    logic       exp_txempty;
    logic [7:0] exp_status;
    logic [7:0] exp_data_o;
    logic       exp_data_oe;

    assign exp_break_det = (break_run == 2'd2);
    assign exp_syndet    = async_mode ? exp_break_det : syndet_flag;
    assign exp_txempty   = (!tx_buf_full && (tx_state == TxIdle)) ||
                           (sync_mode && tx_underrun);
    assign exp_status    = {~dsr_n, exp_syndet, fe_flag, oe_flag,
                            pe_flag, exp_txempty, rx_buf_full, ~tx_buf_full};

    always_comb begin
        exp_data_o  = 8'h00;
        exp_data_oe = 1'b0;
        if (bus_read) begin
            exp_data_oe = 1'b1;
            exp_data_o  = c_d ? exp_status : rx_buf;
        end
    end

    // Combinational equivalence and structural safety (hold in any state)
    always_comb begin
        assert ({data_o, data_oe} == {exp_data_o, exp_data_oe});
        assert (txd == (send_break ? 1'b0 : txd_reg));
        assert (txrdy == (!tx_buf_full && configured && tx_en && !cts_n));
        assert (txempty == exp_txempty);
        assert (rxrdy == rx_buf_full);
        assert (syndet_o == exp_syndet);
        assert (syndet_oe == (configured && (async_mode || !ext_sync)));
        assert (rts_n == ~cmd_reg[5]);
        assert (dtr_n == ~cmd_reg[1]);

        // Structural safety
        assert (!data_oe || bus_read);
        assert (!bus_read || !bus_write);
        assert (!txrdy || (!tx_buf_full && !cts_n && configured));
        assert (!syndet_oe || configured);
        assert (!txempty || !tx_buf_full || sync_mode);
    end

    // Sequential behavioral properties and state-space invariants
    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end else if (!$past(rst_n) || $past(internal_reset)) begin
            // Synchronous reset priority, shared by hardware and internal reset
            assert (prog_state == StMode);
            assert (mode_reg == 8'h00);
            assert (sync_char1 == 8'h00);
            assert (sync_char2 == 8'h00);
            assert (cmd_reg == 8'h00);
            assert (tx_buf == 8'h00);
            assert (!tx_buf_full);
            assert (tx_shift == 8'h00);
            assert (!tx_parity);
            assert (tx_bit_cnt == 4'd0);
            assert (tx_div == 8'd0);
            assert (tx_state == TxIdle);
            assert (txd_reg);
            assert (!tx_underrun);
            assert (!tx_sync_phase);
            assert (rx_buf == 8'h00);
            assert (!rx_buf_full);
            assert (rx_shift == 8'h00);
            assert (!rx_parity_acc);
            assert (!rx_all_zero);
            assert (rx_bit_cnt == 4'd0);
            assert (rx_div == 8'd0);
            assert (rx_state == RxIdle);
            assert (hunt_shift == 15'h0000);
            assert (!pe_flag);
            assert (!oe_flag);
            assert (!fe_flag);
            assert (!syndet_flag);
            assert (break_run == 2'd0);
        end else begin
            // ---- Programming pointer and control-register writes ----
            if ($past(ctrl_write) && ($past(prog_state) == StMode)) begin
                assert (mode_reg == $past(data_i));
                assert (prog_state == (($past(data_i[1:0]) == 2'b00)
                                       ? StSync1 : StCmd));
            end else begin
                assert (mode_reg == $past(mode_reg));
            end

            if ($past(ctrl_write) && ($past(prog_state) == StSync1)) begin
                assert (sync_char1 == $past(data_i));
                assert (prog_state == ($past(single_sync) ? StCmd : StSync2));
            end else begin
                assert (sync_char1 == $past(sync_char1));
            end

            if ($past(ctrl_write) && ($past(prog_state) == StSync2)) begin
                assert (sync_char2 == $past(data_i));
                assert (prog_state == StCmd);
            end else begin
                assert (sync_char2 == $past(sync_char2));
            end

            // Reaching this branch with a past command write means the internal
            // reset bit was clear, so the command byte is retained as written.
            if ($past(cmd_write)) begin
                assert (cmd_reg == $past(data_i));
                assert (prog_state == StCmd);
                assert (dtr_n == ~$past(data_i[1]));
                assert (rts_n == ~$past(data_i[5]));
            end else begin
                assert (cmd_reg == $past(cmd_reg));
            end

            // ---- Error flags ----
            if ($past(cmd_write) && $past(data_i[4])) begin
                assert (!pe_flag);
                assert (!oe_flag);
                assert (!fe_flag);
            end else begin
                // Error flags are sticky until an error reset or a reset
                assert (!$past(pe_flag) || pe_flag);
                assert (!$past(oe_flag) || oe_flag);
                assert (!$past(fe_flag) || fe_flag);
            end

            // ---- Buffer fill provenance ----
            if ($past(data_write)) begin
                assert (tx_buf_full);
                assert (tx_buf == $past(data_i));
            end
            if (!$past(tx_buf_full) && tx_buf_full) begin
                assert ($past(data_write));
            end
            if (!$past(rx_buf_full) && rx_buf_full) begin
                assert ($past(rxc_tick) && $past(rx_active));
            end

            // A status read clears the sync-detect flag; the only way it can be
            // set again in the same cycle is the receiver detecting sync.
            if ($past(status_read) && syndet_flag) begin
                assert ($past(rxc_tick) && $past(rx_active) &&
                        ($past(rx_state) == RxHunt));
            end

            // ---- State-space invariants ----
            assert (tx_state <= TxStop);
            assert (rx_state <= RxHunt);

            // Nothing runs before the command instruction is reachable
            assert (configured || (cmd_reg == 8'h00));
            assert (configured || (tx_state == TxIdle));
            assert (configured || (tx_bit_cnt == 4'd0));
            assert (configured || (tx_div == 8'd0));

            // Transmitter phase bounds
            assert ((tx_state != TxIdle) || (tx_div == 8'd0));
            assert ((tx_state != TxIdle) || (tx_bit_cnt == 4'd0));
            assert ((tx_state == TxStop) || (tx_div < bit_period));
            assert ((tx_state != TxStop) || (tx_div < stop_ticks));
            assert ((tx_state != TxData) || ((tx_bit_cnt >= 4'd1) &&
                                            (tx_bit_cnt <= char_bits)));
            assert ((tx_state != TxParity) || (tx_bit_cnt == char_bits));
            assert (async_mode || (tx_state != TxStop));
            assert (async_mode || (tx_state != TxStart));

            // Receiver phase bounds
            assert ((rx_state != RxIdle) || (rx_div == 8'd0));
            assert ((rx_state != RxHunt) || (rx_div == 8'd0));
            assert ((rx_state != RxStart) || (rx_div < half_period));
            assert ((rx_state != RxData) || (rx_bit_cnt < char_bits));
            assert ((rx_state != RxParity) || (rx_bit_cnt == char_bits));
            assert ((rx_state == RxStart) || (rx_div < bit_period));
            assert (!rx_active || async_mode ||
                    ((rx_state != RxIdle) && (rx_state != RxStart) &&
                     (rx_state != RxStop)));
        end
    end

    // Serial-side inputs and decoded fields that this property set does not
    // constrain. Bit-stream correctness is covered by the simulation
    // regression, which can observe a whole character time.
    logic _unused_props;
    assign _unused_props = &{1'b0, txc_tick, rxd, syndet_i,
                             parity_en, even_parity};

endmodule
