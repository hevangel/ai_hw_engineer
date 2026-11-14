`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26S12 reconstruction (REVISION selected by
// chparam in the sby script; the S12A member uses the same source and
// harness structure with its own parameterization). Driver contract
// with the dual-enable AND, release, always-active receiver; same
// scoping as the am26s10 formal plan.
module am26s12_props (
    input logic e1_n_i, e2_n_i,
    input logic i0_i, i1_i, i2_i, i3_i,
    input logic b0_i, b1_i, b2_i, b3_i
);
  logic b0, b1, b2, b3;
  logic z0, z1, z2, z3;
  am26s12 #(.REVISION(0)) dut (
      .e1_n_i, .e2_n_i,
      .i0_i, .b0_n_o(b0), .b0_i, .z0_n_o(z0),
      .i1_i, .b1_n_o(b1), .b1_i, .z1_n_o(z1),
      .i2_i, .b2_n_o(b2), .b2_i, .z2_n_o(z2),
      .i3_i, .b3_n_o(b3), .b3_i, .z3_n_o(z3));

  logic enabled;
  assign enabled = !e1_n_i && !e2_n_i;

  always_comb begin
    if (enabled) begin
      // Truth-table rows 1-2: driver asserts the inverse only when both
      // enables are low.
      assert (b0 === !i0_i);
      assert (b1 === !i1_i);
      assert (b2 === !i2_i);
      assert (b3 === !i3_i);
    end else begin
      // Either enable high releases the driver.
      assert (b0 === 1'bz && b1 === 1'bz);
      assert (b2 === 1'bz && b3 === 1'bz);
    end
    // Receiver: always active, inverting the bus net (all modes).
    assert (z0 === !b0_i);
    assert (z1 === !b1_i);
    assert (z2 === !b2_i);
    assert (z3 === !b3_i);
  end

  always_ff @($global_clock) begin
    // Truth-table rows per channel.
    cover (!e1_n_i && !e2_n_i && i0_i && b0 === 1'b0 && z0 === 1'b1);
    cover (!e1_n_i && !e2_n_i && !i0_i && b0 === 1'b1 && z0 === 1'b0);
    cover ((!e1_n_i || !e2_n_i) && !( !e1_n_i && !e2_n_i)
           && b0 === 1'bz && z0 === 1'b1);
    cover (!e1_n_i && !e2_n_i && i1_i && b1 === 1'b0 && z1 === 1'b1);
    cover (e2_n_i && b2 === 1'bz && z2 === 1'b0);
    cover (!e1_n_i && !e2_n_i && i3_i && b3 === 1'b0 && z3 === 1'b1);
    // Single-enable release per enable pin.
    cover (e1_n_i && !e2_n_i && b0 === 1'bz);
    cover (!e1_n_i && e2_n_i && b0 === 1'bz);
    // All four released simultaneously.
    cover (b0 === 1'bz && b1 === 1'bz && b2 === 1'bz && b3 === 1'bz);
    // All four driving the bus low.
    cover (!e1_n_i && !e2_n_i && i0_i && i1_i && i2_i && i3_i
           && b0 === 1'b0 && b1 === 1'b0 && b2 === 1'b0 && b3 === 1'b0);
  end
endmodule
`endif
