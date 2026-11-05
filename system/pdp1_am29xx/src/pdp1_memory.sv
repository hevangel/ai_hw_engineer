`timescale 1ns/1ps
// 4096 x 18 core-memory model.
//
// The original core is a destructive-read, 5 us cycle machine. This model has
// a combinational read port and a single-cycle write, and the visible timing
// (one core cycle per access) is counted separately in the top module. See
// spec.md A10: no electrical or destructive-read behavior is claimed.
`ifndef PDP1_MEMORY_SV
`define PDP1_MEMORY_SV

module pdp1_memory (
    input  logic        clk_i,
    input  logic [11:0] cpu_addr_i,
    input  logic [17:0] cpu_wdata_i,
    input  logic        cpu_we_i,
    output logic [17:0] cpu_rdata_o,
    input  logic [11:0] host_addr_i,
    input  logic [17:0] host_wdata_i,
    input  logic        host_we_i,
    output logic [17:0] host_rdata_o
);
  // ASSUMPTION: power-up core contents are undefined in hardware; this model
  // starts at +0 so that a cold machine is deterministic.
  logic [17:0] mem[0:4095];

  assign cpu_rdata_o = mem[cpu_addr_i];
  assign host_rdata_o = mem[host_addr_i];

  always_ff @(posedge clk_i) begin
    if (cpu_we_i) mem[cpu_addr_i] <= cpu_wdata_i;
    if (host_we_i) mem[host_addr_i] <= host_wdata_i;
  end
endmodule

`endif
