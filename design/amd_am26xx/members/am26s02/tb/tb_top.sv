`timescale 1ns/1ps
// Self-checking testbench for the Am26S02 reconstruction.
//
// The S02's function table is identical across the 1974 preliminary and
// 1978 final printings, so the stimulus plan is the Am2602/L02 family
// plan: both trigger paths per channel, non-trigger combinations, pulse
// width, retrigger extension, asynchronous clear dominance with spike
// suppression, consumed edges, and channel independence.
module tb_top;
  localparam int unsigned PULSE_CYCLES = 4;

  logic clk_i = 1'b1;
  logic m1_i0_n_i = 1'b1, m1_i1_i = 1'b0, m1_cd_n_i = 1'b1;
  logic m2_i0_n_i = 1'b1, m2_i1_i = 1'b0, m2_cd_n_i = 1'b1;
  logic m1_q_o, m1_q_n_o, m2_q_o, m2_q_n_o;

  am26s02 #(.PULSE_CYCLES(PULSE_CYCLES)) dut (
      .clk_i,
      .m1_i0_n_i, .m1_i1_i, .m1_cd_n_i, .m1_q_o, .m1_q_n_o,
      .m2_i0_n_i, .m2_i1_i, .m2_cd_n_i, .m2_q_o, .m2_q_n_o);

  always #5 clk_i = ~clk_i;

  integer errors = 0;
  integer checks = 0;

  task automatic expect1(input logic exp, input string ctx);
    if (m1_q_o !== exp || m1_q_n_o !== !exp) begin
      $display("FAIL m1 %s: q=%b q_n=%b expected q=%b (t=%0t)",
               ctx, m1_q_o, m1_q_n_o, exp, $time);
      errors++;
    end
    checks++;
  endtask

  task automatic expect2(input logic exp, input string ctx);
    if (m2_q_o !== exp || m2_q_n_o !== !exp) begin
      $display("FAIL m2 %s: q=%b q_n=%b expected q=%b (t=%0t)",
               ctx, m2_q_o, m2_q_n_o, exp, $time);
      errors++;
    end
    checks++;
  endtask

  task automatic settle;
    @(negedge clk_i);
    #1;
  endtask

  task automatic tick1(input logic exp, input string ctx);
    @(posedge clk_i);
    #1;
    expect1(exp, ctx);
  endtask

  task automatic tick2(input logic exp, input string ctx);
    @(posedge clk_i);
    #1;
    expect2(exp, ctx);
  endtask

  task automatic tick_both(input logic e1, input logic e2,
                           input string ctx);
    @(posedge clk_i);
    #1;
    expect1(e1, ctx);
    expect2(e2, ctx);
  endtask

  task automatic pulse1(input string ctx);
    tick1(1'b1, {ctx, ": trig"});
    repeat (PULSE_CYCLES - 1) tick1(1'b1, {ctx, ": run"});
    tick1(1'b0, {ctx, ": expire"});
    expect1(1'b0, {ctx, ": idle"});
  endtask

  task automatic pulse2(input string ctx);
    tick2(1'b1, {ctx, ": trig"});
    repeat (PULSE_CYCLES - 1) tick2(1'b1, {ctx, ": run"});
    tick2(1'b0, {ctx, ": expire"});
    expect2(1'b0, {ctx, ": idle"});
  endtask

  initial begin
    #1 expect1(1'b0, "power-on");
    expect2(1'b0, "power-on");

    // Channel 1: both function-table rows.
    settle(); tick1(1'b0, "idle1");
    settle(); m1_i0_n_i = 1'b0;             // I0# falls, I1 low
    pulse1("m1-i0-fall");
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b0, "m1-fell");
    settle(); m1_i1_i = 1'b1;               // I1 rises, I0# high
    pulse1("m1-i1-rise");

    // Non-trigger combinations.
    settle(); m1_i0_n_i = 1'b0;             // network held high
    tick1(1'b0, "no-edge-high-held");
    tick1(1'b0, "still-quiescent");
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b0, "still-high-held");
    settle(); m1_i1_i = 1'b0;
    tick1(1'b0, "fell-after-high");
    // Toggles under a held-high network: no new edge mid-run.
    settle(); m1_i0_n_i = 1'b0;
    tick1(1'b1, "rearm-trig");
    settle(); m1_i1_i = 1'b1;
    tick1(1'b1, "held-high-run");
    settle(); m1_i1_i = 1'b0;
    repeat (PULSE_CYCLES - 2) tick1(1'b1, "expire-run");
    tick1(1'b0, "expire");
    expect1(1'b0, "expired-idle");

    // Retrigger extension.
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b0, "fell-prep");
    settle(); m1_i0_n_i = 1'b0;
    tick1(1'b1, "retrig-first");
    tick1(1'b1, "retrig-run1");
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b1, "retrig-run2");
    settle(); m1_i0_n_i = 1'b0;
    repeat (PULSE_CYCLES) tick1(1'b1, "retrig-extend");
    tick1(1'b0, "retrig-expire");
    expect1(1'b0, "retrig-idle");

    // Asynchronous clear dominance.
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b0, "fell-prep2");
    settle(); m1_i1_i = 1'b1;
    tick1(1'b1, "clear-run");
    settle(); m1_cd_n_i = 1'b0;
    #1 expect1(1'b0, "async-clear");
    m1_i0_n_i = 1'b0; #1 expect1(1'b0, "held-toggle1");
    m1_i1_i = 1'b0;   #1 expect1(1'b0, "held-toggle2");
    settle(); m1_cd_n_i = 1'b1;
    tick1(1'b0, "release-no-fire");
    tick1(1'b0, "release-still-off");
    settle(); m1_i0_n_i = 1'b1;
    tick1(1'b0, "post-clear-fall");
    settle(); m1_i0_n_i = 1'b0;
    pulse1("after-release");

    // Channel 2: both function-table rows.
    settle(); tick2(1'b0, "idle2");
    settle(); m2_i0_n_i = 1'b0;
    pulse2("m2-i0-fall");
    settle(); m2_i0_n_i = 1'b1;
    tick2(1'b0, "m2-fell");
    settle(); m2_i1_i = 1'b1;
    pulse2("m2-i1-rise");
    settle(); m2_i1_i = 1'b0;
    tick2(1'b0, "m2-fell");

    // Channel independence.
    settle(); m1_i0_n_i = 1'b1; m1_i1_i = 1'b0;
    tick_both(1'b0, 1'b0, "m1-idle-prep");
    settle(); m1_i1_i = 1'b1; m2_i1_i = 1'b1;
    tick_both(1'b1, 1'b1, "both-trig");
    settle(); m2_cd_n_i = 1'b0;
    #1 expect2(1'b0, "m2-cleared");
    expect1(1'b1, "m1-still-running");
    repeat (PULSE_CYCLES - 1) tick_both(1'b1, 1'b0, "independent-run");
    tick_both(1'b0, 1'b0, "m1-expire-m2-held");
    settle(); m2_cd_n_i = 1'b1;
    tick2(1'b0, "m2-released");
    expect1(1'b0, "both-idle");

    if (errors == 0) begin
      $display("am26s02 TEST PASSED: %0d checks", checks);
    end else begin
      $display("am26s02 TEST FAILED: %0d errors / %0d checks", errors, checks);
      $fatal(1, "am26s02 testbench failed");
    end
    $finish;
  end
endmodule
