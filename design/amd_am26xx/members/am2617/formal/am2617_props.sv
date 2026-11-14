`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2617 reconstruction: per-receiver inversion
// contract and covers for every state class.
module am2617_props (
    input logic in_a_i, in_b_i, in_c_i, in_d_i
);
  logic out_a, out_b, out_c, out_d;
  am2617 dut (
      .in_a_i, .out_a_o(out_a),
      .in_b_i, .out_b_o(out_b),
      .in_c_i, .out_c_o(out_c),
      .in_d_i, .out_d_o(out_d));

  always_comb begin
    assert (out_a == !in_a_i);
    assert (out_b == !in_b_i);
    assert (out_c == !in_c_i);
    assert (out_d == !in_d_i);
  end

  always_ff @($global_clock) begin
    cover (in_a_i && !out_a);
    cover (!in_a_i && out_a);
    cover (in_b_i && !out_b);
    cover (!in_b_i && out_b);
    cover (in_c_i && !out_c);
    cover (!in_c_i && out_c);
    cover (in_d_i && !out_d);
    cover (!in_d_i && out_d);
    cover (in_a_i && in_b_i && in_c_i && in_d_i);
    cover (!in_a_i && !in_b_i && !in_c_i && !in_d_i);
    cover (in_a_i && !in_b_i && in_c_i && !in_d_i);
  end
endmodule
`endif
