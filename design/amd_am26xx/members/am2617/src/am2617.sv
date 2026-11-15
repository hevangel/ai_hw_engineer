`timescale 1ns/1ps
// Am2617 quad RS-232C line receiver (functional reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-82 to 4-85
// (logic symbol LIC-417, circuit diagram LIC-418, connection diagram
// LIC-419 on page 4-82). Four inverting receivers with hysteresis and a
// response-control input each. In the boolean line model, an input at
// the positive (space) level reads 1 and drives the output LOW; an
// input at the negative (mark) level or below the switching threshold
// reads 0 and drives the output HIGH:
//
//   OUT = !IN
//
// The documented hysteresis window (switch LOW at +2.25 V rising, HIGH
// at +0.75 V falling), the 2 k-ohm internal pull-up, the response-
// control bias effect and the +-30 V input range are analog properties
// documented in the spec and not modeled.
module am2617 (
    input  logic in_a_i,    // A IN   pin 1
    output logic out_a_o,   // A OUT  pin 3
    input  logic in_b_i,    // B IN   pin 4
    output logic out_b_o,   // B OUT  pin 6
    input  logic in_c_i,    // C IN   pin 10
    output logic out_c_o,   // C OUT  pin 8
    input  logic in_d_i,    // D IN   pin 13
    output logic out_d_o    // D OUT  pin 11
);
  assign out_a_o = !in_a_i;
  assign out_b_o = !in_b_i;
  assign out_c_o = !in_c_i;
  assign out_d_o = !in_d_i;
endmodule
