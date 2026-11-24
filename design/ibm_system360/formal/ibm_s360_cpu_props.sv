// Formal properties for the S/360 M3 core.
//
// Instantiated inside ibm_s360_cpu under `ifdef FORMAL so that it can observe
// the sequencer's latches as well as the architectural ports. The properties
// state the contracts added on top of the M1 retirement contract:
//
//   - whenever an interruption is raised (suppressed program check, divide
//     exception, supervisor call, or completed fixed-point overflow) the next
//     cycle enters the interruption sequence with the code in PSW bits 16-31
//     and the instruction address advanced by the instruction length
//     (A22-6821-7 pp. 31, 71-74);
//   - suppressions and the divide exception leave the condition code alone;
//   - an interruption is never taken in the same cycle as a retirement, and a
//     loaded PSW clears the interruption code and ILC fields;
//   - storage is written only in the data-write cycle or the two old-PSW store
//     cycles;
//   - no instruction is fetched in the wait state.
//
// Memory contents are free inputs, so the properties hold for arbitrary
// instruction streams. Instruction-level agreement with an independent S/360
// oracle is tracked by issue #383.
`timescale 1ns/1ps

module ibm_s360_cpu_props (
    input logic        clk,
    input logic        rst_n,
    input logic [4:0]  state,
    input logic        dec_valid,
    input logic [5:0]  op,
    input logic [3:0]  len_q,
    input logic [1:0]  ilc_q,
    input logic [23:0] ia_cur,
    input logic [23:0] next_ia_q,
    input logic [23:0] branch_target,
    input logic        branch_taken,
    input logic        is_branch,
    input logic        is_store,
    input logic        wr_en_q,
    input logic        wr_en2_q,
    input logic        suppress,
    input logic [15:0] suppress_code,
    input logic [3:0]  len,
    input logic        int_raise,
    input logic [3:0]  int_raise_len,
    input logic        int_raise_cc_same,
    input logic        int_pending,
    input logic [15:0] int_code,
    input logic [63:0] int_psw,
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

  localparam logic [4:0] ST_CHECK   = 5'd0;
  localparam logic [4:0] ST_FETCH   = 5'd1;
  localparam logic [4:0] ST_DECODE  = 5'd2;
  localparam logic [4:0] ST_WRITE   = 5'd4;
  localparam logic [4:0] ST_COMMIT  = 5'd5;
  localparam logic [4:0] ST_OLD0    = 5'd6;
  localparam logic [4:0] ST_OLD1    = 5'd7;
  localparam logic [4:0] ST_SS_C    = 5'd16;

  always @(posedge clk) begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  // Assertions only apply once a reset has actually been observed. The counter
  // is forced to zero in the initial state so an unconstrained start cannot
  // enable the checks, and it is cleared whenever reset is asserted.
  logic       raise_d;
  logic [3:0] raise_len_d;
  logic [1:0] raise_cc_d;
  logic       raise_cc_same_d;

  always_ff @(posedge clk) begin
    raise_d        <= int_raise;
    raise_len_d    <= int_raise_len;
    raise_cc_d     <= psw[PSW_CC_MSB -: 2];
    raise_cc_same_d <= int_raise_cc_same;
  end

  logic [2:0] rst_count;
  always_ff @(posedge clk) begin
    if ($initstate || !rst_n) begin
      rst_count <= 3'd0;
    end else if (rst_count != 3'd7) begin
      rst_count <= rst_count + 3'd1;
    end
  end

  always_ff @(posedge clk) begin
    if ((rst_count >= 3'd3) && rst_n) begin
      // ---- Retirement contract --------------------------------------------
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

      // A general register changes only as the result of a retirement that
      // enables one of the two write ports.
      if (gpr_dbg != $past(gpr_dbg)) begin
        assert ($past(retire));
        assert ($past(wr_en_q) || $past(wr_en2_q));
      end
      if ($past(retire) &&
          (($past(op) == OP_C) || ($past(op) == OP_CR) || ($past(op) == OP_CL) ||
           ($past(op) == OP_CLR) || ($past(op) == OP_BC) || ($past(op) == OP_BCR) ||
           ($past(op) == OP_CH))) begin
        assert (gpr_dbg == $past(gpr_dbg));
      end

      // ---- Interruption entry ---------------------------------------------
      // raise_d and its payload are registered copies of the combinational
      // raise signals, so all comparisons below read the same cycle's values.
      if (raise_d) begin
        assert (state == ST_CHECK);
        assert (int_pending);
        assert (int_psw[PSW_INTCODE_MSB -: 16] == int_code);
        assert (int_psw[PSW_IA_MSB:PSW_IA_LSB] == (ia_cur + {20'd0, raise_len_d}));
        if (raise_cc_same_d) begin
          assert (int_psw[PSW_CC_MSB -: 2] == raise_cc_d);
        end
      end

      // ---- Storage writes --------------------------------------------------
      assert (!mem_we || (state == ST_WRITE) || (state == ST_SS_C) ||
              (state == ST_OLD0) || (state == ST_OLD1));
      if (state == ST_OLD0) begin
        // Program, supervisor-call and external old PSWs.
        assert (mem_addr == 24'h00_0028 || mem_addr == 24'h00_0020 ||
                mem_addr == 24'h00_0018);
        assert (mem_wbe == 4'hF);
      end
      if (state == ST_OLD1) begin
        assert (mem_addr == 24'h00_002C || mem_addr == 24'h00_0024 ||
                mem_addr == 24'h00_001C);
      end

      assert (!(int_taken && retire));
      if ($past(int_taken)) begin
        assert (psw[PSW_INTCODE_MSB -: 16] == 16'd0);
        assert (psw[PSW_ILC_MSB -: 2] == 2'd0);
      end

      if (psw_wait) begin
        assert (state != ST_FETCH);
      end
    end
  end

  // ---- Non-vacuity covers ---------------------------------------------------
  // Only covers reachable by one instruction from the reset state are claimed:
  // the divider and the variable shifts make unreachable-cover proofs
  // expensive, so two-instruction covers are simulation territory (tests 7, 11
  // and 13).
  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (int_taken && (int_code == 16'd1));   // operation
      cover (int_taken && (int_code == 16'd6));   // specification
      cover (retire && ((op) == OP_LPSW));
      cover (retire && ((op) == OP_LH));
      cover (retire && ((op) == OP_SLA));
      cover (int_pending);
      cover (psw_wait);
    end
  end

endmodule
