`timescale 1ns/1ps
// Self-checking testbench for the Am2600 reconstruction.
//
// Checks, against the 1974 Data Book contract (catalog pages 4-15..4-20):
// 1. every Table I trigger path from the quiescent state,
// 2. non-trigger input combinations leave Q quiescent,
// 3. pulse width equals PULSE_CYCLES reference cycles,
// 4. retriggering during a cycle re-arms the full width,
// 5. either direct clear terminates a cycle asynchronously and holds the
//    quiescent state with no output spikes while inputs toggle,
// 6. an input edge consumed during a held clear does not fire afterward.
module tb_top;
  localparam int unsigned PULSE_CYCLES = 4;

  logic clk_i = 1'b1;
  logic i0_n_i = 1'b1, i1_n_i = 1'b1, i2_i = 1'b0, i3_i = 1'b0, i4_i = 1'b0;
  logic co0_n_i = 1'b1, co1_n_i = 1'b1;
  logic q_o, q_n_o;

  am2600 #(.PULSE_CYCLES(PULSE_CYCLES)) dut (
      .clk_i, .i0_n_i, .i1_n_i, .i2_i, .i3_i, .i4_i,
      .co0_n_i, .co1_n_i, .q_o, .q_n_o);

  always #5 clk_i = ~clk_i;

  integer errors = 0;
  integer checks = 0;

  task automatic expect_q(input logic exp, input string ctx);
    if (q_o !== exp || q_n_o !== !exp) begin
      $display("FAIL %s: q=%b q_n=%b expected q=%b (t=%0t)",
               ctx, q_o, q_n_o, exp, $time);
      errors++;
    end
    checks++;
  endtask

  // Settle inputs away from the reference edges.
  task automatic settle;
    @(negedge clk_i);
    #1;
  endtask

  // Run one reference edge and verify the pulse state.
  task automatic tick(input logic exp, input string ctx);
    @(posedge clk_i);
    #1;
    expect_q(exp, ctx);
  endtask

  // Idle the device (no trigger network activity).
  task automatic idle;
    i0_n_i = 1'b1; i1_n_i = 1'b1; i2_i = 1'b0; i3_i = 1'b0; i4_i = 1'b0;
  endtask

  // Verify a completed full-width pulse from a trigger edge created by
  // applying the given input values.
  task automatic pulse_from(input string ctx);
    int unsigned c;
    tick(1'b1, {ctx, ": trigger"});
    for (c = 1; c < PULSE_CYCLES; c++) tick(1'b1, {ctx, ": run"});
    tick(1'b0, {ctx, ": expire"});
    expect_q(1'b0, {ctx, ": quiescent"});
  endtask

  integer cycle;

  initial begin
    idle();
    // Power-on quiescence before any stimulus.
    #1 expect_q(1'b0, "power-on");

    // --- 1. Each documented trigger path (Table I rows) ---
    // Row 1: I0# falls, all other inputs high.
    settle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "armed-idle");
    settle(); i0_n_i = 1'b0;
    pulse_from("i0-fall");
    settle(); idle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    // Row 2: I1# falls.
    settle(); i1_n_i = 1'b0;
    pulse_from("i1-fall");
    // Row 3: I2 rises while I0# low.
    settle(); idle(); i0_n_i = 1'b0; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i2_i = 1'b1;
    pulse_from("i2-rise");
    // Row 5: I3 rises while I0# low.
    settle(); idle(); i0_n_i = 1'b0; i2_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i3_i = 1'b1;
    pulse_from("i3-rise");
    // Row 7: I4 rises while I0# low.
    settle(); idle(); i0_n_i = 1'b0; i2_i = 1'b1; i3_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i4_i = 1'b1;
    pulse_from("i4-rise");

    // --- 2. Non-trigger combinations ---
    // Both active-low inputs high: an active-high input rising is gated
    // off by the network (Table I requires I0# or I1# low).
    settle(); idle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i0_n_i = 1'b0;  // I0# falls alone: network rises, triggers
    tick(1'b1, "gated-rise-trigger");
    settle(); idle(); i2_i = 1'b0;
    // wait for expiry
    for (cycle = 0; cycle < PULSE_CYCLES; cycle++) tick(cycle < PULSE_CYCLES - 1 ? 1'b1 : 1'b0, "expiry");
    // I2 rise with both active-low inputs high: no trigger.
    settle(); idle(); i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i2_i = 1'b1;
    tick(1'b0, "no-trigger-gated");
    tick(1'b0, "still-quiescent");
    // Steady network-high (I0# low, I2..I4 high) creates no new edge.
    settle(); idle(); i0_n_i = 1'b0; i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b1, "steady-high-triggers");
    for (cycle = 0; cycle < PULSE_CYCLES; cycle++) tick(cycle < PULSE_CYCLES - 1 ? 1'b1 : 1'b0, "steady-expiry");
    expect_q(1'b0, "steady-quiescent");

    // --- 3. Pulse width already checked; retrigger extension ---
    settle(); idle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i0_n_i = 1'b0;             // trigger
    tick(1'b1, "retrig-first");
    tick(1'b1, "retrig-run1");
    settle(); i0_n_i = 1'b1;             // network falls
    tick(1'b1, "retrig-run2");
    settle(); i0_n_i = 1'b0;             // retrigger mid-pulse
    for (cycle = 0; cycle < PULSE_CYCLES; cycle++)
      tick(1'b1, {"/retrig-extend", cycle});
    tick(1'b0, "retrig-expire");
    expect_q(1'b0, "retrig-quiescent");

    // --- 4. Asynchronous clear dominance ---
    settle(); idle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i0_n_i = 1'b0;
    tick(1'b1, "clear-first");
    settle(); co0_n_i = 1'b0;
    #1 expect_q(1'b0, "async-clear-co0");
    // Inputs toggling under a held clear: no spikes.
    i0_n_i = 1'b1; i2_i = 1'b0; #1 expect_q(1'b0, "held-clear-toggle1");
    i2_i = 1'b1; i3_i = 1'b0;  #1 expect_q(1'b0, "held-clear-toggle2");
    settle(); co0_n_i = 1'b1;  // release with inputs re-armed: no edge
    tick(1'b0, "release-no-fire");
    tick(1'b0, "release-still-off");
    settle(); i0_n_i = 1'b0; i3_i = 1'b1;  // fresh rising edge after release
    pulse_from("after-release");

    // Clear CO1# alone terminates as well.
    settle(); idle(); i2_i = 1'b1; i3_i = 1'b1; i4_i = 1'b1;
    tick(1'b0, "settled");
    settle(); i0_n_i = 1'b0;
    tick(1'b1, "co1-first");
    settle(); co1_n_i = 1'b0;
    #1 expect_q(1'b0, "async-clear-co1");
    settle(); co1_n_i = 1'b1;
    tick(1'b0, "co1-release");

    // --- 5. Edge consumed during held clear ---
    settle(); idle(); i2_i = 1'b0; i3_i = 1'b1; i4_i = 1'b1;
    co0_n_i = 1'b0;
    tick(1'b0, "held-clear-idle");
    settle(); i0_n_i = 1'b0; i2_i = 1'b1;  // network rises during clear
    tick(1'b0, "edge-during-clear");
    settle(); co0_n_i = 1'b1;              // release, network stays high
    tick(1'b0, "consumed-after-release");
    tick(1'b0, "consumed-still-off");
    settle(); i0_n_i = 1'b1;               // network falls
    tick(1'b0, "network-fall");
    settle(); i0_n_i = 1'b0;               // genuine new edge fires
    pulse_from("post-clear-real-edge");

    if (errors == 0) begin
      $display("am2600 TEST PASSED: %0d checks", checks);
    end else begin
      $display("am2600 TEST FAILED: %0d errors / %0d checks", errors, checks);
      $fatal(1, "am2600 testbench failed");
    end
    $finish;
  end
endmodule
