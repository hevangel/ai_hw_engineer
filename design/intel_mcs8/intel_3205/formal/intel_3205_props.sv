`timescale 1ns/1ps
`ifdef FORMAL
module intel_3205_props (
    input logic [2:0] a_i,
    input logic e1_n_i,
    input logic e2_n_i,
    input logic e3_i
);
  logic [7:0] out_n;
  intel_3205 dut (.a_i(a_i), .e1_n_i(e1_n_i), .e2_n_i(e2_n_i), .e3_i(e3_i), .out_n_o(out_n));

  logic enabled;
  assign enabled = (e1_n_i == 1'b0) && (e2_n_i == 1'b0) && (e3_i == 1'b1);

  always_comb begin
    // Per-output truth-table check, formulated independently of the
    // shift-based RTL decode.
    for (int i = 0; i < 8; i++) begin
      assert(out_n[i] == !(enabled && (a_i == 3'(i))));
    end
    // An enabled decoder asserts exactly one output; a disabled one
    // asserts none.
    assert(!enabled || $onehot(~out_n));
    assert(enabled || (out_n == 8'hFF));
  end

  always_ff @($global_clock) begin
    for (int i = 0; i < 8; i++) begin
      cover(enabled && (a_i == 3'(i)) && (out_n[i] == 1'b0));
    end
    cover(!enabled && (out_n == 8'hFF));
  end
endmodule
`endif
