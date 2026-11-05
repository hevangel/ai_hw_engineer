// Unit test for the Am2910 adapter: taken jump, subroutine call, return,
// sequential flow.  Checks the exact sequence of executed micro-addresses.
`timescale 1ns/1ps
module tb_seq;
  logic clk = 0;
  logic [11:0] mpc;
  logic full_n;

  // Micro-assembler constants
  localparam logic [3:0] CJP = 4'h3, CJS = 4'h1, RTN = 4'ha, CONT = 4'he;
  const logic [3:0] AL = 4'h1;  // CC value that always passes

  logic [3:0] seq;
  logic [11:0] target;
  logic cc_n;

  always_comb begin
    seq = CONT; target = 12'd0; cc_n = 1'b1;
    case (mpc)
      12'd0: begin seq = CJP; target = 12'd3;  cc_n = 1'b0; end
      12'd3: begin seq = CJS; target = 12'd8;  cc_n = 1'b0; end
      12'd9: begin seq = RTN; target = 12'd0;  cc_n = 1'b0; end
      default: begin seq = CONT; end
    endcase
  end

  pdp8_sequencer dut (
      .clk_i(clk), .boot_i(1'b0), .seq_i(seq), .target_i(target),
      .cc_n_i(cc_n), .mpc_o(mpc), .full_n_o(full_n)
  );

  integer n = 0;
  integer errors = 0;
  int expected[0:9] = '{0, 3, 8, 9, 4, 5, 6, 7, 100, 101};

  always #5 clk = ~clk;

  initial begin
    // Settle the first address before sampling.
    repeat (1) @(posedge clk);
    for (n = 0; n < 8; n = n + 1) begin
      if (mpc !== expected[n]) begin
        $display("FAIL: cycle %0d executed %0d, expected %0d", n, mpc, expected[n]);
        errors = errors + 1;
      end
      @(posedge clk);
    end
    if (errors == 0) $display("PASS: sequencer jump/call/return order");
    $finish;
  end
endmodule
