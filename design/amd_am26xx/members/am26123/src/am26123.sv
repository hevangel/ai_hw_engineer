`timescale 1ns/1ps
// Am26123 dual retriggerable resettable monostable multivibrator
// (functional reconstruction; Am54/74123-compatible trigger arrangement).
//
// Contract: AMD 1974 Data Book, catalog pages 4-87 to 4-92. Each
// independent monostable triggers on a rising edge of its trigger
// network !A && B (A pin active low, B pin active high, "logically
// coupled in an AND gate on the trigger input"; the published rows are A
// falling with B high and B rising with A low) while its active-low
// clear is inactive. The clear "resets the monostable to the normal Q
// LOW quiescent state regardless of the A and B inputs", and a trigger
// edge occurring while the clear is held low never fires afterward. Q
// pulses HIGH; Q# is the complement.
//
// The physical pulse width is set by an external RC network on the
// CEXT/REXT pins; the reconstruction counts PULSE_CYCLES rising edges of
// the abstraction reference clock clk_i instead. clk_i is not a device
// pin. The Am26123's output latch (noise immunity at the RC timing
// nodes) is an electrical property with no digital consequence.
module am26123 #(
    parameter int unsigned PULSE_CYCLES = 4  // documented abstraction width
) (
    input  logic clk_i,         // abstraction timing reference (not a pin)
    input  logic m1_a_n_i,      // 1A    pin 1:  monostable 1 trigger (act-low)
    input  logic m1_b_i,        // 1B    pin 2:  monostable 1 trigger (act-high)
    input  logic m1_clr_n_i,    // 1CLR  pin 3:  monostable 1 direct clear
    output logic m1_q_o,        // 1Q    pin 5:  monostable 1 true output
    output logic m1_q_n_o,      // 1Q#   pin 4:  monostable 1 complement
    input  logic m2_a_n_i,      // 2A    pin 9:  monostable 2 trigger (act-low)
    input  logic m2_b_i,        // 2B    pin 10: monostable 2 trigger (act-high)
    input  logic m2_clr_n_i,    // 2CLR  pin 11: monostable 2 direct clear
    output logic m2_q_o,        // 2Q    pin 13: monostable 2 true output
    output logic m2_q_n_o       // 2Q#   pin 12: monostable 2 complement
);
  /* verilator lint_off PROCASSINIT */
  // The register declaration initializers implement the documented
  // power-up modeling assumption (quiescent state from elaboration; the
  // physical part has no reset pin). Yosys honors the init values.
  // ---- Monostable 1 ----
  logic m1_n_trig;
  assign m1_n_trig = !m1_a_n_i && m1_b_i;

  logic m1_n_trig_q = 1'b0, m1_clear_n_q = 1'b1;
  always_ff @(posedge clk_i) begin
    /* verilator lint_off SYNCASYNCNET */
    // Intentional: the asynchronous clear pin is also sampled so a trigger
    // edge is recognized only when the clear was inactive for a full
    // reference cycle (documented reset-dominant behavior).
    m1_n_trig_q   <= m1_n_trig;
    m1_clear_n_q  <= m1_clr_n_i;
    /* verilator lint_on SYNCASYNCNET */
  end
  logic m1_trig;
  assign m1_trig = m1_n_trig && !m1_n_trig_q && m1_clr_n_i && m1_clear_n_q;

  logic        m1_running = 1'b0;
  logic [31:0] m1_count   = 32'd0;
  always_ff @(posedge clk_i or negedge m1_clr_n_i) begin
    if (!m1_clr_n_i) begin
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
  assign m2_n_trig = !m2_a_n_i && m2_b_i;

  logic m2_n_trig_q = 1'b0, m2_clear_n_q = 1'b1;
  always_ff @(posedge clk_i) begin
    /* verilator lint_off SYNCASYNCNET */
    // Intentional: see monostable 1.
    m2_n_trig_q   <= m2_n_trig;
    m2_clear_n_q  <= m2_clr_n_i;
    /* verilator lint_on SYNCASYNCNET */
  end
  logic m2_trig;
  assign m2_trig = m2_n_trig && !m2_n_trig_q && m2_clr_n_i && m2_clear_n_q;

  logic        m2_running = 1'b0;
  logic [31:0] m2_count   = 32'd0;
  always_ff @(posedge clk_i or negedge m2_clr_n_i) begin
    if (!m2_clr_n_i) begin
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
