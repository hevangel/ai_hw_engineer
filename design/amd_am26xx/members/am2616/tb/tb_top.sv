`timescale 1ns/1ps
// Self-checking testbench for the Am2616 reconstruction: exhaustive
// check of all 2^8 = 256 input combinations against the per-driver
// contracts.
module tb_top;
  logic in_a1_i = 1'b0, in_a2_i = 1'b0, inhibit_a_i = 1'b0;
  logic in_b_i = 1'b0, inhibit_b_i = 1'b0;
  logic in_c_i = 1'b0, inhibit_c_i = 1'b0;
  logic in_d_i = 1'b0, inhibit_d_i = 1'b0;
  logic out_a_o, out_b_o, out_c_o, out_d_o;

  am2616 dut (
      .in_a1_i, .in_a2_i, .inhibit_a_i, .out_a_o,
      .in_b_i, .inhibit_b_i, .out_b_o,
      .in_c_i, .inhibit_c_i, .out_c_o,
      .in_d_i, .inhibit_d_i, .out_d_o);

  integer errors = 0;
  integer checks = 0;
  integer a1, a2, ia, b, ib, c, ic, d, id;
  logic [3:0] exp;

  initial begin
    for (a1 = 0; a1 < 2; a1++)
      for (a2 = 0; a2 < 2; a2++)
        for (ia = 0; ia < 2; ia++)
          for (b = 0; b < 2; b++)
            for (ib = 0; ib < 2; ib++)
              for (c = 0; c < 2; c++)
                for (ic = 0; ic < 2; ic++)
                  for (d = 0; d < 2; d++)
                    for (id = 0; id < 2; id++) begin
                      in_a1_i = a1[0]; in_a2_i = a2[0]; inhibit_a_i = ia[0];
                      in_b_i = b[0];   inhibit_b_i = ib[0];
                      in_c_i = c[0];   inhibit_c_i = ic[0];
                      in_d_i = d[0];   inhibit_d_i = id[0];
                      #1;
                      exp[3] = !((in_a1_i && in_a2_i) || inhibit_a_i);
                      exp[2] = !(in_b_i || inhibit_b_i);
                      exp[1] = !(in_c_i || inhibit_c_i);
                      exp[0] = !(in_d_i || inhibit_d_i);
                      if ({out_a_o, out_b_o, out_c_o, out_d_o} !== exp) begin
                        $display("FAIL: a=%b%b/i%b b=%b/i%b c=%b/i%b d=%b/i%b out=%b exp=%b",
                                 a1, a2, ia, b, ib, c, ic, d, id,
                                 {out_a_o, out_b_o, out_c_o, out_d_o}, exp);
                        errors++;
                      end
                      checks++;
                    end

    if (errors == 0) begin
      $display("am2616 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am2616 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am2616 testbench failed");
    end
    $finish;
  end
endmodule
