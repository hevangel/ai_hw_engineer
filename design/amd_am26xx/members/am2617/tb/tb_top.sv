`timescale 1ns/1ps
// Self-checking testbench for the Am2617 reconstruction: exhaustive
// check of all 16 input combinations against the inversion contract.
module tb_top;
  logic in_a_i = 1'b0, in_b_i = 1'b0, in_c_i = 1'b0, in_d_i = 1'b0;
  logic out_a_o, out_b_o, out_c_o, out_d_o;

  am2617 dut (
      .in_a_i, .out_a_o, .in_b_i, .out_b_o,
      .in_c_i, .out_c_o, .in_d_i, .out_d_o);

  integer errors = 0;
  integer checks = 0;
  integer a, b, c, d;
  logic [3:0] exp;

  initial begin
    for (a = 0; a < 2; a++)
      for (b = 0; b < 2; b++)
        for (c = 0; c < 2; c++)
          for (d = 0; d < 2; d++) begin
            in_a_i = a[0]; in_b_i = b[0]; in_c_i = c[0]; in_d_i = d[0];
            #1;
            exp[3] = !in_a_i;
            exp[2] = !in_b_i;
            exp[1] = !in_c_i;
            exp[0] = !in_d_i;
            if ({out_a_o, out_b_o, out_c_o, out_d_o} !== exp) begin
              $display("FAIL: in=%b out=%b exp=%b",
                       {in_a_i, in_b_i, in_c_i, in_d_i},
                       {out_a_o, out_b_o, out_c_o, out_d_o}, exp);
              errors++;
            end
            checks++;
          end

    if (errors == 0) begin
      $display("am2617 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am2617 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am2617 testbench failed");
    end
    $finish;
  end
endmodule
