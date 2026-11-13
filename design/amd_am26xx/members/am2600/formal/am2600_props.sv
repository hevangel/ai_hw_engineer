`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2600 reconstruction.
//
// The harness derives the Table I trigger network independently and keeps a
// reference model of the documented timing behavior (pulse = PULSE_CYCLES
// reference cycles, retrigger re-arms, asynchronous clear dominates).
//
// Scoping: the mirror-equality and pulse-width properties relate the DUT
// to the model across a hidden count register, which temporal induction
// cannot close from output equality alone; they are therefore asserted in
// the bmc and cover tasks. With PULSE_CYCLES = 4 the design's full
// observable history is five reference cycles, so the 24-step bounded
// proof explores every reachable (state, input-history) combination many
// times and is exhaustive for this parameterization. The prove task checks
// the induction-stable safety properties (output complementarity and
// asynchronous clear dominance) unbounded. The functional truth table is
// exercised exhaustively by the testbench.
module am2600_props #(
    parameter int PROVE_MODE = 0
) (
    input logic clk_i,
    input logic i0_n_i,
    input logic i1_n_i,
    input logic i2_i,
    input logic i3_i,
    input logic i4_i,
    input logic co0_n_i,
    input logic co1_n_i
);
  localparam int unsigned PULSE_CYCLES = 4;

  logic q_o, q_n_o;
  am2600 #(.PULSE_CYCLES(PULSE_CYCLES)) dut (
      .clk_i(clk_i), .i0_n_i(i0_n_i), .i1_n_i(i1_n_i), .i2_i(i2_i),
      .i3_i(i3_i), .i4_i(i4_i), .co0_n_i(co0_n_i), .co1_n_i(co1_n_i),
      .q_o(q_o), .q_n_o(q_n_o));

  // Reference networks, rederived from the datasheet truth table.
  logic n_trig, clear_n;
  assign n_trig  = (!i0_n_i || !i1_n_i) && i2_i && i3_i && i4_i;
  assign clear_n = co0_n_i && co1_n_i;

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) f_past_valid <= 1'b1;

  // Reference model of the documented timing behavior.
  logic n_q = 1'b0, clr_q = 1'b1;
  always_ff @(posedge clk_i) begin
    n_q   <= n_trig;
    clr_q <= clear_n;
  end
  logic trig_ref;
  assign trig_ref = n_trig && !n_q && clear_n && clr_q;

  logic        q_ref = 1'b0;
  logic [31:0] cnt_ref = '0;
  always_ff @(posedge clk_i or negedge clear_n) begin
    if (!clear_n) begin
      q_ref   <= 1'b0;
      cnt_ref <= '0;
    end else if (trig_ref) begin
      q_ref   <= 1'b1;
      cnt_ref <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (q_ref) begin
      if (cnt_ref == '0) q_ref <= 1'b0;
      else cnt_ref <= cnt_ref - 32'd1;
    end
  end

  // Pulse-run tracking on the observed output for the width property.
  logic retrig = 1'b0, ran_high = 1'b0;
  int   high_cnt = 0;
  always_ff @(posedge clk_i or negedge clear_n) begin
    if (!clear_n) begin
      high_cnt <= 0;
      retrig   <= 1'b0;
      ran_high <= 1'b0;
    end else begin
      ran_high <= q_o;
      if (q_o) begin
        high_cnt <= high_cnt + 1;
        if (trig_ref && ran_high) retrig <= 1'b1;
      end else begin
        high_cnt <= 0;
        retrig   <= 1'b0;
      end
    end
  end

  logic q_d, clear_n_d, f_valid_d = 1'b0;
  always_ff @(posedge clk_i) begin
    q_d       <= q_o;
    clear_n_d <= clear_n;
    f_valid_d <= f_past_valid;
  end

  always_ff @(posedge clk_i) begin
    // Induction-stable safety properties: hold in every state.
    assert (q_o == !q_n_o);
    if (!clear_n) begin
      assert (!q_o);
      assert (q_n_o);
    end

    if (!PROVE_MODE) begin
      // DUT matches the independently written reference model (bounded:
      // see the module scoping note).
      assert (q_o == q_ref);

      if (f_past_valid) begin
        // A completed run (no retrigger, no clear at either boundary)
        // lasts exactly PULSE_CYCLES reference cycles.
        if (!q_o && q_d && !retrig && clear_n_d && clear_n) begin
          assert (high_cnt == int'(PULSE_CYCLES));
        end
      end
    end

    // Covers: each documented trigger path from the quiescent state (the
    // named input moves, the other four hold).
    cover ($past(f_past_valid && !q_o && !n_trig) && n_trig
           && $fell(i0_n_i) && $stable(i1_n_i) && $stable(i2_i)
           && $stable(i3_i) && $stable(i4_i));
    cover ($past(f_past_valid && !q_o && !n_trig) && n_trig
           && $fell(i1_n_i) && $stable(i0_n_i) && $stable(i2_i)
           && $stable(i3_i) && $stable(i4_i));
    cover ($past(f_past_valid && !q_o && !n_trig) && n_trig
           && $rose(i2_i) && $stable(i0_n_i) && $stable(i1_n_i)
           && $stable(i3_i) && $stable(i4_i));
    cover ($past(f_past_valid && !q_o && !n_trig) && n_trig
           && $rose(i3_i) && $stable(i0_n_i) && $stable(i1_n_i)
           && $stable(i2_i) && $stable(i4_i));
    cover ($past(f_past_valid && !q_o && !n_trig) && n_trig
           && $rose(i4_i) && $stable(i0_n_i) && $stable(i1_n_i)
           && $stable(i2_i) && $stable(i3_i));
    // Retrigger during a running cycle extends it.
    cover (q_o && trig_ref);
    // Asynchronous clear terminates a running cycle (Q falls although the
    // pulse had not expired).
    cover (f_past_valid && q_d && !q_o && !clear_n);
    // Individual clear pins.
    cover (f_past_valid && q_d && !q_o && !co0_n_i);
    cover (f_past_valid && q_d && !q_o && !co1_n_i);
    // Inhibit: trigger network held high under a clear, no pulse.
    cover (n_trig && !clear_n && !q_o);
    // Completed full-width pulse.
    cover (f_valid_d && !q_o && q_d && !retrig && clear_n_d);
  end
endmodule
`endif
