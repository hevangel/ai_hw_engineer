`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26LS31 reconstruction: per-driver contract
// with complementary outputs, enable semantics, and covers for every
// state class.
module am26ls31_props (
    input logic in_a_i, in_b_i, in_c_i, in_d_i,
    input logic en_n_i, en2_i
);
  logic y_a, z_a, y_b, z_b, y_c, z_c, y_d, z_d;
  am26ls31 dut (
      .in_a_i, .y_a_o(y_a), .z_a_o(z_a),
      .en_n_i,
      .y_b_o(y_b), .z_b_o(z_b), .in_b_i,
      .in_c_i, .y_c_o(y_c), .z_c_o(z_c),
      .en2_i,
      .z_d_o(z_d), .y_d_o(y_d), .in_d_i);

  logic enabled;
  assign enabled = !en_n_i || en2_i;

  always_comb begin
    if (!enabled) begin
      assert (y_a === 1'bz && z_a === 1'bz && y_b === 1'bz && z_b === 1'bz
              && y_c === 1'bz && z_c === 1'bz && y_d === 1'bz && z_d === 1'bz);
    end else begin
      assert (y_a === in_a_i  && z_a === !in_a_i);
      assert (y_b === in_b_i  && z_b === !in_b_i);
      assert (y_c === in_c_i  && z_c === !in_c_i);
      assert (y_d === in_d_i  && z_d === !in_d_i);
    end
  end

  always_ff @($global_clock) begin
    // Enable-pair corners.
    cover (enabled && !en_n_i && !en2_i);
    cover (enabled && en_n_i && en2_i);
    cover (!enabled && en_n_i && !en2_i);
    // Driven differential pairs: data 0 (Y low, Z high) and data 1.
    cover (enabled && !in_a_i && y_a === 1'b0 && z_a === 1'b1);
    cover (enabled && in_a_i && y_a === 1'b1 && z_a === 1'b0);
    cover (enabled && !in_b_i && y_b === 1'b0 && z_b === 1'b1);
    cover (enabled && in_c_i && y_c === 1'b1 && z_c === 1'b0);
    cover (enabled && !in_d_i && y_d === 1'b0 && z_d === 1'b1);
    // Disabled state.
    cover (!enabled && y_a === 1'bz && z_a === 1'bz);
    // Mixed data pattern across drivers.
    cover (enabled && in_a_i && !in_b_i && in_c_i && !in_d_i);
  end
endmodule
`endif
