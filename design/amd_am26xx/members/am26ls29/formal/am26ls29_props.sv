`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26LS29 reconstruction: enable semantics,
// driven contract, and covers for every state class.
module am26ls29_props (
    input logic in_a_i, in_b_i, in_c_i, in_d_i,
    input logic en_n_i,
    input logic sr_a_i, sr_b_i, sr_c_i, sr_d_i
);
  logic out_a, out_b, out_c, out_d;
  am26ls29 dut (
      .in_a_i, .out_a_o(out_a), .in_b_i, .out_b_o(out_b),
      .en_n_i, .in_c_i, .out_c_o(out_c), .in_d_i, .out_d_o(out_d),
      .sr_a_i, .sr_b_i, .sr_c_i, .sr_d_i);

  logic enabled;
  assign enabled = !en_n_i;

  always_comb begin
    if (!enabled) begin
      assert (out_a === 1'bz && out_b === 1'bz
              && out_c === 1'bz && out_d === 1'bz);
    end else begin
      assert (out_a === in_a_i);
      assert (out_b === in_b_i);
      assert (out_c === in_c_i);
      assert (out_d === in_d_i);
    end
    // Slew-rate-control pins have no boolean effect (covered by the
    // driven/undriven contract holding for arbitrary sr_* inputs).
  end

  always_ff @($global_clock) begin
    cover (!enabled && out_a === 1'bz);
    cover (enabled && in_a_i && out_a === 1'b1);
    cover (enabled && !in_a_i && out_a === 1'b0);
    cover (enabled && in_b_i && out_b === 1'b1);
    cover (enabled && !in_c_i && out_c === 1'b0);
    cover (enabled && in_d_i && out_d === 1'b1);
    cover (enabled && in_a_i && !in_b_i && in_c_i && !in_d_i);
    // Slew-control independence: identical data with both sr patterns.
    cover (enabled && in_a_i && sr_a_i && !sr_b_i);
    cover (enabled && in_a_i && !sr_a_i && sr_b_i);
  end
endmodule
`endif
