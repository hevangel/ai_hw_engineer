`timescale 1ns/1ps
// Am26LS32 quad differential RS-422/RS-423 line receiver (functional
// reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-40 to 4-44
// (logic diagram BLI-024 and connection diagram LIC-360 on page 4-40),
// plus the quad-family application note pages 4-45 to 4-56. Four
// non-inverting differential receivers with 3-state outputs and a
// common enable pair (pin 4 active low, pin 12 active high; outputs
// enabled when either is asserted), and the documented fail-safe: the
// outputs stay HIGH when the inputs are open.
//
//   comp  = (in_p >= in_n)          // binary line model; tie = open line
//   out   = enabled ? comp : 'Z
//   enabled = !en_n || en2
//
// The analog envelope (200 mV sensitivity over +-7 V, 30 mV hysteresis,
// 17 ns typical delay, 8 mA sink 3-state drive) is documented in the
// spec and not modeled.
module am26ls32 (
    input  logic a_in_n_i,    // INPUTS A  pin 1: inverting (−) input
    input  logic a_in_p_i,    // INPUTS A  pin 2: non-inverting (+) input
    output logic a_out_o,     // OUTPUT A  pin 3: 3-state
    input  logic en_n_i,      // ENABLE    pin 4: active low
    input  logic c_in_p_i,    // INPUTS C  pin 6: non-inverting (+) input
    input  logic c_in_n_i,    // INPUTS C  pin 7: inverting (−) input
    output logic c_out_o,     // OUTPUT C  pin 5: 3-state
    input  logic d_in_p_i,    // INPUTS D  pin 10: non-inverting (+) input
    input  logic d_in_n_i,    // INPUTS D  pin 9: inverting (−) input
    output logic d_out_o,     // OUTPUT D  pin 11: 3-state
    input  logic en2_i,       // ENABLE(bar) pin 12: active high
    input  logic b_in_n_i,    // INPUTS B  pin 15: inverting (−) input
    input  logic b_in_p_i,    // INPUTS B  pin 14: non-inverting (+) input
    output logic b_out_o      // OUTPUT B  pin 13: 3-state
);
  logic enabled;
  assign enabled = !en_n_i || en2_i;

  logic a_comp, b_comp, c_comp, d_comp;
  assign a_comp = (a_in_p_i >= a_in_n_i);
  assign b_comp = (b_in_p_i >= b_in_n_i);
  assign c_comp = (c_in_p_i >= c_in_n_i);
  assign d_comp = (d_in_p_i >= d_in_n_i);

  assign a_out_o = enabled ? a_comp : 1'bz;
  assign b_out_o = enabled ? b_comp : 1'bz;
  assign c_out_o = enabled ? c_comp : 1'bz;
  assign d_out_o = enabled ? d_comp : 1'bz;
endmodule
