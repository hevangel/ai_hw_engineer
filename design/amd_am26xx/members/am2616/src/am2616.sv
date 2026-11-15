`timescale 1ns/1ps
// Am2616 quad MIL-188C and RS-232C line driver (functional
// reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-78 to 4-82
// (logic symbol LIC-411, circuit diagram LIC-412, connection diagram
// LIC-413 on page 4-78). Four inverting drivers; driver A has two data
// inputs, drivers B/C/D one each. Each output is gated by its inhibit
// input:
//
//   out_a = !((in_a1 && in_a2) || inhibit_a)
//   out_b = !(in_b || inhibit_b)      (same for C and D)
//
// so a HIGH inhibit "forces the driver output to VOL or to mark state"
// (the RS-232C spacing condition reads as output LOW in this boolean
// model). The RS-232C electrical conventions (positive = space,
// negative = mark), slew-rate limiting, the +-12 V swing from the VEE
// supply and short-circuit protection are documented in the spec and
// not modeled.
module am2616 (
    input  logic in_a1_i,      // INPUT A1    pin 1
    input  logic in_a2_i,      // INPUT A2    pin 2
    input  logic inhibit_a_i,  // INHIBIT A   pin 3
    output logic out_a_o,      // OUTPUT A    pin 4
    input  logic in_b_i,       // INPUT B     pin 5
    input  logic inhibit_b_i,  // INHIBIT B   pin 6
    output logic out_b_o,      // OUTPUT B    pin 7
    input  logic in_c_i,       // INPUT C     pin 12
    input  logic inhibit_c_i,  // INHIBIT C   pin 11
    output logic out_c_o,      // OUTPUT C    pin 10
    input  logic in_d_i,       // INPUT D     pin 15
    input  logic inhibit_d_i,  // INHIBIT D   pin 14
    output logic out_d_o       // OUTPUT D    pin 13
);
  assign out_a_o = !((in_a1_i && in_a2_i) || inhibit_a_i);
  assign out_b_o = !(in_b_i || inhibit_b_i);
  assign out_c_o = !(in_c_i || inhibit_c_i);
  assign out_d_o = !(in_d_i || inhibit_d_i);
endmodule
