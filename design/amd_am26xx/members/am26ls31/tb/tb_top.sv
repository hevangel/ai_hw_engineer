`timescale 1ns/1ps
// Self-checking testbench for the Am26LS31 reconstruction: exhaustive
// check of all 2^6 = 64 input combinations (four data inputs, two
// enables) against the complementary-output contract, distinguishing
// the exact `z` state.
module tb_top;
  logic in_a_i = 1'b0, in_b_i = 1'b0, in_c_i = 1'b0, in_d_i = 1'b0;
  logic en_n_i = 1'b0, en2_i = 1'b0;
  logic y_a_o, z_a_o, y_b_o, z_b_o, y_c_o, z_c_o, y_d_o, z_d_o;

  am26ls31 dut (
      .in_a_i, .y_a_o, .z_a_o, .en_n_i,
      .y_b_o, .z_b_o, .in_b_i,
      .in_c_i, .y_c_o, .z_c_o, .en2_i,
      .z_d_o, .y_d_o, .in_d_i);

  integer errors = 0;
  integer checks = 0;
  integer a, b, c, d, en, e2;
  logic enabled, e;
  logic [7:0] got, exp;

  initial begin
    for (a = 0; a < 2; a++)
      for (b = 0; b < 2; b++)
        for (c = 0; c < 2; c++)
          for (d = 0; d < 2; d++)
            for (en = 0; en < 2; en++)
              for (e2 = 0; e2 < 2; e2++) begin
                in_a_i = a[0]; in_b_i = b[0]; in_c_i = c[0]; in_d_i = d[0];
                en_n_i = en[0]; en2_i = e2[0];
                #1;
                enabled = !en_n_i || en2_i;
                got = {y_a_o, z_a_o, y_b_o, z_b_o, y_c_o, z_c_o, y_d_o, z_d_o};
                if (enabled) begin
                  exp = {in_a_i, !in_a_i, in_b_i, !in_b_i,
                         in_c_i, !in_c_i, in_d_i, !in_d_i};
                end else begin
                  exp = 8'hFF;
                end
                // Compare bit by bit to handle z correctly.
                e = 0;
                for (int k = 0; k < 8; k++) begin
                  if (enabled) begin
                    if (got[k] !== exp[k]) e = 1;
                  end else begin
                    if (got[k] !== 1'bz) e = 1;
                  end
                end
                if (e) begin
                  $display("FAIL: a=%b b=%b c=%b d=%b en=%b%b got=%b exp=%b",
                           a, b, c, d, en, e2, got, exp);
                  errors++;
                end
                checks++;
              end

    if (errors == 0) begin
      $display("am26ls31 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am26ls31 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26ls31 testbench failed");
    end
    $finish;
  end
endmodule
