`timescale 1ns/1ps
// Self-checking testbench for the Intel 3404 latch reconstruction.
//
// Directed checks: reset landing, per-section transparent write, hold
// against changing data, section independence, simultaneous writes.
// Random phase: 5000 cycles of unconstrained data/write-enable stimulus
// against a cycle-accurate shadow model.
module tb_top;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [5:0] d_i = 6'h00;
  logic w4_n_i = 1'b1;
  logic w2_n_i = 1'b1;
  logic [5:0] q_n_o;

  intel_3404 dut (.clk(clk), .rst_n(rst_n), .d_i(d_i), .w4_n_i(w4_n_i), .w2_n_i(w2_n_i), .q_n_o(q_n_o));

  always #5 clk = ~clk;

  logic [5:0] model_q = 6'h3F;
  integer errors = 0;
  integer checks = 0;
  logic [31:0] rng = 32'h34041973;

  function automatic logic [31:0] next_random(input logic [31:0] value);
    return value * 32'd1664525 + 32'd1013904223;
  endfunction

  always @(posedge clk) begin
    if (!rst_n) begin
      model_q <= 6'h3F;
    end else begin
      if (!w4_n_i) model_q[3:0] <= ~d_i[3:0];
      if (!w2_n_i) model_q[5:4] <= ~d_i[5:4];
    end
  end

  task automatic tick;
    @(posedge clk);
    #1;
    checks++;
    if (q_n_o !== model_q) begin
      $display("FAIL: d=%b w4=%b w2=%b q=%b model=%b", d_i, w4_n_i, w2_n_i, q_n_o, model_q);
      errors++;
    end
  endtask

  // Write value into the 4-bit section while holding the 2-bit section.
  task automatic write4(input logic [3:0] v);
    d_i = {2'b00, v};
    w4_n_i = 1'b0;
    w2_n_i = 1'b1;
    tick();
    if (q_n_o[3:0] !== ~v) begin
      $display("FAIL write4: v=%b q4=%b", v, q_n_o[3:0]);
      errors++;
    end
    w4_n_i = 1'b1;
  endtask

  // Write value into the 2-bit section while holding the 4-bit section.
  task automatic write2(input logic [1:0] v);
    d_i = {v, 4'b0000};
    w4_n_i = 1'b1;
    w2_n_i = 1'b0;
    tick();
    if (q_n_o[5:4] !== ~v) begin
      $display("FAIL write2: v=%b q2=%b", v, q_n_o[5:4]);
      errors++;
    end
    w2_n_i = 1'b1;
  endtask

  // With the section held, change its data inputs and verify the stored
  // value does not move.
  task automatic hold_check4(input logic [3:0] disturb);
    logic [3:0] prev;
    prev = q_n_o[3:0];
    d_i = {2'b00, disturb};
    tick();
    if (q_n_o[3:0] !== prev) begin
      $display("FAIL hold4: stored=%b now=%b", prev, q_n_o[3:0]);
      errors++;
    end
  endtask

  task automatic hold_check2(input logic [1:0] disturb);
    logic [1:0] prev;
    prev = q_n_o[5:4];
    d_i = {disturb, 4'b0000};
    tick();
    if (q_n_o[5:4] !== prev) begin
      $display("FAIL hold2: stored=%b now=%b", prev, q_n_o[5:4]);
      errors++;
    end
  endtask

  integer rounds;

  initial begin
    // Reset lands: outputs go high.
    tick();
    if (q_n_o !== 6'h3F) begin
      $display("FAIL reset: q=%b", q_n_o);
      errors++;
    end
    rst_n = 1;

    // Per-section transparent write and hold-against-disturbance, both
    // corners of each section's width.
    write4(4'h5);
    hold_check4(4'hA);
    write4(4'h0);
    hold_check4(4'hF);
    write2(2'b01);
    hold_check2(2'b10);
    write2(2'b11);
    hold_check2(2'b00);

    // Simultaneous writes with independent values.
    d_i = 6'b10_1001;
    w4_n_i = 1'b0;
    w2_n_i = 1'b0;
    tick();
    if (q_n_o !== ~6'b10_1001) begin
      $display("FAIL simultaneous: q=%b", q_n_o);
      errors++;
    end
    w4_n_i = 1'b1;
    w2_n_i = 1'b1;

    // Random phase against the shadow model.
    for (rounds = 0; rounds < 5000; rounds++) begin
      rng = next_random(rng);
      d_i = rng[7:2];
      {w2_n_i, w4_n_i} = rng[1:0];
      tick();
    end

    if (errors == 0) begin
      $display("intel_3404 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("intel_3404 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "intel_3404 testbench failed");
    end
    $finish;
  end
endmodule
