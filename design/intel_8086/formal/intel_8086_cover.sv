`ifdef FORMAL
// Reachability harness only; the safety proof instantiates the core directly.
module intel_8086_cover(input logic clk);
  logic rst_n=0;
  (* anyconst *) logic fault_path;
  always_ff @(posedge clk) rst_n<=1;
  // At FFFF:0000 execute PUSH AX, then HLT or unsupported 60h at FFFF:0001.
  // A repeating ROM word permits constant propagation of unused datapath logic.
  intel_8086 dut (.clk(clk),.rst_n(rst_n),.bus_ready_i(1'b1),
      .bus_rdata_i({fault_path ? 8'h60:8'hf4,8'h50}));
endmodule
`endif
