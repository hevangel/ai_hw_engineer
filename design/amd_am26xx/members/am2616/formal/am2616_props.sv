`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2616 reconstruction: per-driver contract,
// inhibit-forces-mark property, and covers for every state class.
module am2616_props (
    input logic in_a1_i, in_a2_i, inhibit_a_i,
    input logic in_b_i, inhibit_b_i,
    input logic in_c_i, inhibit_c_i,
    input logic in_d_i, inhibit_d_i
);
  logic out_a, out_b, out_c, out_d;
  am2616 dut (
      .in_a1_i, .in_a2_i, .inhibit_a_i, .out_a_o(out_a),
      .in_b_i, .inhibit_b_i, .out_b_o(out_b),
      .in_c_i, .inhibit_c_i, .out_c_o(out_c),
      .in_d_i, .inhibit_d_i, .out_d_o(out_d));

  always_comb begin
    // Per-driver contract, formulated independently of the RTL.
    assert (out_a == !((in_a1_i && in_a2_i) || inhibit_a_i));
    assert (out_b == !(in_b_i || inhibit_b_i));
    assert (out_c == !(in_c_i || inhibit_c_i));
    assert (out_d == !(in_d_i || inhibit_d_i));
    // A HIGH inhibit forces the output to mark (LOW).
    assert (!inhibit_a_i || !out_a);
    assert (!inhibit_b_i || !out_b);
    assert (!inhibit_c_i || !out_c);
    assert (!inhibit_d_i || !out_d);
    // With the inhibit low, driver A is a 2-input NAND, B/C/D inverters.
    assert (inhibit_a_i || out_a == !(in_a1_i && in_a2_i));
    assert (inhibit_b_i || out_b == !in_b_i);
    assert (inhibit_c_i || out_c == !in_c_i);
    assert (inhibit_d_i || out_d == !in_d_i);
  end

  always_ff @($global_clock) begin
    // Covers: inhibited (mark) and active-high/low data states per driver.
    cover (inhibit_a_i && !out_a);
    cover (!inhibit_a_i && in_a1_i && in_a2_i && !out_a);
    cover (!inhibit_a_i && !in_a1_i && out_a);
    cover (inhibit_b_i && !out_b);
    cover (!inhibit_b_i && in_b_i && !out_b);
    cover (!inhibit_b_i && !in_b_i && out_b);
    cover (inhibit_c_i && !out_c);
    cover (!inhibit_c_i && !in_c_i && out_c);
    cover (inhibit_d_i && !out_d);
    cover (!inhibit_d_i && in_d_i && !out_d);
    // Mixed: A inhibited while D transmits.
    cover (inhibit_a_i && !inhibit_d_i && out_d);
    // All four inhibited simultaneously (mark on every line).
    cover (inhibit_a_i && inhibit_b_i && inhibit_c_i && inhibit_d_i
           && !out_a && !out_b && !out_c && !out_d);
  end
endmodule
`endif
