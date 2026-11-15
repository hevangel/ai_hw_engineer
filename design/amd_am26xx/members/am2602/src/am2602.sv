`timescale 1ns/1ps
// Am2602 dual retriggerable resettable monostable multivibrator
// (functional reconstruction).
//
// Contract: AMD 1974 Data Book, catalog pages 4-21 to 4-26. Each
// independent monostable triggers on a rising edge of its trigger network
// !I0# || I1 (the datasheet's OR gate with one bubbled input: I0# pin is
// active-low, I1 pin is active-high; the Table I rows are I0# falling
// with I1 low, and I1 rising with I0# high) while its direct clear is
// inactive. The active-low clear terminates a cycle asynchronously and
// inhibits triggering while held low. Q pulses HIGH; Q# is the complement.
//
// The physical pulse width is set by an external RC network
// (T = 0.32*Rx*Cx*(1 + 3.7/Rx) ns); the reconstruction counts PULSE_CYCLES
// rising edges of the abstraction reference clock clk_i instead. clk_i is
// not a device pin. An edge occurring while a clear is held low never
// fires, matching the documented reset-dominant behavior.
module am2602 #(
    parameter int unsigned PULSE_CYCLES = 4  // documented abstraction width
) (
    input  logic clk_i,         // abstraction timing reference (not a pin)
    input  logic m1_i0_n_i,     // I0# pin 5:  monostable 1 trigger (act-low)
    input  logic m1_i1_i,       // I1  pin 4:  monostable 1 trigger (act-high)
    input  logic m1_cd_n_i,     // CD# pin 3:  monostable 1 direct clear
    output logic m1_q_o,        // Q   pin 6:  monostable 1 true output
    output logic m1_q_n_o,      // Q#  pin 7:  monostable 1 complement
    input  logic m2_i0_n_i,     // I0# pin 11: monostable 2 trigger (act-low)
    input  logic m2_i1_i,       // I1  pin 12: monostable 2 trigger (act-high)
    input  logic m2_cd_n_i,     // CD# pin 13: monostable 2 direct clear
    output logic m2_q_o,        // Q   pin 10: monostable 2 true output
    output logic m2_q_n_o       // Q#  pin 9:  monostable 2 complement
);
  /* verilator lint_off PROCASSINIT */
  // The register declaration initializers implement the documented
  // power-up modeling assumption (quiescent state from elaboration; the
  // physical part has no reset pin). Yosys honors the init values.
  // ---- Monostable 1 ----
  logic m1_n_trig;
  assign m1_n_trig = !m1_i0_n_i || m1_i1_i;

  logic m1_n_trig_q = 1'b0, m1_clear_n_q = 1'b1;
  always_ff @(posedge clk_i) begin
    /* verilator lint_off SYNCASYNCNET */
    // Intentional: the asynchronous clear pin is also sampled so a trigger
    // edge is recognized only when the clear was inactive for a full
    // reference cycle (documented reset-dominant behavior).
    m1_n_trig_q   <= m1_n_trig;
    m1_clear_n_q  <= m1_cd_n_i;
    /* verilator lint_on SYNCASYNCNET */
  end
  logic m1_trig;
  assign m1_trig = m1_n_trig && !m1_n_trig_q && m1_cd_n_i && m1_clear_n_q;

  logic        m1_running = 1'b0;
  logic [31:0] m1_count   = 32'd0;
  always_ff @(posedge clk_i or negedge m1_cd_n_i) begin
    if (!m1_cd_n_i) begin
      m1_running <= 1'b0;
      m1_count   <= 32'd0;
    end else if (m1_trig) begin
      m1_running <= 1'b1;
      m1_count   <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (m1_running) begin
      if (m1_count == 32'd0) begin
        m1_running <= 1'b0;
      end else begin
        m1_count <= m1_count - 32'd1;
      end
    end
  end
  assign m1_q_o   = m1_running;
  assign m1_q_n_o = !m1_running;

  // ---- Monostable 2 ----
  logic m2_n_trig;
  assign m2_n_trig = !m2_i0_n_i || m2_i1_i;

  logic m2_n_trig_q = 1'b0, m2_clear_n_q = 1'b1;
  always_ff @(posedge clk_i) begin
    /* verilator lint_off SYNCASYNCNET */
    // Intentional: see monostable 1.
    m2_n_trig_q   <= m2_n_trig;
    m2_clear_n_q  <= m2_cd_n_i;
    /* verilator lint_on SYNCASYNCNET */
  end
  logic m2_trig;
  assign m2_trig = m2_n_trig && !m2_n_trig_q && m2_cd_n_i && m2_clear_n_q;

  logic        m2_running = 1'b0;
  logic [31:0] m2_count   = 32'd0;
  always_ff @(posedge clk_i or negedge m2_cd_n_i) begin
    if (!m2_cd_n_i) begin
      m2_running <= 1'b0;
      m2_count   <= 32'd0;
    end else if (m2_trig) begin
      m2_running <= 1'b1;
      m2_count   <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (m2_running) begin
      if (m2_count == 32'd0) begin
        m2_running <= 1'b0;
      end else begin
        m2_count <= m2_count - 32'd1;
      end
    end
  end
  assign m2_q_o   = m2_running;
  assign m2_q_n_o = !m2_running;
  /* verilator lint_on PROCASSINIT */
endmodule
