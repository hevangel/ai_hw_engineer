`timescale 1ns/1ps
`ifdef FORMAL
module amd_am2505_props (
    input logic [3:0] x_i, k_i,
    input logic x_prev_i, x_sign_i,
    input logic [1:0] y_i,
    input logic y_prev_i, cn_i, polarity_i
);
  logic [5:0] s;
  logic carry;
  logic [3:0] xn, kn;
  logic [1:0] yn;
  logic xm, ym, cin;
  integer sx, sk, digit, result_value, low_operand, low_sum;
  amd_am2505 dut (
      .x_i(x_i), .x_prev_i(x_prev_i), .x_sign_i(x_sign_i),
      .y_i(y_i), .y_prev_i(y_prev_i), .k_i(k_i), .cn_i(cn_i),
      .polarity_i(polarity_i), .s_o(s), .cn4_o(carry)
  );
  always_comb begin
    xn = x_i ^ {4{polarity_i}};
    kn = k_i ^ {4{polarity_i}};
    yn = y_i ^ {2{polarity_i}};
    xm = x_prev_i ^ polarity_i;
    ym = y_prev_i ^ polarity_i;
    cin = cn_i ^ polarity_i;
    sx = int'($signed(xn));
    sk = int'($signed(kn));
    digit = int'(ym) + int'(yn[0]) - 2*int'(yn[1]);
    result_value = digit*sx + sk + int'(cin) - int'(yn[1]);
    if (digit == 2) result_value = result_value + int'(xm);
    if (digit == -2) result_value = result_value - int'(xm);
    // Separately transcribed Booth table for the actual nibble carry.
    case ({yn[1],yn[0],ym})
      3'b000,3'b111: low_operand = 0;
      3'b001,3'b010,3'b101,3'b110: low_operand = int'(xn);
      3'b011,3'b100: low_operand = (2*int'(xn) + int'(xm)) & 15;
    endcase
    if (yn[1]) low_operand = 15 - low_operand;
    low_sum = low_operand + int'(kn) + int'(cin);
    assert ((s[3:0] ^ {4{polarity_i}}) == result_value[3:0]);
    assert ((carry ^ polarity_i) == (low_sum >= 16));
    if (x_sign_i == x_i[3])
      assert ((s ^ {6{polarity_i}}) == result_value[5:0]);
    for (integer selection = 0; selection < 8; selection++) begin
      cover ({yn[1],yn[0],ym} == 3'(selection) && x_sign_i == x_i[3]);
    end
    cover (polarity_i && digit == -2 && sx == -8 && cin == 1);
    cover (!polarity_i && digit == 2 && sx == 7);
    cover (digit == -1 && carry != polarity_i);
  end
endmodule
`endif
