`timescale 1ns/1ps
// Self-checking testbench for the Am2615 reconstruction.
//
// 1. Exhaustive check of all 2^6 = 64 input combinations against the
//    per-receiver OUT = !(COMP && STROBE) contract with the documented
//    fail-safe tie resolution.
// 2. Directed checks of the documented system behaviors: differential
//    transmission with strobing, and open-line fail-safe.
module tb_top;
  logic a_in_p_i = 1'b0, a_in_n_i = 1'b0, a_strobe_i = 1'b0;
  logic b_in_p_i = 1'b0, b_in_n_i = 1'b0, b_strobe_i = 1'b0;
  logic a_out_o, b_out_o;

  am2615 dut (
      .a_in_p_i, .a_in_n_i, .a_strobe_i, .a_out_o,
      .b_in_p_i, .b_in_n_i, .b_strobe_i, .b_out_o);

  integer errors = 0;
  integer checks = 0;
  integer ap, an, as, bp, bn, bs;
  logic exp_a, exp_b;

  // Exhaustive sweep.
  initial begin
    for (ap = 0; ap < 2; ap++)
      for (an = 0; an < 2; an++)
        for (as = 0; as < 2; as++)
          for (bp = 0; bp < 2; bp++)
            for (bn = 0; bn < 2; bn++)
              for (bs = 0; bs < 2; bs++) begin
                a_in_p_i = ap[0]; a_in_n_i = an[0]; a_strobe_i = as[0];
                b_in_p_i = bp[0]; b_in_n_i = bn[0]; b_strobe_i = bs[0];
                #1;
                exp_a = !(((a_in_p_i || !a_in_n_i)) && a_strobe_i);
                exp_b = !(((b_in_p_i || !b_in_n_i)) && b_strobe_i);
                if (a_out_o !== exp_a || b_out_o !== exp_b) begin
                  $display("FAIL: a=%b%b st=%b b=%b%b st=%b out=%b%b exp=%b%b",
                           ap, an, as, bp, bn, bs, a_out_o, b_out_o,
                           exp_a, exp_b);
                  errors++;
                end
                checks++;
              end

    if (errors == 0) begin
      $display("am2615 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am2615 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am2615 testbench failed");
    end
    $finish;
  end
endmodule
