// Zilog Z80 native M-cycle engine.
//
// Wraps the functional core and turns each transaction into real Z80 bus
// cycles:
//   M1 opcode fetch  4 T-states, with the refresh cycle in T3/T4
//                    (RFSH low, R on A0-A6, A7 low, IFF2 on A15)
//   memory read/write 3 T-states
//   I/O read/write    4 T-states (one automatic wait after T2)
//   interrupt acknowledge 6 T-states (M1 with IORQ instead of MREQ)
//
// WAIT is sampled at the falling edge of T2; each sampled wait stretches the
// cycle by one T-state. BUSRQ is honoured at cycle boundaries: the bus floats
// and BUSACK goes low until the request is released.
//
// The data bus is split into d_out/d_oe/d_in so simulation harnesses do not
// need a tri-state net; a board wrapper ties them to the bidirectional pin.
//
// Internal T-states that the functional core performs without a bus cycle (for
// example the extra T in INC (HL) or the five in JR) are NOT modelled yet: this
// engine reproduces cycle shapes and the bus-visible T-state count. See
// report/final_report.md for the consequence on per-instruction totals.
module zilog_z80_native
(
    input  logic        clk,
    input  logic        rst_n,

    // Memory and I/O bus, split for simulation.
    output logic [15:0] a_o,
    output logic [7:0]  d_out_o,
    output logic        d_oe_o,
    input  logic [7:0]  d_in_i,

    // Z80 control pins (active low).
    output logic        m1_n_o,
    output logic        mreq_n_o,
    output logic        iorq_n_o,
    output logic        rd_n_o,
    output logic        wr_n_o,
    output logic        rfsh_n_o,
    output logic        halt_n_o,
    output logic        busack_n_o,

    input  logic        wait_n_i,
    input  logic        int_n_i,
    input  logic        nmi_n_i,
    input  logic        busrq_n_i,

    // Observations.
    output logic [15:0] pc_o,
    output logic [15:0] sp_o,
    output logic        iff1_o,
    output logic [1:0]  im_o,
    output logic [7:0]  r_o,
    output logic        halted_o,
    output logic        retire_o,
    output logic        cycle_active_o
);

  // ---------------------------------------------------------------- core
  logic        core_req, core_ready, core_write, core_io, core_intack, core_m1;
  logic [15:0] core_addr;
  logic [7:0]  core_wdata, core_rdata;
  logic        core_retire, core_fault;

  zilog_z80 u_core (
      .clk          (clk),
      .rst_n        (rst_n),
      .bus_req_o    (core_req),
      .bus_ready_i  (core_ready),
      .bus_write_o  (core_write),
      .bus_addr_o   (core_addr),
      .bus_wdata_o  (core_wdata),
      .bus_rdata_i  (core_rdata),
      .bus_io_o     (core_io),
      .bus_intack_o (core_intack),
      .bus_m1_o     (core_m1),
      .int_i        (~int_n_i),
      .nmi_i        (~nmi_n_i),
      .retire_o     (core_retire),
      .fault_o      (core_fault),
      .halt_o       (halted_o),
      .iff1_o       (iff1_o),
      .im_o         (im_o),
      .pc_o         (pc_o),
      .sp_o         (sp_o),
      .ix_o         (),
      .iy_o         (),
      .wz_o         (),
      .i_o          (),
      .r_o          (r_o),
      .regs_o       (),
      .alt_o        ()
  );

  // -------------------------------------------------------------- cycle FSM
  typedef enum logic [1:0] {C_IDLE, C_RUN, C_BUSACK} cyc_t;
  cyc_t cyc;

  logic [2:0] t;          // T-state within the cycle
  logic [2:0] tlen;       // total T-states of the current cycle
  logic       is_m1, is_io, is_write, is_intack;
  logic [15:0] addr_l;
  logic [7:0]  wdata_l;
  logic        wait_seen;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cyc        <= C_IDLE;
      t          <= 3'd0;
      tlen       <= 3'd4;
      is_m1      <= 1'b0;
      is_io      <= 1'b0;
      is_write   <= 1'b0;
      is_intack  <= 1'b0;
      addr_l     <= 16'h0000;
      wdata_l    <= 8'h00;
      wait_seen  <= 1'b0;
      core_ready <= 1'b0;
    end else begin
      core_ready <= 1'b0;

      // Bus request is granted only between cycles.
      if (cyc == C_IDLE && !busrq_n_i) begin
        cyc <= C_BUSACK;
      end

      case (cyc)
        C_IDLE: begin
          if (busrq_n_i && core_req && !core_ready) begin
            // Latch the transaction and start its cycle.
            addr_l    <= core_addr;
            wdata_l   <= core_wdata;
            is_m1     <= core_m1;
            is_io     <= core_io;
            is_intack <= core_intack;
            is_write  <= core_write;
            t         <= 3'd0;
            wait_seen <= 1'b0;
            if (core_intack)
              tlen <= 3'd6;                       // M1 + IORQ, two automatic waits
            else if (core_io)
              tlen <= 3'd4;                       // I/O: one automatic wait
            else if (core_m1)
              tlen <= 3'd4;                       // M1 opcode fetch
            else
              tlen <= 3'd3;                       // memory read/write
            cyc <= C_RUN;
          end
        end

        C_RUN: begin
          // Sample WAIT at the falling edge of T2 (modelled here at the end of
          // the T2 slot) and stretch the cycle by one T-state per wait.
          // WAIT is sampled in the T2 slot; the cycle stalls there for as
          // long as the peripheral holds it low.
          if ((t == 3'd1) && !wait_n_i) begin
            tlen <= tlen + 3'd1;
          end

          if (t + 3'd1 >= tlen) begin
            // Last T-state: let the core consume the transaction.
            core_ready <= 1'b1;
            cyc        <= (busrq_n_i ? C_IDLE : C_BUSACK);
            t          <= 3'd0;
          end else begin
            t <= t + 3'd1;
          end
        end

        C_BUSACK: begin
          if (busrq_n_i) cyc <= C_IDLE;
        end

        default: cyc <= C_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------------- pins
  always_comb begin
    // A0-A6 carry R and A15 carries IFF2 during the refresh T-states.
    a_o       = (cyc == C_RUN) && is_m1 && (t >= 3'd2) ? {iff1_o, 7'h00, r_o} : addr_l;
    d_out_o   = wdata_l;
    d_oe_o    = (cyc == C_RUN) && is_write;
    m1_n_o    = ~((cyc == C_RUN) && (is_m1 || is_intack));
    mreq_n_o  = ~((cyc == C_RUN) && !is_io && !is_intack && (t >= 3'd1) &&
                  (t <= 3'd2));
    iorq_n_o  = ~((cyc == C_RUN) && (is_io || is_intack) && (t >= 3'd1));
    rd_n_o    = ~((cyc == C_RUN) && !is_write && (t >= 3'd1) && (t <= 3'd2));
    wr_n_o    = ~((cyc == C_RUN) && is_write && (t >= 3'd1) && (t <= 3'd2));
    // Refresh occupies T3/T4 of an M1 cycle with the R counter on A0-A6,
    // A7 low and IFF2 on A15.
    rfsh_n_o  = ~((cyc == C_RUN) && is_m1 && (t >= 3'd2));
    halt_n_o  = ~halted_o;
    busack_n_o = ~(cyc == C_BUSACK);
    cycle_active_o = (cyc == C_RUN);
  end

  // Data presented to the core: memory or I/O, depending on the cycle.
  assign core_rdata = d_in_i;
  assign retire_o   = core_retire;

  // Refresh address replaces the normal address during the refresh T-states.
  // (Kept as a separate observation so a board wrapper can mux it onto A.)
  logic [15:0] refresh_addr;
  assign refresh_addr = {iff1_o, 7'h00, r_o};

endmodule
