`timescale 1ns/1ps
`ifdef FORMAL
// Formal harness for the Am26LS30 reconstruction: checks both published
// function tables (RS-422 mode and RS-423 mode) row-by-row, plus
// covers for every documented behavior.
module am26ls30_props (
    input logic in_a_i, in_b_i, in_c_i, in_d_i,
    input logic mode_i,
    input logic sr_a_i, sr_b_i, sr_c_i, sr_d_i
);
  logic out_a, out_b, out_c, out_d;
  am26ls30 dut (
      .in_a_i, .in_b_i, .mode_i, .in_c_i, .in_d_i,
      .out_a_o(out_a), .out_b_o(out_b), .out_c_o(out_c), .out_d_o(out_d),
      .sr_a_i, .sr_b_i, .sr_c_i, .sr_d_i);

  always_comb begin
    if (mode_i) begin
      // RS-423 quad single-ended: all four outputs follow their inputs.
      assert (out_a === in_a_i);
      assert (out_b === in_b_i);
      assert (out_c === in_c_i);
      assert (out_d === in_d_i);
    end else begin
      // RS-422 dual differential: complementary pairs, active-low
      // enables on B/C.
      if (!in_b_i) begin
        assert (out_a === in_a_i);
        assert (out_b === !in_a_i);
      end else begin
        assert (out_a === 1'bz && out_b === 1'bz);
      end
      if (!in_c_i) begin
        assert (out_c === in_d_i);
        assert (out_d === !in_d_i);
      end else begin
        assert (out_c === 1'bz && out_d === 1'bz);
      end
    end
  end

  always_ff @($global_clock) begin
    // RS-422 function-table rows (A/B pair).
    cover (!mode_i && !in_a_i && !in_b_i && out_a === 1'b0 && out_b === 1'b1);
    cover (!mode_i && !in_a_i && in_b_i && out_a === 1'bz);
    cover (!mode_i && in_a_i && !in_b_i && out_a === 1'b1 && out_b === 1'b0);
    cover (!mode_i && in_a_i && in_b_i && out_b === 1'bz);
    // RS-422 rows (C/D pair).
    cover (!mode_i && in_d_i && !in_c_i && out_c === 1'b1 && out_d === 1'b0);
    cover (!mode_i && in_d_i && in_c_i && out_d === 1'bz);
    // RS-423 rows.
    cover (mode_i && !in_a_i && !in_b_i && out_a === 1'b0 && out_b === 1'b0);
    cover (mode_i && in_a_i && in_b_i && in_c_i && in_d_i
           && out_a === 1'b1 && out_d === 1'b1);
    cover (mode_i && !in_b_i && in_b_i === 1'b0 && out_b === 1'b0);
    // Slew-pin independence in both modes.
    cover (mode_i && in_a_i && sr_a_i && !sr_d_i);
    cover (!mode_i && in_a_i && !sr_a_i && sr_d_i);
  end
endmodule
`endif
