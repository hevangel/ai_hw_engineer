`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2614 reconstruction: exhaustively checks all
// four 3-input NAND contracts and covers every input combination class.
module am2614_props (
    input logic strobe_a_i,
    input logic in_a1a_i, in_a1b_i,
    input logic in_a2a_i, in_a2b_i,
    input logic strobe_b_i,
    input logic in_b1a_i, in_b1b_i,
    input logic in_b2a_i, in_b2b_i
);
  logic out_a1, out_a2, out_b1, out_b2;
  am2614 dut (
      .strobe_a_i, .in_a1a_i, .in_a1b_i, .out_a1_o(out_a1),
      .in_a2a_i, .in_a2b_i, .out_a2_o(out_a2),
      .strobe_b_i, .in_b1a_i, .in_b1b_i, .out_b1_o(out_b1),
      .in_b2a_i, .in_b2b_i, .out_b2_o(out_b2));

  always_comb begin
    // Per-output NAND contract, formulated independently of the RTL.
    assert (out_a1 == !(in_a1a_i && in_a1b_i && strobe_a_i));
    assert (out_a2 == !(in_a2a_i && in_a2b_i && strobe_a_i));
    assert (out_b1 == !(in_b1a_i && in_b1b_i && strobe_b_i));
    assert (out_b2 == !(in_b2a_i && in_b2b_i && strobe_b_i));
    // A low strobe idles its pair HIGH.
    assert (strobe_a_i || (out_a1 && out_a2));
    assert (strobe_b_i || (out_b1 && out_b2));
  end

  always_ff @($global_clock) begin
    // Covers: strobe-disabled and strobe-enabled low/high states per pair.
    cover (!strobe_a_i && out_a1 && out_a2);
    cover (strobe_a_i && !out_a1 && !out_a2);
    cover (strobe_a_i && out_a1 && out_a2 && !in_a1a_i && !in_a2a_i);
    cover (!strobe_b_i && out_b1 && out_b2);
    cover (strobe_b_i && !out_b1 && !out_b2);
    cover (strobe_b_i && out_b1 && out_b2 && !in_b1b_i && !in_b2b_i);
    // Mixed pairs: A disabled while B asserts.
    cover (!strobe_a_i && strobe_b_i && !out_b1);
    // Asymmetric data: one data input low while the other is high.
    cover (strobe_a_i && in_a1a_i && !in_a1b_i && out_a1);
    cover (strobe_b_i && !in_b2a_i && in_b2b_i && out_b2);
  end
endmodule
`endif
