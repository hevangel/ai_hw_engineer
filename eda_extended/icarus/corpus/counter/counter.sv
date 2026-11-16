// A clocked counter with an independent expected trace.
//
// The expected output is derived by hand from the schedule: the clock period is
// 10 ns, reset is asserted for the first two rising edges, and the counter is
// printed after every rising edge from then on.  Nothing here models the RTL.
`timescale 1ns/1ps
module counter;
  reg       clk = 1'b0;
  reg       rst = 1'b1;
  wire [3:0] q;

  ghdl_counter dut (.clk(clk), .rst(rst), .q(q));

  always #5 clk = ~clk;

  integer n;
  initial begin
    // Two rising edges with reset asserted (t = 5 ns and 15 ns).
    @(posedge clk);
    @(posedge clk);
    rst = 1'b0;

    for (n = 1; n <= 6; n = n + 1) begin
      @(posedge clk);
      #1;  // sample after the clock edge so the counter update is visible
      $display("q=%0d", q);
    end

    $display("counter done");
    $finish;
  end
endmodule

module ghdl_counter (
  input  logic clk,
  input  logic rst,
  output logic [3:0] q
);
  always_ff @(posedge clk) begin
    if (rst) q <= 4'd0;
    else     q <= q + 4'd1;
  end
endmodule