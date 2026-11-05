// Synthesis-only stub for the 4096 x 18 core array.
//
// The real memory is a 73,728-bit array that dominates area and is not the
// subject of this synthesis check (spec.md A10 and the report). This stub
// keeps the port signature so the sequencer, datapath and I/O glue can be
// elaborated and counted; it stores one word and is never used in simulation.
`timescale 1ns/1ps
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
  logic [17:0] word_q;
  always_ff @(posedge clk_i) begin
    if (cpu_we_i) word_q <= cpu_wdata_i;
  end
  assign cpu_rdata_o = word_q;
  assign host_rdata_o = word_q;
endmodule
