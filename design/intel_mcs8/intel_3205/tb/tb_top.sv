`timescale 1ns/1ps
// Self-checking testbench for the Intel 3205 decoder reconstruction.
//
// 1. Exhaustive check of all 64 enable/address input combinations against
//    the truth-table semantics.
// 2. Two-level expansion network (one root decoder driving eight leaves
//    through their active-low enables), checked against a flat 6-bit
//    decode -- the datasheet's "each decoder can drive 8 other decoders"
//    cascade arrangement.
module tb_top;
  logic [2:0] a_i;
  logic e1_n_i, e2_n_i, e3_i;
  logic [7:0] out_n_o;

  intel_3205 dut (.a_i(a_i), .e1_n_i(e1_n_i), .e2_n_i(e2_n_i), .e3_i(e3_i), .out_n_o(out_n_o));

  integer errors = 0;
  integer checks = 0;

  task automatic check_exhaustive;
    logic [7:0] expected;
    logic enabled;
    for (int e = 0; e < 8; e++) begin
      {e3_i, e2_n_i, e1_n_i} = 3'(e);
      for (int addr = 0; addr < 8; addr++) begin
        a_i = 3'(addr);
        #1;
        enabled = (e1_n_i == 1'b0) && (e2_n_i == 1'b0) && (e3_i == 1'b1);
        expected = 8'hFF;
        if (enabled) expected[addr] = 1'b0;
        if (out_n_o !== expected) begin
          $display("FAIL exhaustive: enable_bits=%b a=%0d out=%b expected=%b",
                   3'(e), addr, out_n_o, expected);
          errors++;
        end
        checks++;
      end
    end
  endtask

  logic [5:0] wide_a;
  logic [7:0] root_n;
  logic [7:0] leaf_n [0:7];
  logic [63:0] wide_n;
  logic [63:0] wide_expected;

  intel_3205 root (.a_i(wide_a[5:3]), .e1_n_i(1'b0), .e2_n_i(1'b0), .e3_i(1'b1), .out_n_o(root_n));
  for (genvar k = 0; k < 8; k++) begin : leaves
    intel_3205 leaf (.a_i(wide_a[2:0]), .e1_n_i(1'b0), .e2_n_i(root_n[k]), .e3_i(1'b1),
                     .out_n_o(leaf_n[k]));
  end
  for (genvar k = 0; k < 8; k++) begin : flat
    assign wide_n[k*8 +: 8] = leaf_n[k];
  end

  task automatic check_cascade(input int rounds);
    for (int r = 0; r < rounds; r++) begin
      wide_a = 6'(r);
      #1;
      wide_expected = ~(64'h1 << wide_a);
      if (wide_n !== wide_expected) begin
        $display("FAIL cascade: wide_a=%0d out=%b expected=%b", wide_a, wide_n, wide_expected);
        errors++;
      end
      checks++;
    end
  endtask

  initial begin
    a_i = 3'd0;
    e1_n_i = 1'b1;
    e2_n_i = 1'b1;
    e3_i = 1'b0;
    wide_a = 6'd0;
    check_exhaustive();
    check_cascade(64);
    if (errors == 0) begin
      $display("intel_3205 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("intel_3205 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "intel_3205 testbench failed");
    end
    $finish;
  end
endmodule
