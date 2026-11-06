// IBM System/360 program status word register.
//
// Field layout from A22-6821-7 Figure 14 "Program Status Word Format", p. 15:
//   bits  0-7   system mask (I/O channel 0-5, timer, external)
//   bits  8-11  protection key
//   bit   12    ASCII mode (A)
//   bit   13    machine-check mask (M)
//   bit   14    wait state (W)
//   bit   15    problem state (P)
//   bits 16-31  interruption code
//   bits 32-33  instruction length code (ILC)
//   bits 34-35  condition code (CC)
//   bits 36-39  program mask
//   bits 40-63  instruction address
//
// In this 64-bit vector bit 63 is the manual's bit 0, so the instruction
// address occupies psw[23:0] and the condition code occupies psw[29:28].
//
// Only the fields the M1 core changes are writable here: instruction address,
// ILC and condition code. A whole-word load path is provided for LOAD PSW and
// for interruption entry in later milestones; it replaces every bit, including
// the fields this core never writes individually.

`timescale 1ns/1ps

`ifndef IBM_S360_PSW_SV
`define IBM_S360_PSW_SV

module ibm_s360_psw (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [23:0] reset_ia,
    // Whole-word load (LOAD PSW / interruption entry).
    input  logic        load,
    input  logic [63:0] load_data,
    // Field updates. Fields are disjoint, so simultaneous strobes are safe.
    input  logic        set_ia,
    input  logic [23:0] ia_in,
    input  logic        set_ilc,
    input  logic [1:0]  ilc_in,
    input  logic        set_cc,
    input  logic [1:0]  cc_in,
    output logic [63:0] psw,
    output logic [23:0] ia,
    output logic [1:0]  ilc,
    output logic [1:0]  cc
);

  logic [63:0] psw_q;

  `include "ibm_s360_defs.svh"

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      psw_q <= {40'd0, reset_ia};
    end else if (load) begin
      psw_q <= load_data;
    end else begin
      if (set_ia) begin
        psw_q[PSW_IA_MSB:PSW_IA_LSB] <= ia_in;
      end
      if (set_ilc) begin
        psw_q[PSW_ILC_MSB -: 2] <= ilc_in;
      end
      if (set_cc) begin
        psw_q[PSW_CC_MSB -: 2] <= cc_in;
      end
    end
  end

  assign psw = psw_q;
  assign ia  = psw_q[PSW_IA_MSB:PSW_IA_LSB];
  assign ilc = psw_q[PSW_ILC_MSB -: 2];
  assign cc  = psw_q[PSW_CC_MSB -: 2];

endmodule

`endif
