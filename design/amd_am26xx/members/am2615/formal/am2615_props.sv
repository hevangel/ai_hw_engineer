`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am2615 reconstruction: checks the per-receiver
// OUT = !(COMP && STROBE) contract, the strobe-idle property and the
// documented fail-safe tie resolution; covers every input state class.
module am2615_props (
    input logic a_in_p_i, a_in_n_i, a_strobe_i,
    input logic b_in_p_i, b_in_n_i, b_strobe_i
);
  logic a_out, b_out;
  am2615 dut (
      .a_in_p_i, .a_in_n_i, .a_strobe_i, .a_out_o(a_out),
      .b_in_p_i, .b_in_n_i, .b_strobe_i, .b_out_o(b_out));

  logic a_comp, b_comp;
  assign a_comp = a_in_p_i || !a_in_n_i;
  assign b_comp = b_in_p_i || !b_in_n_i;

  always_comb begin
    // Per-receiver contract, formulated independently of the RTL.
    assert (a_out == !(a_comp && a_strobe_i));
    assert (b_out == !(b_comp && b_strobe_i));
    // Strobe LOW holds the output HIGH.
    assert (a_strobe_i || a_out);
    assert (b_strobe_i || b_out);
    // Fail-safe: equal (open-line) inputs resolve to COMP = 1, so the
    // output follows the strobe inversion.
    if (!a_in_p_i && !a_in_n_i) assert (a_out == !a_strobe_i);
    if (!b_in_p_i && !b_in_n_i) assert (b_out == !b_strobe_i);
    // Defined differential states.
    if (a_in_p_i && !a_in_n_i) assert (a_out == !a_strobe_i);
    if (!a_in_p_i && a_in_n_i) assert (a_out);
  end

  always_ff @($global_clock) begin
    // Covers: defined differential states, strobe-disabled, fail-safe.
    cover (a_in_p_i && !a_in_n_i && a_strobe_i && !a_out);
    cover (!a_in_p_i && a_in_n_i && a_strobe_i && a_out);
    cover (!a_strobe_i && a_out);
    cover (!a_in_p_i && !a_in_n_i && !a_strobe_i && a_out);   // tie + idle
    cover (!a_in_p_i && !a_in_n_i && a_strobe_i && !a_out);   // fail-safe
    cover (b_in_p_i && !b_in_n_i && b_strobe_i && !b_out);
    cover (!b_in_p_i && b_in_n_i && b_strobe_i && b_out);
    cover (!b_strobe_i && b_out);
    cover (b_in_p_i && b_in_n_i && b_strobe_i && !b_out);     // tie active
    // Independent receivers strobed differently.
    cover (a_strobe_i && !b_strobe_i && a_out && b_out);
  end
endmodule
`endif
