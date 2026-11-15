`timescale 1ns/1ps
// Am26S11 quad bus transceiver (functional reconstruction).
//
// Contract: AMD 1974 Data Book catalog pages 4-39 to 4-44 (truth tables
// page 4-41; identical reprint in the 1979 Linear and Interface Data
// Book pages 4-57 to 4-61, truth tables page 4-59). The Am26S11 is the
// non-inverting sibling of the Am26S10: same pin map, same always-on
// inverting receiver, but the open-collector driver does not invert:
//
//   B# = !E ? I : 'Z           // open-collector driver (non-inverting)
//   Z# = !B#                   // receiver follows the bus, always on
//
// Truth table (page 4-41): with E low, B# = I and Z# = !B#; with E high
// the driver releases the bus (B# = Y) and the receiver still drives
// Z# = Ȳ. Port structure as in the Am26S10 spec (split driver/receiver
// ports per bus pin; the tie, pull-up bias and party-line resolution
// are directed in the testbench).
module am26s11 (
    input  logic e_n_i,     // E    pin 12: enable, active low
    input  logic i0_i,      // I0   pin 4:  channel 0 driver input
    output logic b0_n_o,    // B0#  pin 2:  channel 0 bus (driver role)
    input  logic b0_i,      // B0#  pin 2:  channel 0 bus (receiver role)
    output logic z0_n_o,    // Z0#  pin 3:  channel 0 receiver output
    input  logic i1_i,      // I1   pin 5:  channel 1 driver input
    output logic b1_n_o,    // B1#  pin 7:  channel 1 bus (driver role)
    input  logic b1_i,      // B1#  pin 7:  channel 1 bus (receiver role)
    output logic z1_n_o,    // Z1#  pin 6:  channel 1 receiver output
    input  logic i2_i,      // I2   pin 11: channel 2 driver input
    output logic b2_n_o,    // B2#  pin 9:  channel 2 bus (driver role)
    input  logic b2_i,      // B2#  pin 9:  channel 2 bus (release only)
    output logic z2_n_o,    // Z2#  pin 10: channel 2 receiver output
    input  logic i3_i,      // I3   pin 13: channel 3 driver input
    output logic b3_n_o,    // B3#  pin 15: channel 3 bus (driver role)
    input  logic b3_i,      // B3#  pin 15: channel 3 bus (receiver role)
    output logic z3_n_o     // Z3#  pin 14: channel 3 receiver output
);
  logic enabled;
  assign enabled = !e_n_i;

  assign b0_n_o = enabled ? i0_i : 1'bz;
  assign b1_n_o = enabled ? i1_i : 1'bz;
  assign b2_n_o = enabled ? i2_i : 1'bz;
  assign b3_n_o = enabled ? i3_i : 1'bz;

  // Always-active inverting bus receivers.
  assign z0_n_o = !b0_i;
  assign z1_n_o = !b1_i;
  assign z2_n_o = !b2_i;
  assign z3_n_o = !b3_i;
endmodule
