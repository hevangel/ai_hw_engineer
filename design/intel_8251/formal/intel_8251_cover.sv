// Reachability (non-vacuity) covers for the Intel 8251/8251A reconstruction.
//
// The environment is left free apart from two constraints that keep witness
// traces short enough to find inside the cover depth: reset is asserted only in
// the initial formal cycle, and both baud-rate clock enables are held asserted
// so one core clock equals one baud-clock pulse. Everything else, including the
// CPU bus, `RxD`, the modem inputs, and the external sync input, is
// unconstrained, so the solver is free to choose the programming sequence and
// the serial stimulus that reaches each cover.
//
// The covers demonstrate that both framing modes, the full asynchronous frame,
// every error flag, break detection, sync detection, synchronous underrun fill,
// and both CPU read paths are reachable, which is what makes the safety
// property set non-vacuous.
module intel_8251_cover (
    input logic       clk,
    input logic       rst_n,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic       c_d,
    input logic [7:0] data_i,
    input logic       txc_tick,
    input logic       rxc_tick,
    input logic       rxd,
    input logic       syndet_i,
    input logic       cts_n,
    input logic       dsr_n,
    input logic       txd,
    input logic       txrdy,
    input logic       txempty,
    input logic       rxrdy,
    input logic       syndet_o,
    input logic       syndet_oe,
    input logic       data_oe,
    input logic [1:0] prog_state,
    input logic       configured,
    input logic       async_mode,
    input logic [2:0] tx_state,
    input logic       tx_buf_full,
    input logic       tx_underrun,
    input logic [2:0] rx_state,
    input logic [7:0] rx_buf,
    input logic       rx_buf_full,
    input logic       pe_flag,
    input logic       oe_flag,
    input logic       fe_flag,
    input logic       syndet_flag,
    input logic [1:0] break_run
);

    localparam logic [1:0] StMode = 2'd0;

    localparam logic [2:0] TxIdle = 3'd0;
    localparam logic [2:0] TxStop = 3'd4;
    localparam logic [2:0] RxHunt = 3'd5;

    logic bus_read;
    assign bus_read = !cs_n && !rd_n && wr_n;

    always_ff @(posedge clk) begin
        // Reset in the initial cycle only; the baud enables always fire.
        if ($initstate) begin
            assume (!rst_n);
        end else begin
            assume (rst_n);
        end
        assume (txc_tick);
        assume (rxc_tick);

        // C1: the device is programmed for asynchronous framing
        cover (!$initstate && configured && async_mode);
        // C2: the device is programmed for synchronous framing
        cover (!$initstate && configured && !async_mode);
        // C3: a transmit character reaches the stop phase
        cover (!$initstate && (tx_state == TxStop));
        // C4: a complete asynchronous frame is driven and the transmitter
        //     returns to idle. Cover mode leaves the pre-reset state free, so
        //     the configured qualifier keeps this witness from being vacuous.
        cover (!$initstate && configured && async_mode &&
               ($past(tx_state) == TxStop) && (tx_state == TxIdle));
        // C5: a received character is available to the CPU
        cover (!$initstate && rxrdy && async_mode);
        // C6: parity error
        cover (!$initstate && pe_flag);
        // C7: framing error
        cover (!$initstate && fe_flag);
        // C8: overrun error
        cover (!$initstate && oe_flag);
        // C9: break detected and driven on the shared pin
        cover (!$initstate && async_mode && syndet_oe && syndet_o &&
               (break_run == 2'd2));
        // C10: sync pattern detected, receiver has left hunt
        cover (!$initstate && !async_mode && syndet_flag &&
               (rx_state != RxHunt));
        // C11: synchronous transmitter underrun drives sync-character fill
        cover (!$initstate && !async_mode && tx_underrun && txempty);
        // C12: a status read drives the CPU bus
        cover (!$initstate && bus_read && c_d && data_oe);
        // C13: a receive-buffer read returns a non-zero character
        cover (!$initstate && bus_read && !c_d && data_oe && (rx_buf != 8'h00));
        // C14: the transmit buffer is loaded while a character is in flight
        cover (!$initstate && tx_buf_full && (tx_state != TxIdle) && !txrdy);
        // C15: an internal reset returns the programming pointer to the mode
        //      instruction after the device was configured. Requiring reset to
        //      have been released in the previous cycle rules out the free
        //      pre-reset state as a witness.
        cover (!$initstate && (prog_state == StMode) && $past(configured) &&
               $past(rst_n));
    end

    // Inputs and status bits that no cover constrains
    logic _unused_cover;
    assign _unused_cover = &{1'b0, rxd, syndet_i, cts_n, dsr_n, txd};

endmodule
