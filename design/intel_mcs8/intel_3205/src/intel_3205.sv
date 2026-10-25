`timescale 1ns/1ps
// Intel 3205 high-speed 1-of-8 binary decoder (functional reconstruction).
//
// Three address inputs select one of eight active-low outputs whenever the
// three chip enables agree: E1# and E2# low, E3 high. With any enable
// inactive all eight outputs sit high, so disabled parts present no chip
// select to the attached memory row. The device is purely combinational;
// the datasheet's 18 ns electrical delay is not modeled.
module intel_3205 (
    input  logic [2:0] a_i,
    input  logic       e1_n_i,
    input  logic       e2_n_i,
    input  logic       e3_i,
    output logic [7:0] out_n_o
);
  logic enable;
  assign enable = (e1_n_i == 1'b0) && (e2_n_i == 1'b0) && (e3_i == 1'b1);
  assign out_n_o = enable ? ~(8'b0000_0001 << a_i) : 8'hFF;
endmodule
