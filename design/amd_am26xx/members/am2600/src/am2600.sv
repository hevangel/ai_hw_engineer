`timescale 1ns/1ps
// Am2600 single retriggerable monostable multivibrator (functional
// reconstruction).
//
// Contract: AMD 1974 Data Book, catalog pages 4-15 to 4-20. Five trigger
// inputs combine into one network whose rising edge starts a timing cycle:
// the two active-low inputs (I0#, I1#) OR together, gated with the three
// active-high inputs I2..I4. Either active-low direct clear (CO0#, CO1#)
// terminates a cycle immediately and inhibits triggering while held low.
// Q pulses HIGH for the cycle; Q# is its complement.
//
// The physical pulse width is set by an external RC network
// (T = 0.32*Rx*Cx*(1 + 3.7/Rx) ns); the reconstruction counts PULSE_CYCLES
// rising edges of the abstraction reference clock clk_i instead. clk_i is
// not a device pin. An edge occurring while a clear is held low never
// fires, matching the documented inhibit-while-cleared behavior.
module am2600 #(
    parameter int unsigned PULSE_CYCLES = 4  // documented abstraction width
) (
    input  logic clk_i,    // abstraction timing reference (not a device pin)
    input  logic i0_n_i,   // I0# pin 1: active-low trigger input
    input  logic i1_n_i,   // I1# pin 2: active-low trigger input
    input  logic i2_i,     // I2  pin 3: active-high trigger input
    input  logic i3_i,     // I3  pin 4: active-high trigger input
    input  logic i4_i,     // I4  pin 5: active-high trigger input
    input  logic co0_n_i,  // CO0# pin 9: asynchronous direct clear
    input  logic co1_n_i,  // CO1# pin 10: asynchronous direct clear
    output logic q_o,      // Q   pin 6: true output, HIGH during cycle
    output logic q_n_o     // Q#  pin 8: complementary output
);
  // Trigger network per the Table I truth table.
  logic n_trig;
  assign n_trig = (!i0_n_i || !i1_n_i) && i2_i && i3_i && i4_i;

  logic clear_n;
  assign clear_n = co0_n_i && co1_n_i;  // active when both clears are HIGH

  // Trigger edge detection, inhibited while any clear is held low: an edge
  // is recognized only when the clears are inactive at this and the
  // previous reference edge, so a rise during a held clear never fires.
  logic n_trig_q = 1'b0, clear_n_q = 1'b1;
  always_ff @(posedge clk_i) begin
    /* verilator lint_off SYNCASYNCNET */
    // Intentional: the asynchronous clear pin is also sampled so a trigger
    // edge is recognized only when the clear was inactive for a full
    // reference cycle (documented inhibit-while-cleared behavior).
    n_trig_q  <= n_trig;
    clear_n_q <= clear_n;
    /* verilator lint_on SYNCASYNCNET */
  end
  logic trig;
  assign trig = n_trig && !n_trig_q && clear_n && clear_n_q;

  // Timing cycle counter with asynchronous direct clear. The declaration
  // initializer realizes the documented modeling assumption that the
  // reconstruction presents the quiescent state from elaboration.
  logic running = 1'b0;
  logic [31:0] count = 32'd0;
  always_ff @(posedge clk_i or negedge clear_n) begin
    if (!clear_n) begin
      running <= 1'b0;
      count   <= 32'd0;
    end else if (trig) begin
      running <= 1'b1;
      count   <= 32'(PULSE_CYCLES) - 32'd1;
    end else if (running) begin
      if (count == 32'd0) begin
        running <= 1'b0;
      end else begin
        count <= count - 32'd1;
      end
    end
  end

  assign q_o   = running;
  assign q_n_o = !running;
endmodule
