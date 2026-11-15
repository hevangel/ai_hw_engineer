`timescale 1ns/1ps
// Am26LS33 quad differential line receiver (functional reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-40 to 4-44
// (logic diagram BLI-024 and connection diagram LIC-360 on page 4-40).
// The Am26LS33 shares the Am26LS32 logic diagram, pin map and enable
// structure; it differs electrically: 500 mV input sensitivity over the
// +-15 V input voltage range (versus the LS32's 200 mV over +-7 V).
//
//   comp  = (in_p >= in_n)          // binary line model; tie = open line
//   out   = enabled ? comp : 'Z
//   enabled = !en_n || en2
//
// The fail-safe relationship ("output always high when inputs are
// open") and the analog envelope are documented in the spec and the
// electrical differences are not modeled.
module am26ls33 (
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
