`timescale 1ns/1ps
// Self-checking testbench for the Am26LS30 reconstruction: exhaustive
// check of all 2^6 = 64 input combinations (four data inputs, mode)
// with slew-pin toggling, against the published function tables for
// both modes.
module tb_top;
  logic in_a_i = 1'b0, in_b_i = 1'b0, in_c_i = 1'b0, in_d_i = 1'b0;
  logic mode_i = 1'b0;
  logic sr_a_i = 1'b0, sr_b_i = 1'b0, sr_c_i = 1'b0, sr_d_i = 1'b0;
  logic out_a_o, out_b_o, out_c_o, out_d_o;

  am26ls30 dut (
      .in_a_i, .in_b_i, .mode_i, .in_c_i, .in_d_i,
      .out_a_o, .out_b_o, .out_c_o, .out_d_o,
      .sr_a_i, .sr_b_i, .sr_c_i, .sr_d_i);

  integer errors = 0;
  integer checks = 0;
  integer a, b, c, d, m, s;
  logic e;

  initial begin
    for (a = 0; a < 2; a++)
      for (b = 0; b < 2; b++)
        for (c = 0; c < 2; c++)
          for (d = 0; d < 2; d++)
            for (m = 0; m < 2; m++)
              for (s = 0; s < 2; s++) begin
                in_a_i = a[0]; in_b_i = b[0]; in_c_i = c[0]; in_d_i = d[0];
                mode_i = m[0];
                {sr_a_i, sr_b_i, sr_c_i, sr_d_i} = 4'(s);
                #1;
                e = 0;
                if (mode_i) begin
                  if (out_a_o !== in_a_i) e = 1;
                  if (out_b_o !== in_b_i) e = 1;
                  if (out_c_o !== in_c_i) e = 1;
                  if (out_d_o !== in_d_i) e = 1;
                end else begin
                  if (!in_b_i) begin
                    if (out_a_o !== in_a_i) e = 1;
                    if (out_b_o !== !in_a_i) e = 1;
                  end else begin
                    // Inline comparisons: Verilator resolves tristate z
                    // through task-argument copies, so the z checks must
                    // stay in the evaluation context.
                    if (out_a_o !== 1'bz) e = 1;
                    if (out_b_o !== 1'bz) e = 1;
                  end
                  if (!in_c_i) begin
                    if (out_c_o !== in_d_i) e = 1;
                    if (out_d_o !== !in_d_i) e = 1;
                  end else begin
                    if (out_c_o !== 1'bz) e = 1;
                    if (out_d_o !== 1'bz) e = 1;
                  end
                end
                if (e) begin
                  $display("FAIL: a=%b b=%b c=%b d=%b mode=%b out=%b%b%b%b",
                           a, b, c, d, m, out_a_o, out_b_o, out_c_o, out_d_o);
                  errors++;
                end
                checks++;
              end

    if (errors == 0) begin
      $display("am26ls30 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am26ls30 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26ls30 testbench failed");
    end
    $finish;
  end
endmodule
