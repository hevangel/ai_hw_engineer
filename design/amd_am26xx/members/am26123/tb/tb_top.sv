`timescale 1ns/1ps
// Self-checking testbench for the Am26123 reconstruction.
//
// Checks, against the 1974 Data Book contract (catalog pages 4-87..4-92):
// 1. every truth-table trigger path per channel from the quiescent state
//    (A falling with B high; B rising with A low),
// 2. the truth table's non-trigger rows (A high steady; B low steady),
// 3. pulse width equals PULSE_CYCLES reference cycles per channel,
// 4. retriggering during a cycle re-arms the full width,
// 5. the asynchronous clear resets to the Q-LOW quiescent state
//    immediately and suppresses spikes while inputs toggle,
// 6. an input edge consumed during a held clear does not fire afterward,
// 7. the two monostables operate independently.
module tb_top;
  localparam int unsigned PULSE_CYCLES = 4;

  logic clk_i = 1'b1;
  logic m1_a_n_i = 1'b1, m1_b_i = 1'b0, m1_clr_n_i = 1'b1;
  logic m2_a_n_i = 1'b1, m2_b_i = 1'b0, m2_clr_n_i = 1'b1;
  logic m1_q_o, m1_q_n_o, m2_q_o, m2_q_n_o;

  am26123 #(.PULSE_CYCLES(PULSE_CYCLES)) dut (
      .clk_i,
      .m1_a_n_i, .m1_b_i, .m1_clr_n_i, .m1_q_o, .m1_q_n_o,
      .m2_a_n_i, .m2_b_i, .m2_clr_n_i, .m2_q_o, .m2_q_n_o);

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

    // Channel 1: truth-table rows.
    settle(); tick1(1'b0, "idle1");
    settle(); m1_a_n_i = 1'b0;             // A falls while B low: no edge
    tick1(1'b0, "a-fall-b-low");
    tick1(1'b0, "still-idle");
    settle(); m1_b_i = 1'b1;               // B rises while A low: row 3
    pulse1("m1-b-rise");
    settle(); m1_b_i = 1'b0;               // network falls
    tick1(1'b0, "m1-fell");
    settle(); m1_b_i = 1'b1;               // re-arm (A low, B high steady)
    tick1(1'b1, "steady-high-triggers");
    repeat (PULSE_CYCLES - 1) tick1(1'b1, "steady-run");
    tick1(1'b0, "steady-expire");
    expect1(1'b0, "steady-idle");
    settle(); m1_a_n_i = 1'b1;             // A high: network forced low
    tick1(1'b0, "a-high-idle");
    settle(); m1_a_n_i = 1'b0;             // A falls with B high: row 5
    pulse1("m1-a-fall");

    // Non-trigger: B falls (network 0) then A falls (no edge, already 0).
    settle(); m1_b_i = 1'b0;
    tick1(1'b0, "b-fell");
    settle(); m1_a_n_i = 1'b1;
    tick1(1'b0, "a-high-noedge");
    settle(); m1_a_n_i = 1'b0;             // A falls, B low: no edge
    tick1(1'b0, "a-fall-b-low-noedge");
    tick1(1'b0, "still-quiescent");

    // Retrigger extension.
    settle(); m1_b_i = 1'b1;               // trigger
    tick1(1'b1, "retrig-first");
    tick1(1'b1, "retrig-run1");
    settle(); m1_b_i = 1'b0;               // network falls
    tick1(1'b1, "retrig-run2");
    settle(); m1_b_i = 1'b1;               // retrigger mid-pulse
    repeat (PULSE_CYCLES) tick1(1'b1, "retrig-extend");
    tick1(1'b0, "retrig-expire");
    expect1(1'b0, "retrig-idle");

    // Asynchronous clear dominance.
    settle(); m1_clr_n_i = 1'b0;
    tick1(1'b0, "held-clear-idle");
    settle(); m1_b_i = 1'b0;               // network falls under clear
    tick1(1'b0, "held-clear-fell");
    settle(); m1_clr_n_i = 1'b1;           // release, no edge
    tick1(1'b0, "release-no-fire");
    settle(); m1_b_i = 1'b1;               // fresh edge fires
    pulse1("after-release");
    settle(); m1_a_n_i = 1'b1;             // idle the network
    tick1(1'b0, "network-idled");
    settle(); m1_b_i = 1'b0;               // re-arm A low, B low
    tick1(1'b0, "rearm-idle");
    settle(); m1_a_n_i = 1'b0;             // A low re-arms for B's rise
    tick1(1'b0, "armed-idle");
    settle(); m1_b_i = 1'b1;               // B rises with A low: trigger
    tick1(1'b1, "clr-run");
    settle(); m1_clr_n_i = 1'b0;
    #1 expect1(1'b0, "async-clear");
    m1_b_i = 1'b0;    #1 expect1(1'b0, "held-toggle1");
    m1_a_n_i = 1'b1;  #1 expect1(1'b0, "held-toggle2");
    settle(); m1_clr_n_i = 1'b1;
    tick1(1'b0, "release-still-off");
    tick1(1'b0, "release-quiescent");

    // Channel 2: both trigger rows.
    settle(); tick2(1'b0, "idle2");
    settle(); m2_a_n_i = 1'b0;
    tick2(1'b0, "m2-a-fall-b-low");
    settle(); m2_b_i = 1'b1;
    pulse2("m2-b-rise");
    settle(); m2_b_i = 1'b0;
    tick2(1'b0, "m2-fell");
    settle(); m2_b_i = 1'b1;
    tick2(1'b1, "m2-steady-triggers");
    repeat (PULSE_CYCLES - 1) tick2(1'b1, "m2-steady-run");
    tick2(1'b0, "m2-steady-expire");

    // Channel independence.
    settle(); m2_a_n_i = 1'b1;             // idle channel 2 network
    tick_both(1'b0, 1'b0, "prep");
    settle(); m1_a_n_i = 1'b0; m2_a_n_i = 1'b0; m2_b_i = 1'b0;   // re-arm
    tick_both(1'b0, 1'b0, "both-idle");
    settle(); m1_b_i = 1'b1; m2_b_i = 1'b1;   // both networks rise
    tick_both(1'b1, 1'b1, "both-trig");
    settle(); m2_clr_n_i = 1'b0;
    #1 expect2(1'b0, "m2-cleared");
    expect1(1'b1, "m1-still-running");
    repeat (PULSE_CYCLES - 1) tick_both(1'b1, 1'b0, "independent-run");
    tick_both(1'b0, 1'b0, "m1-expire-m2-held");
    settle(); m2_clr_n_i = 1'b1;
    tick2(1'b0, "m2-released");
    expect1(1'b0, "both-idle");

    if (errors == 0) begin
      $display("am26123 TEST PASSED: %0d checks", checks);
    end else begin
      $display("am26123 TEST FAILED: %0d errors / %0d checks", errors, checks);
      $fatal(1, "am26123 testbench failed");
    end
    $finish;
  end
endmodule
