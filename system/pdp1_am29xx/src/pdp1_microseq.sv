`timescale 1ns/1ps
// Am2910 microsequencer, control store and instruction/device dispatch ROMs.
//
// Address map (spec.md 3.5):
//   0x000-0x02F reset, fetch, indirect loop, shared helpers
//   0x030-0x0FF microcode subroutines
//   0x100-0x1FF 32 opcode slots, 8 microinstructions each
//   0x200-0x2FF 64 I/O device slots, 4 microinstructions each
//   0x300-0x37F shift-subcode handlers, 8 microinstructions each
//   0x0F0       illegal-opcode handler
`ifndef PDP1_MICROSEQ_SV
`define PDP1_MICROSEQ_SV

module pdp1_microseq (
    input  logic                  clk_i,
    input  logic                  rst_n_i,
    input  pdp1_uc_pkg::pdp1_uc_t uc_i,
    input  logic                  cond_i,
    input  logic [4:0]            opcode_i,
    input  logic [5:0]            device_i,
    input  logic [3:0]            sft_i,
    output pdp1_uc_pkg::pdp1_uc_t uc_o,
    output logic [11:0]           addr_o
);

  `include "pdp1_defs.svh"

  logic [11:0] seq_d, micro_addr;
  logic        cond_eff;
  logic        cc_n;

  // Dispatch ROM: illegal opcodes of the selected 1961 profile go to the
  // illegal handler; every other opcode has an eight-word slot.
  function automatic logic [11:0] op_entry(input logic [4:0] op);
    unique case (op)
      OP_AND, OP_IOR, OP_XOR, OP_XCT, OP_CAL, OP_LAC, OP_LIO, OP_DAC,
      OP_DAP, OP_DIP, OP_DIO, OP_DZM, OP_ADD, OP_SUB, OP_IDX, OP_ISP,
      OP_SAD, OP_SAS, OP_MUS, OP_DIS, OP_JMP, OP_JSP, OP_SKP, OP_SFT,
      OP_LAW, OP_IOT, OP_OPR: op_entry = 12'h100 | {4'd0, op, 3'b000};
      default:               op_entry = 12'h0F0;
    endcase
  endfunction

  function automatic logic [11:0] dev_entry(input logic [5:0] dev);
    dev_entry = 12'h200 | {4'd0, dev, 2'b00};
  endfunction

  always_comb begin
    cond_eff = cond_i ^ uc_i.cc_inv;
    cc_n = ~cond_eff;
    unique case (uc_i.seq_disp)
      2'd1:    seq_d = op_entry(opcode_i);
      2'd2:    seq_d = dev_entry(device_i);
      2'd3:    seq_d = 12'h300 | {5'd0, sft_i, 3'b000};
      default: seq_d = uc_i.next;
    endcase
  end

  amd_am2910 sequencer (
      .cp_i(clk_i),
      .instruction_i(uc_i.seq),
      .d_i(seq_d),
      .cc_n_i(cc_n),
      .ccen_n_i(1'b0),
      .ci_i(1'b1),
      .rld_n_i(1'b1),
      .oe_n_i(1'b0),
      .y_o(micro_addr),
      .y_oe_o(),
      .full_n_o(),
      .pl_n_o(),
      .map_n_o(),
      .vect_n_o()
  );

  // The Am2910 has no reset pin. While reset is asserted the store is held at
  // the power-up vector 0x0F8 (JZ), which clears the stack and jumps to word 0;
  // on release the first executed word is RESET1 at microaddress 0.
  assign addr_o = rst_n_i ? micro_addr : 12'h0F8;

  pdp1_uc store (
      .addr_i(addr_o),
      .word_o(uc_o)
  );


endmodule

`endif
