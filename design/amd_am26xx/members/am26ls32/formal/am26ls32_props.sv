`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26LS32 reconstruction: per-receiver contract,
// enable semantics, fail-safe ties, and covers for every state class.
module am26ls32_props (
    input logic a_in_n_i, a_in_p_i,
    input logic b_in_n_i, b_in_p_i,
    input logic c_in_n_i, c_in_p_i,
    input logic d_in_n_i, d_in_p_i,
    input logic en_n_i, en2_i
);
  logic a_out, b_out, c_out, d_out;
  am26ls32 dut (
      .a_in_n_i, .a_in_p_i, .a_out_o(a_out),
      .b_in_n_i, .b_in_p_i, .b_out_o(b_out),
      .c_in_n_i, .c_in_p_i, .c_out_o(c_out),
      .d_in_n_i, .d_in_p_i, .d_out_o(d_out),
      .en_n_i, .en2_i);

  logic enabled;
  assign enabled = !en_n_i || en2_i;

  always_comb begin
    // Enable semantics (formulated independently of the RTL).
    if (!enabled) begin
      assert (a_out === 1'bz && b_out === 1'bz
              && c_out === 1'bz && d_out === 1'bz);
    end else begin
      assert (a_out === (a_in_p_i >= a_in_n_i));
      assert (b_out === (b_in_p_i >= b_in_n_i));
      assert (c_out === (c_in_p_i >= c_in_n_i));
      assert (d_out === (d_in_p_i >= d_in_n_i));
    end
    // Fail-safe: open-line ties drive the outputs HIGH when enabled.
    if (enabled && !a_in_p_i && !a_in_n_i) assert (a_out === 1'b1);
    if (enabled && !b_in_p_i && !b_in_n_i) assert (b_out === 1'b1);
    if (enabled && !c_in_p_i && !c_in_n_i) assert (c_out === 1'b1);
    if (enabled && !d_in_p_i && !d_in_n_i) assert (d_out === 1'b1);
  end

  always_ff @($global_clock) begin
    // Covers: enable pair corners.
    cover (enabled && !en_n_i && !en2_i);
    cover (enabled && en_n_i && en2_i);
    cover (!enabled && en_n_i && !en2_i);
    // Differential states per receiver (A shown enabled).
    cover (enabled && a_in_p_i && !a_in_n_i && a_out === 1'b1);
    cover (enabled && !a_in_p_i && a_in_n_i && a_out === 1'b0);
    cover (enabled && b_in_p_i && !b_in_n_i && b_out === 1'b1);
    cover (enabled && !b_in_p_i && b_in_n_i && b_out === 1'b0);
    cover (enabled && c_in_p_i && !c_in_n_i && c_out === 1'b1);
    cover (enabled && d_in_p_i && !d_in_n_i && d_out === 1'b1);
    // Fail-safe ties, enabled and disabled.
    cover (enabled && !a_in_p_i && !a_in_n_i && a_out === 1'b1);
    cover (!enabled && !c_in_p_i && !c_in_n_i && c_out === 1'bz);
    // Mixed differential pattern across receivers.
    cover (enabled && a_in_p_i && !a_in_n_i && b_in_n_i && !b_in_p_i
           && c_in_p_i && !c_in_n_i && d_in_n_i && !d_in_p_i);
  end
endmodule
`endif
