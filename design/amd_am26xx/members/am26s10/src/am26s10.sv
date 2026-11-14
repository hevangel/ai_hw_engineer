`timescale 1ns/1ps
// Am26S10 quad bus transceiver (functional reconstruction).
//
// Contract: AMD 1974 Data Book catalog pages 4-39 to 4-44 (page 4-39
// logic diagram and connection diagram; truth table with the switching
// characteristics; the identical part is reprinted in the 1979 Linear
// and Interface Data Book pages 4-57 to 4-61, truth tables page 4-59).
// Four channels, each: an open-collector inverting bus driver (B#)
// gated by the common active-low enable E, and a separate always-active
// inverting bus receiver (Z#) tied to the same bus node:
//
//   B# = !E ? !I : 'Z          // open-collector driver
//   Z# = !B#                   // receiver follows the bus, always on
//
// The truth table states this directly: with E low, B# = !I and
// Z# = !B#; with E high the driver releases the bus (B# = Y, the level
// set by another transceiver or the pull-up bias) and the receiver
// still drives Z# = Ȳ = !Y.
//
// Port structure: the physical B# pins are single bidirectional bus
// nets serving two roles. For synthesis and formal compatibility the
// reconstruction exposes the roles separately — `b#_n_o` is the
// open-collector driver output and `b#_i` the receiver bus input — and
// the testbench ties each pair onto one tristate net with pull-up bias
// (the party-line section drives them from two instances). The open-
// collector pull-up biasing, the 2.0 V receiver switching point, PNP
// input loading and the 100 mA sink capability are documented in the
// spec and not modeled.
module am26s10 (
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
    input  logic b2_i,      // B2#  pin 9:  channel 2 bus (receiver role)
    output logic z2_n_o,    // Z2#  pin 10: channel 2 receiver output
    input  logic i3_i,      // I3   pin 13: channel 3 driver input
    output logic b3_n_o,    // B3#  pin 15: channel 3 bus (driver role)
    input  logic b3_i,      // B3#  pin 15: channel 3 bus (receiver role)
    output logic z3_n_o     // Z3#  pin 14: channel 3 receiver output
);
  logic enabled;
  assign enabled = !e_n_i;

  assign b0_n_o = enabled ? !i0_i : 1'bz;
  assign b1_n_o = enabled ? !i1_i : 1'bz;
  assign b2_n_o = enabled ? !i2_i : 1'bz;
  assign b3_n_o = enabled ? !i3_i : 1'bz;

  // Always-active inverting bus receivers.
  assign z0_n_o = !b0_i;
  assign z1_n_o = !b1_i;
  assign z2_n_o = !b2_i;
  assign z3_n_o = !b3_i;
endmodule
