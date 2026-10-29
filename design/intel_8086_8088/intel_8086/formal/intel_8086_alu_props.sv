`ifdef FORMAL
module intel_8086_alu_props;
  (* anyconst *) logic wide;
  (* anyconst *) logic [2:0] kind;
  (* anyconst *) logic [15:0] lhs, rhs, flags;
  logic [15:0] value, result_flags;
  logic [16:0] a, b, result;
  logic [4:0] nibble_sum;
  logic subtract_op, arithmetic_op, carry_in;
  logic signed [17:0] signed_a, signed_b, signed_result;
  intel_8086_alu dut (
      .wide_i (wide),
      .kind_i (kind),
      .lhs_i  (lhs),
      .rhs_i  (rhs),
      .flags_i(flags),
      .value_o(value),
      .flags_o(result_flags)
  );
  always_comb begin
    a = wide ? {1'b0, lhs} : {9'b0, lhs[7:0]};
    b = wide ? {1'b0, rhs} : {9'b0, rhs[7:0]};
    subtract_op = kind == 3 || kind == 5 || kind == 7;
    arithmetic_op = kind == 0 || kind == 2 || subtract_op;
    carry_in = (kind == 2 || kind == 3) && flags[0];
    result = subtract_op ? a - b - {16'b0, carry_in} : a + b + {16'b0, carry_in};
    nibble_sum = {1'b0, lhs[3:0]} + {1'b0, rhs[3:0]} + {4'b0, carry_in};
    signed_a = wide ? {{2{lhs[15]}}, lhs} : {{10{lhs[7]}}, lhs[7:0]};
    signed_b = wide ? {{2{rhs[15]}}, rhs} : {{10{rhs[7]}}, rhs[7:0]};
    signed_result = subtract_op ? signed_a - signed_b - $signed({17'b0, carry_in}) :
        signed_a + signed_b + $signed({17'b0, carry_in});
    if (arithmetic_op) begin
      assert (value == (wide ? result[15:0] : {8'b0, result[7:0]}));
      if (subtract_op) begin
        assert (result_flags[0] == (a < b + {16'b0, carry_in}));
        assert (result_flags[4] == ({1'b0, lhs[3:0]} < {1'b0, rhs[3:0]} + {4'b0, carry_in}));
      end else begin
        assert (result_flags[0] == (wide ? result > 17'd65535 : result > 17'd255));
        assert (result_flags[4] == nibble_sum[4]);
      end
      assert(result_flags[11] == (wide ? (signed_result < -18'sd32768 || signed_result > 18'sd32767) :
          (signed_result < -18'sd128 || signed_result > 18'sd127)));
    end else begin
      case (kind)
        1: assert (value == (wide ? lhs | rhs : {8'b0, lhs[7:0] | rhs[7:0]}));
        4: assert (value == (wide ? lhs & rhs : {8'b0, lhs[7:0] & rhs[7:0]}));
        6: assert (value == (wide ? lhs ^ rhs : {8'b0, lhs[7:0] ^ rhs[7:0]}));
        default: assert (0);
      endcase
      assert (!result_flags[0] && !result_flags[11]);
      assert (result_flags[4] == flags[4]);
    end
    assert (result_flags[6] == (value == 0));
    assert (result_flags[7] == (wide ? value[15] : value[7]));
    assert(result_flags[2] == !(value[0]^value[1]^value[2]^value[3]^value[4]^value[5]^value[6]^value[7]));
    assert ((result_flags & 16'hf02a) == 16'hf002);
    assert (result_flags[10:8] == flags[10:8]);
    cover (wide && kind == 0 && result_flags[11] && result_flags[0]);
    cover (!wide && kind == 3 && result_flags[6] && result_flags[4]);
    cover (wide && kind == 6 && result_flags[6]);
  end
endmodule
`endif
