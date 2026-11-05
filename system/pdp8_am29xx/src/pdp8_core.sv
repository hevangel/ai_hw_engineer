// Core memory: 4096 words of 12 bits, one-cycle registered read.
//
// The read and write ports have independent addresses.  The PDP-8 defer state
// performs a read-modify-write of an auto-index word; a single-ported core
// would take two cycles for that, so this model exposes both ports and the
// microcode completes it in one cycle.  Program-visible order is unchanged
// (the read of the incremented word happens after the write).
//
// ASSUMPTION: power-up contents are undefined on real core memory; the model
// starts at zero and is loaded through the init port.
`timescale 1ns/1ps
module pdp8_core (
    input  logic        clk_i,
    input  logic [11:0] raddr_i,
    input  logic        re_i,
    input  logic [11:0] waddr_i,
    input  logic        we_i,
    input  logic [11:0] wdata_i,
    input  logic        init_we_i,
    input  logic [11:0] init_addr_i,
    input  logic [11:0] init_data_i,
    output logic [11:0] rdata_o
);
  logic [11:0] mem[0:4095];

  always_ff @(negedge clk_i) begin
    if (init_we_i) mem[init_addr_i] <= init_data_i;
    if (we_i) mem[waddr_i] <= wdata_i;
    if (re_i) rdata_o <= mem[raddr_i];
  end
endmodule
