`timescale 1ns / 1ps
// One original-8086 shift/rotate step. The controller uses the full 8-bit CL.
module intel_8086_shift (
    input logic wide_i,
    input logic [2:0] kind_i,
    input logic [15:0] value_i,
    flags_i,
    output logic [15:0] value_o,
    flags_o
);
  logic sign_bit, carry;
  always_comb begin
    sign_bit = wide_i ? value_i[15] : value_i[7];
    carry = kind_i[0] ? value_i[0] : sign_bit;
    value_o = value_i;
    case (kind_i)
      0: value_o = (value_i << 1) | {15'b0, sign_bit};
      1: value_o = (value_i >> 1) | (wide_i ? {value_i[0], 15'b0} : {8'b0, value_i[0], 7'b0});
      2: value_o = (value_i << 1) | {15'b0, flags_i[0]};
      3: value_o = (value_i >> 1) | (wide_i ? {flags_i[0], 15'b0} : {8'b0, flags_i[0], 7'b0});
      4: value_o = value_i << 1;
      5: value_o = value_i >> 1;
      6: value_o = 16'hffff;
      7: value_o = (value_i >> 1) | (wide_i ? {sign_bit, 15'b0} : {8'b0, sign_bit, 7'b0});
    endcase
    if (!wide_i) value_o[15:8] = 0;
    flags_o = (flags_i & 16'h0fd5) | 16'hf002;
    flags_o[0] = carry;
    case (kind_i)
      0, 2, 4: flags_o[11] = (wide_i ? value_o[15] : value_o[7]) ^ carry;
      1: flags_o[11] = sign_bit ^ value_i[0];
      3: flags_o[11] = sign_bit ^ flags_i[0];
      5: flags_o[11] = sign_bit;
      6: begin
        flags_o[0]  = 0;
        flags_o[11] = 0;
      end
      7: flags_o[11] = 0;
    endcase
    if (kind_i >= 4) begin
      flags_o[2] = ~^value_o[7:0];
      flags_o[6] = value_o == 0;
      flags_o[7] = wide_i ? value_o[15] : value_o[7];
    end
  end
endmodule
