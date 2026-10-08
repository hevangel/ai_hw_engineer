`timescale 1ns/1ps
// Intel 3404 high-speed 6-bit latch (functional reconstruction).
//
// Six inverting latch stages organized as an independent 4-bit section and
// 2-bit section, each with its own active-low write enable: while W# is
// low the section is transparent (output = inverted data); the rising edge
// of W# stores, and a high W# holds. The two sections never interact.
//
// ASSUMPTION (A1, spec.md): logical d_i[3:0]/q_n_o[3:0] are the 4-bit
// section on write enable w4_n_i (pin 7), d_i[5:4]/q_n_o[5:4] the 2-bit
// section on w2_n_i (pin 15). Corroborated by the datasheet's "independent
// 4-bit and 2-bit latches" text and its input-load figures (pin 7 -1.0 mA
// vs pin 15 -0.5 mA, four gated inputs vs two). The physical DIP stage
// order is not modeled.
//
// DEVIATION (A3, spec.md): clk/rst_n are reconstruction artifacts. The
// physical part has no clock or reset and powers up indeterminate; the
// synchronous model samples transparency at clock edges and reset drives
// the stored bits to zero (q_n outputs high) for deterministic
// verification.
module intel_3404 (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [5:0] d_i,
    input  logic       w4_n_i,
    input  logic       w2_n_i,
    output logic [5:0] q_n_o
);
  logic [3:0] q4_n;
  logic [1:0] q2_n;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      q4_n <= 4'hF;
      q2_n <= 2'b11;
    end else begin
      if (!w4_n_i) q4_n <= ~d_i[3:0];
      if (!w2_n_i) q2_n <= ~d_i[5:4];
    end
  end

  assign q_n_o = {q2_n, q4_n};
endmodule
