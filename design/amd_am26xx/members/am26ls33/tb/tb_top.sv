`timescale 1ns/1ps
// Self-checking testbench for the Am26LS33 reconstruction: exhaustive
// check of all 2^10 = 1024 input combinations (four differential pairs,
// two enables) against the per-receiver contract, distinguishing the
// exact `z` high-impedance state.
module tb_top;
  logic a_in_n_i = 1'b0, a_in_p_i = 1'b0;
  logic b_in_n_i = 1'b0, b_in_p_i = 1'b0;
  logic c_in_n_i = 1'b0, c_in_p_i = 1'b0;
  logic d_in_n_i = 1'b0, d_in_p_i = 1'b0;
  logic en_n_i = 1'b0, en2_i = 1'b0;
  logic a_out_o, b_out_o, c_out_o, d_out_o;

  am26ls33 dut (
      .a_in_n_i, .a_in_p_i, .a_out_o,
      .b_in_n_i, .b_in_p_i, .b_out_o,
      .c_in_n_i, .c_in_p_i, .c_out_o,
      .d_in_n_i, .d_in_p_i, .d_out_o,
      .en_n_i, .en2_i);

  integer errors = 0;
  integer checks = 0;
  integer an, ap, bn, bp, cn, cp, dn, dp, en, e2;
  logic enabled, exp_a, exp_b, exp_c, exp_d;

  initial begin
    for (an = 0; an < 2; an++)
      for (ap = 0; ap < 2; ap++)
        for (bn = 0; bn < 2; bn++)
          for (bp = 0; bp < 2; bp++)
            for (cn = 0; cn < 2; cn++)
              for (cp = 0; cp < 2; cp++)
                for (dn = 0; dn < 2; dn++)
                  for (dp = 0; dp < 2; dp++)
                    for (en = 0; en < 2; en++)
                      for (e2 = 0; e2 < 2; e2++) begin
                        a_in_n_i = an[0]; a_in_p_i = ap[0];
                        b_in_n_i = bn[0]; b_in_p_i = bp[0];
                        c_in_n_i = cn[0]; c_in_p_i = cp[0];
                        d_in_n_i = dn[0]; d_in_p_i = dp[0];
                        en_n_i = en[0];   en2_i = e2[0];
                        #1;
                        enabled = !en_n_i || en2_i;
                        if (enabled) begin
                          exp_a = (a_in_p_i >= a_in_n_i);
                          exp_b = (b_in_p_i >= b_in_n_i);
                          exp_c = (c_in_p_i >= c_in_n_i);
                          exp_d = (d_in_p_i >= d_in_n_i);
                          if (a_out_o !== exp_a || b_out_o !== exp_b
                              || c_out_o !== exp_c || d_out_o !== exp_d) begin
                            $display("FAIL enabled: en=%b%b out=%b%b%b%b exp=%b%b%b%b",
                                     en, e2, a_out_o, b_out_o, c_out_o,
                                     d_out_o, exp_a, exp_b, exp_c, exp_d);
                            errors++;
                          end
                        end else begin
                          if (a_out_o !== 1'bz || b_out_o !== 1'bz
                              || c_out_o !== 1'bz || d_out_o !== 1'bz) begin
                            $display("FAIL disabled: en=%b%b out=%b%b%b%b exp=zzzz",
                                     en, e2, a_out_o, b_out_o, c_out_o, d_out_o);
                            errors++;
                          end
                        end
                        checks++;
                      end

    if (errors == 0) begin
      $display("am26ls33 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am26ls33 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26ls33 testbench failed");
    end
    $finish;
  end
endmodule
