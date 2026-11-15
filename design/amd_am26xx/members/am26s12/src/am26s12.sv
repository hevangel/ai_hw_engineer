`timescale 1ns/1ps
// Am26S12 / Am26S12A quad bus transceiver (functional reconstruction).
//
// Contract: AMD 1974 Data Book catalog pages 4-39 to 4-44 (shared sheet
// with the Am26S10/S11, connection diagram page 4-39, truth table page
// 4-41) and the 1979 Linear and Interface Data Book pages 4-62 to 4-66
// (logic diagram LIC-380, connection diagram LIC-382, electrical
// characteristics page 4-63, truth table page 4-65). One documented
// part with two released receiver-hysteresis grades:
//
//   Am26S12  receiver input thresholds VIH 2.0 V typ / VIL 1.4 V typ
//   Am26S12A receiver input thresholds VIH 2.25 V typ / VIL 1.2 V typ
//   (threshold margin > 0.4 V guaranteed in both grades)
//
// The digital contract is identical across the two grades:
//
//   enabled = !E1 && !E2       // dual active-low enables (pins 7, 9);
//                              // "an active LOW, two-input AND gate
//                              // controls the four drivers"
//   B# = enabled ? !I : 'Z     // open-collector inverting driver
//   Z# = !B#                   // receiver, always active
//
// Truth table (page 4-65): with both enables low, B# = !I and Z# = !B#;
// with either enable high the driver releases the bus (B# = Y, the
// level another transceiver or the pull-up sets) and the receiver still
// drives Z# = Ȳ.
//
// Port structure: split driver/receiver ports per bus pin, as in the
// Am26S10/S11 members (the physical B# pins are single bidirectional
// nets; the tie, pull-up bias and party-line resolution are directed in
// the testbench). The hysteresis grades are electrical behavior — the
// REVISION parameter pins the documented threshold pair per grade and
// is checked at elaboration; the digital function does not depend on
// it.
module am26s12 #(
    parameter integer REVISION = 0  // 0 = Am26S12, 1 = Am26S12A
) (
    input  logic e1_n_i,    // E pin 7:  enable 1, active low
    input  logic e2_n_i,    // E pin 9:  enable 2, active low
    input  logic i0_i,      // I0   pin 2:  channel 0 driver input
    output logic b0_n_o,    // B0#  pin 1:  channel 0 bus (driver role)
    input  logic b0_i,      // B0#  pin 1:  channel 0 bus (receiver role)
    output logic z0_n_o,    // Z0#  pin 3:  channel 0 receiver output
    input  logic i1_i,      // I1   pin 5:  channel 1 driver input
    output logic b1_n_o,    // B1#  pin 4:  channel 1 bus (driver role)
    input  logic b1_i,      // B1#  pin 4:  channel 1 bus (receiver role)
    output logic z1_n_o,    // Z1#  pin 6:  channel 1 receiver output
    input  logic i2_i,      // I2   pin 11: channel 2 driver input
    output logic b2_n_o,    // B2#  pin 12: channel 2 bus (driver role)
    input  logic b2_i,      // B2#  pin 12: channel 2 bus (receiver role)
    output logic z2_n_o,    // Z2#  pin 10: channel 2 receiver output
    input  logic i3_i,      // I3   pin 14: channel 3 driver input
    output logic b3_n_o,    // B3#  pin 15: channel 3 bus (driver role)
    input  logic b3_i,      // B3#  pin 15: channel 3 bus (receiver role)
    output logic z3_n_o     // Z3#  pin 13: channel 3 receiver output
);
  // Documented receiver input thresholds per grade (volts, typ), per
  // the 1979 electrical characteristics table. Electrical constants
  // recorded for the contract; the digital function does not use them.
  localparam real TH_VIH_TYP = (REVISION == 1) ? 2.25 : 2.0;
  localparam real TH_VIL_TYP = (REVISION == 1) ? 1.2  : 1.4;

  if (REVISION != 0 && REVISION != 1) begin : gen_bad_revision
    $error("am26s12: REVISION must be 0 (Am26S12) or 1 (Am26S12A)");
  end
  // Documented threshold-margin guarantee: "the threshold margin, the
  // difference between the switching points, is greater than 0.4
  // volts" for both grades (1979 book, page 4-62).
  if ((TH_VIH_TYP - TH_VIL_TYP) <= 0.4) begin : gen_margin_check
    $error("am26s12: documented threshold margin violated for this REVISION");
  end

  logic enabled;
  assign enabled = !e1_n_i && !e2_n_i;

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
