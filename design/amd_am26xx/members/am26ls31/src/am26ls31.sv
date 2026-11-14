`timescale 1ns/1ps
// Am26LS31 quad high-speed differential line driver (functional
// reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-36 to 4-39
// (logic diagram LIC-352, connection diagram LIC-353, switching
// characteristics page 4-37, equivalent circuit and application page
// 4-38). Four differential drivers with complementary 3-state outputs
// and an OR-ed complementary enable pair:
//
//   enabled = !en_n || en2        // pin 4 low or pin 12 high
//   y       = enabled ? in  : 'Z  // true output (A+..D+)
//   z       = enabled ? !in : 'Z  // complementary output (A-..D-)
//
// The analog envelope (RS-422 conformance, 2.0 ns output skew, 12 ns
// typical delay, 100-ohm terminated-line drive, short-circuit
// protection) is documented in the spec and not modeled.
module am26ls31 (
    input  logic in_a_i,     // INPUT A   pin 1
    output logic y_a_o,      // OUTPUT A+ pin 2: true  3-state output
    output logic z_a_o,      // OUTPUT A- pin 3: complement 3-state output
    input  logic en_n_i,     // ENABLE    pin 4: active low
    output logic y_b_o,      // OUTPUT B+ pin 5: true  3-state output
    output logic z_b_o,      // OUTPUT B- pin 6: complement 3-state output
    input  logic in_b_i,     // INPUT B   pin 7
    input  logic in_c_i,     // INPUT C   pin 9
    output logic y_c_o,      // OUTPUT C+ pin 10: true  3-state output
    output logic z_c_o,      // OUTPUT C- pin 11: complement 3-state output
    input  logic en2_i,      // ENABLE(bar) pin 12: active high
    output logic z_d_o,      // OUTPUT D- pin 13: complement 3-state output
    output logic y_d_o,      // OUTPUT D+ pin 14: true  3-state output
    input  logic in_d_i      // INPUT D   pin 15
);
  logic enabled;
  assign enabled = !en_n_i || en2_i;

  assign y_a_o = enabled ? in_a_i  : 1'bz;
  assign z_a_o = enabled ? !in_a_i : 1'bz;
  assign y_b_o = enabled ? in_b_i  : 1'bz;
  assign z_b_o = enabled ? !in_b_i : 1'bz;
  assign y_c_o = enabled ? in_c_i  : 1'bz;
  assign z_c_o = enabled ? !in_c_i : 1'bz;
  assign y_d_o = enabled ? in_d_i  : 1'bz;
  assign z_d_o = enabled ? !in_d_i : 1'bz;
endmodule
