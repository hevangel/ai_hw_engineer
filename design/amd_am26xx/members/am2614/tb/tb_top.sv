`timescale 1ns/1ps
// Self-checking testbench for the Am2614 reconstruction.
//
// 1. Exhaustive check of all 2^10 = 1024 input combinations against the
//    3-input NAND contract per driver.
// 2. Pair-independence check: toggling pair A inputs cannot affect pair
//    B outputs.
module tb_top;
  logic strobe_a_i = 1'b0;
  logic in_a1a_i = 1'b0, in_a1b_i = 1'b0;
  logic in_a2a_i = 1'b0, in_a2b_i = 1'b0;
  logic strobe_b_i = 1'b0;
  logic in_b1a_i = 1'b0, in_b1b_i = 1'b0;
  logic in_b2a_i = 1'b0, in_b2b_i = 1'b0;
  logic out_a1_o, out_a2_o, out_b1_o, out_b2_o;

  am2614 dut (
      .strobe_a_i, .in_a1a_i, .in_a1b_i, .out_a1_o,
      .in_a2a_i, .in_a2b_i, .out_a2_o,
      .strobe_b_i, .in_b1a_i, .in_b1b_i, .out_b1_o,
      .in_b2a_i, .in_b2b_i, .out_b2_o);

  integer errors = 0;
  integer checks = 0;
  integer sa, a1a, a1b, a2a, a2b, sb, b1a, b1b, b2a, b2b;
  logic [3:0] exp;

  initial begin
    for (sa = 0; sa < 2; sa++)
      for (a1a = 0; a1a < 2; a1a++)
        for (a1b = 0; a1b < 2; a1b++)
          for (a2a = 0; a2a < 2; a2a++)
            for (a2b = 0; a2b < 2; a2b++)
              for (sb = 0; sb < 2; sb++)
                for (b1a = 0; b1a < 2; b1a++)
                  for (b1b = 0; b1b < 2; b1b++)
                    for (b2a = 0; b2a < 2; b2a++)
                      for (b2b = 0; b2b < 2; b2b++) begin
                        strobe_a_i = sa[0];
                        in_a1a_i = a1a[0]; in_a1b_i = a1b[0];
                        in_a2a_i = a2a[0]; in_a2b_i = a2b[0];
                        strobe_b_i = sb[0];
                        in_b1a_i = b1a[0]; in_b1b_i = b1b[0];
                        in_b2a_i = b2a[0]; in_b2b_i = b2b[0];
                        #1;
                        exp[0] = !(in_a1a_i && in_a1b_i && strobe_a_i);
                        exp[1] = !(in_a2a_i && in_a2b_i && strobe_a_i);
                        exp[2] = !(in_b1a_i && in_b1b_i && strobe_b_i);
                        exp[3] = !(in_b2a_i && in_b2b_i && strobe_b_i);
                        if ({out_b2_o, out_b1_o, out_a2_o, out_a1_o} !== exp) begin
                          $display("FAIL: sa=%b a1=%b%b a2=%b%b sb=%b b1=%b%b b2=%b%b out=%b exp=%b",
                                   sa, a1a, a1b, a2a, a2b, sb, b1a, b1b,
                                   b2a, b2b,
                                   {out_a1_o, out_a2_o, out_b1_o, out_b2_o},
                                   exp);
                          errors++;
                        end
                        checks++;
                      end

    if (errors == 0) begin
      $display("am2614 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am2614 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am2614 testbench failed");
    end
    $finish;
  end
endmodule
