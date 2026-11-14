`timescale 1ns/1ps
// Am26LS29 quad three-state single-ended RS-423 line driver (functional
// reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-26 to 4-29
// (logic diagram BLI-001, connection diagram BLI-004 on page 4-26;
// switching waveforms pages 4-27/4-28). Four non-inverting single-ended
// drivers with three-state outputs gated by one active-low enable:
//
//   out = enable ? in : 'Z      // enable (pin 4) active low
//
// The per-output slew-rate-control pins connect an external capacitor
// for rise/fall-time control and have no boolean effect. The analog
// envelope (RS-423 conformance, +-6 V output swing from the VCC/VEE
// supplies, slew-rate figures, 50-ohm line drive) is documented in the
// spec and not modeled.
module am26ls29 (
    input  logic in_a_i,       // INPUT A             pin 2
    output logic out_a_o,      // OUTPUT A            pin 15
    input  logic in_b_i,       // INPUT B             pin 3
    output logic out_b_o,      // OUTPUT B            pin 14
    input  logic en_n_i,       // ENABLE              pin 4: active low
    input  logic in_c_i,       // INPUT C             pin 6
    output logic out_c_o,      // OUTPUT C            pin 11
    input  logic in_d_i,       // INPUT D             pin 7
    output logic out_d_o,      // OUTPUT D            pin 10
    input  logic sr_a_i,       // SLEW RATE CONTROL A pin 16 (unmodeled)
    input  logic sr_b_i,       // SLEW RATE CONTROL B pin 13 (unmodeled)
    input  logic sr_c_i,       // SLEW RATE CONTROL C pin 12 (unmodeled)
    input  logic sr_d_i        // SLEW RATE CONTROL D pin 9  (unmodeled)
);
  // Slew-rate-control pins are analog-only; reference them so lint stays
  // clean while documenting their presence in the port map.
  logic _unused_sr = &{1'b1, sr_a_i, sr_b_i, sr_c_i, sr_d_i};

  logic enabled;
  assign enabled = !en_n_i;

  assign out_a_o = enabled ? in_a_i : 1'bz;
  assign out_b_o = enabled ? in_b_i : 1'bz;
  assign out_c_o = enabled ? in_c_i : 1'bz;
  assign out_d_o = enabled ? in_d_i : 1'bz;
endmodule
