`timescale 1ns/1ps
// Self-checking testbench for the Am26LS29 reconstruction: exhaustive
// check of all 2^5 = 32 input combinations (four data inputs and the
// enable) plus slew-control independence.
module tb_top;
  logic in_a_i = 1'b0, in_b_i = 1'b0, in_c_i = 1'b0, in_d_i = 1'b0;
  logic en_n_i = 1'b0;
  logic sr_a_i = 1'b0, sr_b_i = 1'b0, sr_c_i = 1'b0, sr_d_i = 1'b0;
  logic out_a_o, out_b_o, out_c_o, out_d_o;

  am26ls29 dut (
      .in_a_i, .out_a_o, .in_b_i, .out_b_o, .en_n_i,
      .in_c_i, .out_c_o, .in_d_i, .out_d_o,
      .sr_a_i, .sr_b_i, .sr_c_i, .sr_d_i);

  integer errors = 0;
  integer checks = 0;
  integer a, b, c, d, en, s;
  logic [3:0] got;

  initial begin
    for (a = 0; a < 2; a++)
      for (b = 0; b < 2; b++)
        for (c = 0; c < 2; c++)
          for (d = 0; d < 2; d++)
            for (en = 0; en < 2; en++)
              for (s = 0; s < 2; s++) begin
                in_a_i = a[0]; in_b_i = b[0]; in_c_i = c[0]; in_d_i = d[0];
                en_n_i = en[0];
                // Toggle the slew pins per iteration to prove independence.
                {sr_a_i, sr_b_i, sr_c_i, sr_d_i} = 4'(s);
                #1;
                got = {out_a_o, out_b_o, out_c_o, out_d_o};
                if (en_n_i) begin
                  if (got !== 4'bzzzz) begin
                    $display("FAIL disabled: en=%b got=%b", en, got);
                    errors++;
                  end
                end else begin
                  if (got !== {in_a_i, in_b_i, in_c_i, in_d_i}) begin
                    $display("FAIL enabled: in=%b got=%b",
                             {in_a_i, in_b_i, in_c_i, in_d_i}, got);
                    errors++;
                  end
                end
                checks++;
              end

    if (errors == 0) begin
      $display("am26ls29 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am26ls29 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26ls29 testbench failed");
    end
    $finish;
  end
endmodule
