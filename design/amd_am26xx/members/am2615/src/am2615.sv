`timescale 1ns/1ps
// Am2615 dual differential line receiver (functional reconstruction).
//
// Contract: AMD 1974 Data Book catalog pages 4-51 to 4-56 (logic diagram
// page 4-51, strobe transfer characteristics page 4-54, switching test
// circuit and loading rules page 4-55); the identical part is reprinted
// in the 1979 Linear and Interface Data Book pages 4-72 to 4-77 (logic
// diagram LIC-399 on 4-72). Each receiver is a differential comparator
// followed by a strobe gate:
//
//   OUT = !(COMP && STROBE)
//
// where COMP is the comparator decision (TRUE when VIN+ > VIN-). The
// strobe (pins 3/13) LOW holds the output HIGH. The response-control
// pins (4/12) bring the comparator output out for an optional
// frequency-response capacitor and have no digital effect.
//
// The differential decision is modeled on binary line states:
// COMP = in_p && !in_n for the two defined differential states; the
// equal-inputs code stands for the open/undriven line, which the
// Am2615's documented fail-safe resolves as COMP = 1 ("output going to
// a LOW state when the inputs are open or disconnected", so OUT is LOW
// with the strobe high). Input threshold voltage (-1.5 V on the Am2615,
// about 0 V on the Am9615), common-mode range and response timing are
// analog properties documented in the spec and not modeled.
module am2615 (
    input  logic a_in_p_i,    // +INPUT A  pin 5:  differential line +
    input  logic a_in_n_i,    // -INPUT A  pin 7:  differential line -
    input  logic a_strobe_i,  // STROBE A  pin 3:  strobe, active high
    output logic a_out_o,     // OUTPUT A  pin 1
    input  logic b_in_p_i,    // +INPUT B  pin 11: differential line +
    input  logic b_in_n_i,    // -INPUT B  pin 9:  differential line -
    input  logic b_strobe_i,  // STROBE B  pin 13: strobe, active high
    output logic b_out_o      // OUTPUT B  pin 15
);
  // Differential decision with the documented fail-safe on ties.
  logic a_comp, b_comp;
  assign a_comp = a_in_p_i || !a_in_n_i;  // (in_p >= in_n) on {0,1}
  assign b_comp = b_in_p_i || !b_in_n_i;

  assign a_out_o = !(a_comp && a_strobe_i);
  assign b_out_o = !(b_comp && b_strobe_i);
endmodule
