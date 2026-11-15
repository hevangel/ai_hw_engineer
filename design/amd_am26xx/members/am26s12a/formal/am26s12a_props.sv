`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26S12A reconstruction: same contract checks
// as the am26s12 harness, instantiated at REVISION 1 (the S12A
// hysteresis grade) per the parent issue's rule that documented base
// and A revisions of one part share a source file and verify each
// contract separately. The digital function is grade-independent; the
// elaboration-time margin check inside the DUT pins the documented
// S12A threshold pair (VIH 2.25 V typ / VIL 1.2 V typ).
module am26s12a_props (
    input logic e1_n_i, e2_n_i,
    input logic i0_i, i1_i, i2_i, i3_i,
    input logic b0_i, b1_i, b2_i, b3_i
);
  logic b0, b1, b2, b3;
  logic z0, z1, z2, z3;
  am26s12 #(.REVISION(1)) dut (
      .e1_n_i, .e2_n_i,
      .i0_i, .b0_n_o(b0), .b0_i, .z0_n_o(z0),
      .i1_i, .b1_n_o(b1), .b1_i, .z1_n_o(z1),
      .i2_i, .b2_n_o(b2), .b2_i, .z2_n_o(z2),
      .i3_i, .b3_n_o(b3), .b3_i, .z3_n_o(z3));

  logic enabled;
  assign enabled = !e1_n_i && !e2_n_i;

  always_comb begin
    if (enabled) begin
      assert (b0 === !i0_i);
      assert (b1 === !i1_i);
      assert (b2 === !i2_i);
      assert (b3 === !i3_i);
    end else begin
      assert (b0 === 1'bz && b1 === 1'bz);
      assert (b2 === 1'bz && b3 === 1'bz);
    end
    assert (z0 === !b0_i);
    assert (z1 === !b1_i);
    assert (z2 === !b2_i);
    assert (z3 === !b3_i);
  end

  always_ff @($global_clock) begin
    cover (!e1_n_i && !e2_n_i && i0_i && b0 === 1'b0 && z0 === 1'b1);
    cover (!e1_n_i && !e2_n_i && !i0_i && b0 === 1'b1 && z0 === 1'b0);
    cover ((!e1_n_i || !e2_n_i) && !( !e1_n_i && !e2_n_i)
           && b0 === 1'bz && z0 === 1'b1);
    cover (!e1_n_i && !e2_n_i && i1_i && b1 === 1'b0 && z1 === 1'b1);
    cover (e2_n_i && b2 === 1'bz && z2 === 1'b0);
    cover (!e1_n_i && !e2_n_i && i3_i && b3 === 1'b0 && z3 === 1'b1);
    cover (e1_n_i && !e2_n_i && b0 === 1'bz);
    cover (!e1_n_i && e2_n_i && b0 === 1'bz);
    cover (b0 === 1'bz && b1 === 1'bz && b2 === 1'bz && b3 === 1'bz);
    cover (!e1_n_i && !e2_n_i && i0_i && i1_i && i2_i && i3_i
           && b0 === 1'b0 && b1 === 1'b0 && b2 === 1'b0 && b3 === 1'b0);
  end
endmodule
`endif
