`timescale 1ns/1ps
// Original AMD datasheet pp. 2-9/2-12 and application note pp. 8-87/8-88.
module amd_am2505 (
    input logic [3:0] x_i,
    input logic x_prev_i,
    input logic x_sign_i,
    input logic [1:0] y_i,
    input logic y_prev_i,
    input logic [3:0] k_i,
    input logic cn_i,
    input logic polarity_i,
    output logic [5:0] s_o,
    output logic cn4_o
);
  logic [3:0] x, k;
  logic [1:0] y;
  logic xm, xs, ym, cin;
  logic one_x, two_x;
  logic [5:0] magnitude, operand;
  logic [1:0] sign_sum;
  logic [4:0] nibble_sum;

  assign x = x_i ^ {4{polarity_i}};
  assign k = k_i ^ {4{polarity_i}};
  assign y = y_i ^ {2{polarity_i}};
  assign xm = x_prev_i ^ polarity_i;
  assign xs = x_sign_i ^ polarity_i;
  assign ym = y_prev_i ^ polarity_i;
  assign cin = cn_i ^ polarity_i;

  assign one_x = ym ^ y[0];
  assign two_x = (ym == y[0]) && (y[1] != y[0]);
  assign magnitude = ({6{one_x}} & {xs,xs,x}) |
                     ({6{two_x}} & {xs,x,xm});
  assign operand = magnitude ^ {6{y[1]}};
  // The caller supplies the +1 for negative Booth digits via Cn=Y1.
  assign nibble_sum = {1'b0,operand[3:0]} + {1'b0,k} + {4'b0,cin};
  assign sign_sum = operand[5:4] + {2{k[3]}} + {1'b0,nibble_sum[4]};
  assign s_o = {sign_sum,nibble_sum[3:0]} ^ {6{polarity_i}};
  assign cn4_o = nibble_sum[4] ^ polarity_i;

`ifdef FORMAL
  always_comb assert (!(one_x && two_x));
`endif
endmodule
