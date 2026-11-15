`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2602 reconstruction.
//
// Each independent monostable is checked against an independently written
// reference model (Table I trigger network !I0# || I1, two-cycle edge
// history, PULSE_CYCLES down-counter, asynchronous clear dominance), plus
// the induction-stable safety properties. See the am2600 formal plan for
// the scoping rationale (bmc/cover carry the bounded behavioral
// equivalence, exhaustive for the five-cycle observable history at
// PULSE_CYCLES = 4; prove carries the unbounded safety properties).
module am2602_props #(
    parameter int PROVE_MODE = 0
) (
    input logic clk_i,
    input logic m1_i0_n_i, m1_i1_i, m1_cd_n_i,
    input logic m2_i0_n_i, m2_i1_i, m2_cd_n_i
);
  localparam int unsigned PULSE_CYCLES = 4;

  logic m1_q_o, m1_q_n_o, m2_q_o, m2_q_n_o;
  am2602 #(.PULSE_CYCLES(PULSE_CYCLES)) dut (
      .clk_i(clk_i),
      .m1_i0_n_i(m1_i0_n_i), .m1_i1_i(m1_i1_i), .m1_cd_n_i(m1_cd_n_i),
      .m1_q_o(m1_q_o), .m1_q_n_o(m1_q_n_o),
      .m2_i0_n_i(m2_i0_n_i), .m2_i1_i(m2_i1_i), .m2_cd_n_i(m2_cd_n_i),
      .m2_q_o(m2_q_o), .m2_q_n_o(m2_q_n_o));

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) f_past_valid <= 1'b1;

  // ---- Reference model, one instance per channel ----
  logic m1_n_trig, m2_n_trig;
  assign m1_n_trig = !m1_i0_n_i || m1_i1_i;
  assign m2_n_trig = !m2_i0_n_i || m2_i1_i;

  logic m1_n_q = 1'b0, m1_clr_q = 1'b1, m2_n_q = 1'b0, m2_clr_q = 1'b1;
  always_ff @(posedge clk_i) begin
    m1_n_q <= m1_n_trig;   m1_clr_q <= m1_cd_n_i;
    m2_n_q <= m2_n_trig;   m2_clr_q <= m2_cd_n_i;
  end
  logic m1_trig_ref, m2_trig_ref;
  assign m1_trig_ref = m1_n_trig && !m1_n_q && m1_cd_n_i && m1_clr_q;
  assign m2_trig_ref = m2_n_trig && !m2_n_q && m2_cd_n_i && m2_clr_q;

  logic        m1_q_ref = 1'b0, m2_q_ref = 1'b0;
  logic [31:0] m1_cnt = '0,      m2_cnt = '0;
  always_ff @(posedge clk_i or negedge m1_cd_n_i) begin
    if (!m1_cd_n_i) begin
      m1_q_ref <= 1'b0;  m1_cnt <= '0;
    end else if (m1_trig_ref) begin
      m1_q_ref <= 1'b1;  m1_cnt <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (m1_q_ref) begin
      if (m1_cnt == '0) m1_q_ref <= 1'b0;
      else m1_cnt <= m1_cnt - 32'd1;
    end
  end
  always_ff @(posedge clk_i or negedge m2_cd_n_i) begin
    if (!m2_cd_n_i) begin
      m2_q_ref <= 1'b0;  m2_cnt <= '0;
    end else if (m2_trig_ref) begin
      m2_q_ref <= 1'b1;  m2_cnt <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (m2_q_ref) begin
      if (m2_cnt == '0) m2_q_ref <= 1'b0;
      else m2_cnt <= m2_cnt - 32'd1;
    end
  end

  // Pulse-run tracking for the width property.
  logic m1_retrig = 1'b0, m1_ran = 1'b0, m2_retrig = 1'b0, m2_ran = 1'b0;
  int   m1_high = 0, m2_high = 0;
  always_ff @(posedge clk_i or negedge m1_cd_n_i) begin
    if (!m1_cd_n_i) begin
      m1_high <= 0;  m1_retrig <= 1'b0;  m1_ran <= 1'b0;
    end else begin
      m1_ran <= m1_q_o;
      if (m1_q_o) begin
        m1_high <= m1_high + 1;
        if (m1_trig_ref && m1_ran) m1_retrig <= 1'b1;
      end else begin
        m1_high <= 0;  m1_retrig <= 1'b0;
      end
    end
  end
  always_ff @(posedge clk_i or negedge m2_cd_n_i) begin
    if (!m2_cd_n_i) begin
      m2_high <= 0;  m2_retrig <= 1'b0;  m2_ran <= 1'b0;
    end else begin
      m2_ran <= m2_q_o;
      if (m2_q_o) begin
        m2_high <= m2_high + 1;
        if (m2_trig_ref && m2_ran) m2_retrig <= 1'b1;
      end else begin
        m2_high <= 0;  m2_retrig <= 1'b0;
      end
    end
  end

  logic m1_q_d, m2_q_d, clear1_d, clear2_d, f_valid_d = 1'b0;
  always_ff @(posedge clk_i) begin
    m1_q_d <= m1_q_o;      m2_q_d <= m2_q_o;
    clear1_d <= m1_cd_n_i; clear2_d <= m2_cd_n_i;
    f_valid_d <= f_past_valid;
  end

  always_ff @(posedge clk_i) begin
    // Induction-stable safety properties, per channel.
    assert (m1_q_o == !m1_q_n_o);
    assert (m2_q_o == !m2_q_n_o);
    if (!m1_cd_n_i) begin
      assert (!m1_q_o);
      assert (m1_q_n_o);
    end
    if (!m2_cd_n_i) begin
      assert (!m2_q_o);
      assert (m2_q_n_o);
    end

    if (!PROVE_MODE) begin
      // Reference-model equality (bounded: see the module scoping note).
      assert (m1_q_o == m1_q_ref);
      assert (m2_q_o == m2_q_ref);

      if (f_past_valid) begin
        if (!m1_q_o && m1_q_d && !m1_retrig && clear1_d && m1_cd_n_i) begin
          assert (m1_high == int'(PULSE_CYCLES));
        end
        if (!m2_q_o && m2_q_d && !m2_retrig && clear2_d && m2_cd_n_i) begin
          assert (m2_high == int'(PULSE_CYCLES));
        end
      end
    end

    // Covers: each documented trigger path per channel.
    cover ($past(f_past_valid && !m1_q_o && !m1_n_trig) && m1_n_trig
           && $fell(m1_i0_n_i) && $stable(m1_i1_i));
    cover ($past(f_past_valid && !m1_q_o && !m1_n_trig) && m1_n_trig
           && $rose(m1_i1_i) && $stable(m1_i0_n_i));
    cover ($past(f_past_valid && !m2_q_o && !m2_n_trig) && m2_n_trig
           && $fell(m2_i0_n_i) && $stable(m2_i1_i));
    cover ($past(f_past_valid && !m2_q_o && !m2_n_trig) && m2_n_trig
           && $rose(m2_i1_i) && $stable(m2_i0_n_i));
    // Retrigger during a running cycle extends it.
    cover (m1_q_o && m1_trig_ref);
    cover (m2_q_o && m2_trig_ref);
    // Asynchronous clear terminates a running cycle.
    cover (f_past_valid && m1_q_d && !m1_q_o && !m1_cd_n_i);
    cover (f_past_valid && m2_q_d && !m2_q_o && !m2_cd_n_i);
    // Inhibit: trigger network held high under a clear, no pulse.
    cover (m1_n_trig && !m1_cd_n_i && !m1_q_o);
    cover (m2_n_trig && !m2_cd_n_i && !m2_q_o);
    // Completed full-width pulses on both channels.
    cover (f_valid_d && !m1_q_o && m1_q_d && !m1_retrig && clear1_d);
    cover (f_valid_d && !m2_q_o && m2_q_d && !m2_retrig && clear2_d);
    // Channel independence: monostable 1 running while monostable 2
    // completes a full pulse.
    cover (m1_q_o && f_valid_d && !m2_q_o && m2_q_d && !m2_retrig
           && clear2_d);
  end
endmodule
`endif
