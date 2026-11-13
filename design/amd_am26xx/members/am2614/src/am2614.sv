`timescale 1ns/1ps
// Am2614 quad single-ended line driver (functional reconstruction).
//
// Contract: AMD 1974 Data Book catalog pages 4-45 to 4-50 (page 4-45
// logic and connection diagrams; the identical part is reprinted in the
// 1979 Linear and Interface Data Book pages 4-67 to 4-71). Four
// independent 3-input inverting drivers ("two separate inputs and one
// common-strobe input" per pair): each output is
// OUT = !(IN_x & IN_y & STROBE_pair), so a low strobe idles the line
// HIGH and a low data input asserts it HIGH regardless of the other.
//
// Electrical behavior (50-ohm line drive, short-circuit protection,
// active pull-up, propagation delays) is documented in the spec and not
// modeled; the reconstruction is a zero-delay combinational contract.
module am2614 (
    input  logic strobe_a_i,   // STROBE A pin 1: common gate of pair A
    input  logic in_a1a_i,     // INPUT A1 pin 2: driver A1 data input
    input  logic in_a1b_i,     // INPUT A1 pin 3: driver A1 data input
    output logic out_a1_o,     // OUTPUT A1 pin 4
    input  logic in_a2a_i,     // INPUT A2 pin 5: driver A2 data input
    input  logic in_a2b_i,     // INPUT A2 pin 6: driver A2 data input
    output logic out_a2_o,     // OUTPUT A2 pin 7
    input  logic strobe_b_i,   // STROBE B pin 15: common gate of pair B
    input  logic in_b1a_i,     // INPUT B1 pin 14: driver B1 data input
    input  logic in_b1b_i,     // INPUT B1 pin 13: driver B1 data input
    output logic out_b1_o,     // OUTPUT B1 pin 12
    input  logic in_b2a_i,     // INPUT B2 pin 11: driver B2 data input
    input  logic in_b2b_i,     // INPUT B2 pin 10: driver B2 data input
    output logic out_b2_o      // OUTPUT B2 pin 9
);
  assign out_a1_o = !(in_a1a_i && in_a1b_i && strobe_a_i);
  assign out_a2_o = !(in_a2a_i && in_a2b_i && strobe_a_i);
  assign out_b1_o = !(in_b1a_i && in_b1b_i && strobe_b_i);
  assign out_b2_o = !(in_b2a_i && in_b2b_i && strobe_b_i);
endmodule
