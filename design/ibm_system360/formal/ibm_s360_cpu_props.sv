// Formal properties for the S/360 M2 core.
//
// This module is instantiated inside ibm_s360_cpu under `ifdef FORMAL so that
// it can observe the sequencer's latches as well as the architectural ports.
// The properties state the contracts added by M2 on top of the M1 retirement
// contract:
//
//   - a suppressed program check (operation, privileged operation,
//     specification) does not retire, does not change the condition code, and
//     stores an old PSW whose instruction address is advanced by the
//     instruction length and whose interruption code names the cause
//     (A22-6821-7 pp. 71-72);
//   - an interruption is never taken in the same cycle as a retirement, and
//     loading the new PSW clears the interruption code and ILC fields;
//   - storage is written only in the data-write cycle or in the two old-PSW
//     store cycles;
//   - no instruction is fetched in the wait state.
//
// Memory contents are free inputs, so the properties hold for arbitrary
// instruction streams. Instruction-level agreement with an independent S/360
// oracle is tracked by issue #383; these properties check the core's
// structural contract, not the encoding table.
`timescale 1ns/1ps

module ibm_s360_cpu_props (
    input logic        clk,
    input logic        rst_n,
    // Sequencer state.
    input logic [3:0]  state,
    input logic        dec_valid,
    input logic [4:0]  op,
    input logic [3:0]  len_q,
    input logic [1:0]  ilc_q,
    input logic [23:0] ia_cur,
    input logic [23:0] next_ia_q,
    input logic [23:0] branch_target,
    input logic        branch_taken,
    input logic        is_branch,
    input logic        is_store,
    input logic        wr_en_q,
    input logic        suppress,
    input logic [15:0] suppress_code,
    input logic [3:0]  len,
    input logic        int_pending,
    input logic [15:0] int_code,
    input logic [63:0] int_psw,
    // Storage and architectural ports.
    input logic        mem_we,
    input logic [23:0] mem_addr,
    input logic [3:0]  mem_wbe,
    input logic [63:0] psw,
    input logic        psw_problem,
    input logic        psw_wait,
    input logic [511:0] gpr_dbg,
    input logic        retire,
    input logic [3:0]  retire_len,
    input logic        int_taken,
    input logic        ovf_pending
);

  `include "ibm_s360_defs.svh"

  localparam logic [3:0] ST_CHECK   = 4'd0;
  localparam logic [3:0] ST_FETCH   = 4'd1;
  localparam logic [3:0] ST_DECODE  = 4'd2;
  localparam logic [3:0] ST_WRITE   = 4'd4;
  localparam logic [3:0] ST_COMMIT  = 4'd5;
  localparam logic [3:0] ST_OLD0    = 4'd6;
  localparam logic [3:0] ST_OLD1    = 4'd7;
  localparam logic [3:0] ST_INTLOAD = 4'd10;

  // Reset is assumed in the first cycle so that the sequencer and PSW start
  // from defined values and $past() aligns with the clock edge.
  always @(posedge clk) begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      // ---- Retirement contract (unchanged from M1) ------------------------
      // LOAD PSW replaces the instruction address instead of advancing it, so
      // the sequential-advance clause does not apply to it.
      if ($past(retire) && ($past(op) != OP_LPSW)) begin
        assert (psw[PSW_ILC_MSB -: 2] == $past(ilc_q));
        assert ($past(retire_len) == ({2'b00, $past(ilc_q)} << 1));
        assert (psw[PSW_IA_MSB:PSW_IA_LSB] == $past(next_ia_q));
        if ($past(is_branch) && $past(branch_taken)) begin
          assert ($past(next_ia_q) == $past(branch_target));
        end else begin
          assert ($past(next_ia_q) == ($past(ia_cur) + {20'd0, $past(len_q)}));
        end
      end

      // A general register changes only as the result of a retirement.
      if (gpr_dbg != $past(gpr_dbg)) begin
        assert ($past(retire));
        assert ($past(wr_en_q));
      end
      // Comparing and branching instructions never write a general register.
      if ($past(retire) &&
          (($past(op) == OP_C) || ($past(op) == OP_CR) || ($past(op) == OP_CL) ||
           ($past(op) == OP_CLR) || ($past(op) == OP_BC) || ($past(op) == OP_BCR))) begin
        assert (gpr_dbg == $past(gpr_dbg));
      end

      // ---- Program-check suppression --------------------------------------
      if (($past(state) == ST_DECODE) && $past(suppress)) begin
        // The instruction does not retire and the machine enters the
        // interruption sequence on the next cycle.
        assert (state == ST_CHECK);
        assert (int_pending);
        // The interruption code names the cause, in PSW bits 16-31.
        assert (int_psw[PSW_INTCODE_MSB -: 16] == $past(suppress_code));
        // The stored instruction address is the updated one. `len` is the
        // length of the instruction being decoded; len_q is not yet updated
        // on a suppressed instruction.
        assert (int_psw[PSW_IA_MSB:PSW_IA_LSB] ==
                ($past(ia_cur) + {20'd0, $past(len)}));
        // A suppressed instruction leaves the condition code unchanged.
        assert (int_psw[PSW_CC_MSB -: 2] == $past(psw[PSW_CC_MSB -: 2]));
      end

      // ---- Storage writes --------------------------------------------------
      assert (!mem_we || (state == ST_WRITE) || (state == ST_OLD0) || (state == ST_OLD1));
      if (state == ST_OLD0) begin
        assert (mem_addr == 24'h00_0028);
        assert (mem_wbe == 4'hF);
      end
      if (state == ST_OLD1) begin
        assert (mem_addr == 24'h00_002C);
      end

      // ---- Interruption entry ---------------------------------------------
      assert (!(int_taken && retire));
      if ($past(int_taken)) begin
        // A loaded PSW does not retain the interruption code or the ILC.
        assert (psw[PSW_INTCODE_MSB -: 16] == 16'd0);
        assert (psw[PSW_ILC_MSB -: 2] == 2'd0);
      end

      // ---- Wait state ------------------------------------------------------
      if (psw_wait) begin
        assert (state != ST_FETCH);
      end
    end
  end

  // ---- Non-vacuity covers ---------------------------------------------------
  // Covers reachable within the job depth from the reset state.
  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (int_taken && (int_code == 16'd1));   // operation
      cover (int_taken && (int_code == 16'd6));   // specification
      cover (retire && ($past(op) == OP_LPSW));
      cover (retire && ($past(op) == OP_SSM));
      cover (retire && ($past(op) == OP_SPM));
      cover (retire && ($past(op) == OP_L) && (psw[PSW_IA_MSB:PSW_IA_LSB] != 24'd0));
      cover (int_pending);
      cover (ovf_pending);
      cover (psw_wait);
      cover (!psw_problem && (state == ST_CHECK));
    end
  end

endmodule
