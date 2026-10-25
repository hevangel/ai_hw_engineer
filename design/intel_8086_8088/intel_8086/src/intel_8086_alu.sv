`timescale 1ns / 1ps
// Intel 1979 manual: ADD/ADC/SUB/SBB and boolean flag definitions.
module intel_8086_alu (
    input logic wide_i,
    input logic [2:0] kind_i,
    input logic [15:0] lhs_i,
    rhs_i,
    flags_i,
    output logic [15:0] value_o,
    flags_o
);
  logic [16:0] lhs, rhs, total;
  logic subtract_op, arithmetic_op, carry_in, sign_l, sign_r, sign_v;
  always_comb begin
    lhs = {1'b0, (wide_i ? lhs_i : {8'b0, lhs_i[7:0]})};
    rhs = {1'b0, (wide_i ? rhs_i : {8'b0, rhs_i[7:0]})};
    subtract_op = kind_i == 3 || kind_i == 5 || kind_i == 7;
    arithmetic_op = kind_i == 0 || kind_i == 2 || subtract_op;
    carry_in = (kind_i == 2 || kind_i == 3) && flags_i[0];
    total = subtract_op ? lhs - rhs - {16'b0, carry_in} : lhs + rhs + {16'b0, carry_in};
    case (kind_i)
      1: total = lhs | rhs;
      4: total = lhs & rhs;
      6: total = lhs ^ rhs;
      default: ;
    endcase
    value_o = wide_i ? total[15:0] : {8'b0, total[7:0]};
    flags_o = (flags_i & 16'h0fd5) | 16'hf002;
    sign_l = wide_i ? lhs_i[15] : lhs_i[7];
    sign_r = wide_i ? rhs_i[15] : rhs_i[7];
    sign_v = wide_i ? value_o[15] : value_o[7];
    flags_o[0] = arithmetic_op && (wide_i ? total[16] : total[8]);
    flags_o[2] = ~^value_o[7:0];
    // ASSUMPTION: A4. Logic instructions leave their undefined AF unchanged.
    if (arithmetic_op) flags_o[4] = lhs_i[4] ^ rhs_i[4] ^ value_o[4];
    flags_o[6] = value_o == 0;
    flags_o[7] = sign_v;
    flags_o[11] = arithmetic_op && (sign_l ^ sign_v) &&
        (subtract_op ? (sign_l ^ sign_r) : !(sign_l ^ sign_r));
  end
endmodule
