`timescale 1ns/1ps
// Actual four-chip wiring from AMD application note Fig. 8 (pp. 8-88/8-89).
// Every data port is a physical pin level in the selected polarity.
module amd_am2505_array8x4 (
    input logic [7:0] x_i, k_i,
    input logic [3:0] y_i,
    input logic polarity_i,
    output logic [11:0] product_o
);
  logic [5:0] sums [0:3];
  logic [1:0] carries;
  logic [1:0] unused_carries;
  logic [7:0] row1_k;
  assign row1_k = {sums[1][5:0],sums[0][3:2]};
  assign product_o = {sums[3],sums[2][3:0],sums[0][1:0]};

  amd_am2505 row0_low (
      .x_i(x_i[3:0]), .x_prev_i(polarity_i), .x_sign_i(x_i[3]),
      .y_i(y_i[1:0]), .y_prev_i(polarity_i), .k_i(k_i[3:0]),
      .cn_i(y_i[1]), .polarity_i(polarity_i), .s_o(sums[0]), .cn4_o(carries[0])
  );
  amd_am2505 row0_high (
      .x_i(x_i[7:4]), .x_prev_i(x_i[3]), .x_sign_i(x_i[7]),
      .y_i(y_i[1:0]), .y_prev_i(polarity_i), .k_i(k_i[7:4]),
      .cn_i(carries[0]), .polarity_i(polarity_i), .s_o(sums[1]), .cn4_o(unused_carries[0])
  );
  amd_am2505 row1_low (
      .x_i(x_i[3:0]), .x_prev_i(polarity_i), .x_sign_i(x_i[3]),
      .y_i(y_i[3:2]), .y_prev_i(y_i[1]), .k_i(row1_k[3:0]),
      .cn_i(y_i[3]), .polarity_i(polarity_i), .s_o(sums[2]), .cn4_o(carries[1])
  );
  amd_am2505 row1_high (
      .x_i(x_i[7:4]), .x_prev_i(x_i[3]), .x_sign_i(x_i[7]),
      .y_i(y_i[3:2]), .y_prev_i(y_i[1]), .k_i(row1_k[7:4]),
      .cn_i(carries[1]), .polarity_i(polarity_i), .s_o(sums[3]), .cn4_o(unused_carries[1])
  );

  // Upper row carry is physically present but not an extra product bit.
  logic unused_carry_reduction;
  assign unused_carry_reduction = ^unused_carries;
endmodule
