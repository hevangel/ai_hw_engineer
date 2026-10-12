`ifdef FORMAL
// Reachability harness only; the safety proof instantiates the core directly.
module intel_8086_cover (
    input logic clk
);
  logic rst_n = 0;
  (* anyconst *) logic fault_path, irq_path, hold_path;
  logic [ 2:0] cycles = 0;
  logic [19:0] address;
  always_ff @(posedge clk) if (cycles != 7) cycles <= cycles + 1;
  always_ff @(posedge clk) rst_n <= 1;
  // PUSH AX; STI; HLT (or undefined 60h). Optional IRQ and finite HOLD
  // paths independently witness the new control outputs.
  intel_8086 dut (
      .clk(clk),
      .rst_n(rst_n),
      .bus_ready_i(1'b1),
      .bus_rdata_i(address==20'hffff0 ? (irq_path ? 16'h90fb :
          {fault_path ? 8'h60:8'hf4,8'h50}) : 16'hf4f4),
      .bus_addr_o(address),
      .intr_i(irq_path),
      .nmi_i(1'b0),
      .hold_i(hold_path && cycles < 3),
      .test_n_i(1'b0)
  );
endmodule
`endif
