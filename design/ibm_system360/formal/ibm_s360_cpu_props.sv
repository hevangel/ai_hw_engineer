// Formal properties for the S/360 M1 core.
//
// This module is instantiated inside ibm_s360_cpu under `ifdef FORMAL so that
// it can observe the sequencer's latches as well as the architectural ports.
// The properties state the retirement contract that the instruction semantics
// rely on:
//   - the instruction address advances by the fetched length, or to the branch
//     address when a branch is taken (A22-6821-7 pp. 14 and 74);
//   - the ILC recorded with the retired instruction matches its length;
//   - comparisons and branches never write a general register;
//   - general registers change only on a retirement;
//   - stores are issued in their own cycle with the documented byte enables;
//   - an illegal operation code stops the machine before any retirement.
//
// Memory contents are free inputs (mem_rdata is not constrained), so the
// properties hold for arbitrary instruction streams. Instruction-level
// agreement with an independent S/360 oracle is tracked by issue #383; these
// properties check the core's structural contract, not the encoding table.
`timescale 1ns/1ps

module ibm_s360_cpu_props (
    input logic        clk,
    input logic        rst_n,
    // Sequencer state.
    input logic [2:0]  state,
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
    // Storage and architectural ports.
    input logic        mem_we,
    input logic [3:0]  mem_wbe,
    input logic [63:0] psw,
    input logic [511:0] gpr_dbg,
    input logic        retire,
    input logic [3:0]  retire_len,
    input logic        halted,
    input logic        pc_check_pending,
    input logic        ovf_pending
);

  `include "ibm_s360_defs.svh"

  localparam logic [2:0] ST_COMMIT = 3'd5;
  localparam logic [2:0] ST_HALT   = 3'd6;
  localparam logic [2:0] ST_DECODE = 3'd2;

  // Reset is assumed in the first cycle so that the sequencer and PSW start
  // from defined values and $past() aligns with the clock edge.
  always @(posedge clk) begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      // ---- Retirement contract -------------------------------------------
      if ($past(retire)) begin
        // ILC of the retired instruction, visible one cycle later because the
        // PSW is updated at the retiring clock edge.
        assert (psw[PSW_ILC_MSB -: 2] == $past(ilc_q));
        assert ($past(retire_len) == ({2'b00, $past(ilc_q)} << 1));
        assert (psw[PSW_IA_MSB:PSW_IA_LSB] == $past(next_ia_q));
        if ($past(is_branch) && $past(branch_taken)) begin
          assert ($past(next_ia_q) == $past(branch_target));
        end else begin
          assert ($past(next_ia_q) == ($past(ia_cur) + {20'd0, $past(len_q)}));
        end
      end

      // ---- Register writes -------------------------------------------------
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

      // ---- Storage writes --------------------------------------------------
      assert (!mem_we || !retire);
      if (mem_we) begin
        if ($past(op) == OP_MVI) begin
          assert ($onehot(mem_wbe));
        end
        if ($past(op) == OP_ST) begin
          assert (mem_wbe == 4'hF);
        end
      end

      // ---- Program check and halt -----------------------------------------
      if (!dec_valid && $past(state) == ST_DECODE) begin
        assert (halted);
      end
      if (halted) begin
        assert (!retire);
        assert (pc_check_pending);
        // The halt is sticky.
        assert (state == ST_HALT);
      end

      // A retirement never coincides with a halt.
      assert (!(retire && halted));
    end
  end

  // ---- Non-vacuity covers ---------------------------------------------------
  // The covers are limited to behaviour reachable within the job's depth from
  // the reset state, which is one complete instruction for the core job. The
  // retiring operation and the retirement pulse are captured in registers so
  // that a cover can pair an instruction with the condition code it sets (the
  // PSW is updated at the end of the retiring cycle). Covers that need a
  // two-instruction prefix (an overflowing ADD, a negative LOAD AND TEST, a
  // "first operand high" COMPARE LOGICAL) are not claimed here: the arithmetic
  // unit covers prove those semantics exhaustively, and the directed
  // simulation program exercises the overflow path.
  logic       retire_d;
  logic [4:0] retire_op_d;

  always_ff @(posedge clk) begin
    retire_d    <= retire;
    if (retire) begin
      retire_op_d <= op;
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (retire && ($past(op) == OP_L));
      cover (retire && ($past(op) == OP_LA));
      cover (retire && ($past(op) == OP_AR));
      cover (retire && ($past(op) == OP_CR));
      cover (retire && ($past(op) == OP_LR));
      cover (mem_we && ($past(op) == OP_ST) && (mem_wbe == 4'hF));
      cover (mem_we && ($past(op) == OP_MVI) && $onehot(mem_wbe));
      cover (retire_d && (retire_op_d == OP_CLI) && (psw[PSW_CC_MSB -: 2] == 2'd0));
      cover (retire_d && (retire_op_d == OP_LTR) && (psw[PSW_CC_MSB -: 2] == 2'd0));
      cover (retire_d && (retire_op_d == OP_CLR) && (psw[PSW_CC_MSB -: 2] == 2'd0));
      cover (retire && ($past(op) == OP_BC) && $past(branch_taken));
      cover (retire && ($past(op) == OP_BC) && !$past(branch_taken));
      cover (retire && ($past(op) == OP_BCR) && $past(branch_taken));
      cover (halted && pc_check_pending);
    end
  end

endmodule
