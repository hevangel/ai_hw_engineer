// IBM System/360 common CPU engine -- M2 core.
//
// M1 delivered a fetch/decode/execute loop with 23 instructions and no
// interruption mechanism. M2 adds the status-switching instructions and the
// program-interruption path:
//
//   - LOAD PSW (LPSW, 0x82) and SET SYSTEM MASK (SSM, 0x80), both privileged,
//     and SET PROGRAM MASK (SPM, 0x04), which is not privileged, from
//     A22-6821-7 pp. 72-74;
//   - program interruptions with the codes of Figure 16 (p. 16): operation
//     (1), privileged operation (2), specification (6) and fixed-point
//     overflow (8);
//   - the interruption sequence of pp. 15-16 and 71-72: store the current PSW
//     plus interruption code in the program old PSW at 0x28, fetch the new PSW
//     from 0x68, and load it (bits 16-33 are not retained);
//   - problem state (PSW bit 15) enforcement for privileged instructions and
//     the wait state (bit 14), in which no instruction is fetched.
//
// Suppressed exceptions (operation, privileged operation, specification) leave
// the condition code, the registers and storage unchanged, and the instruction
// address stored in the old PSW is the updated one -- advanced by the number of
// halfwords in the ILC (p. 72). A fixed-point overflow completes the
// instruction (result and condition code 3 stored) and then takes the
// interruption when program-mask bit 36 is one (p. 27, p. 16).
//
// Storage interface: the read port is combinational (the aligned word
// containing mem_addr is returned in the same cycle) and the write port takes
// one cycle. Storage access timing, interleaving and channel contention are not
// modelled. Operands must be naturally aligned; apart from the LOAD PSW
// doubleword check, specification (alignment) exceptions are not detected.
//
// Not implemented (each is tracked by its own milestone): protection keys and
// storage protection, DAT, addressing exceptions (no storage-size limit),
// supervisor call, external, I/O and machine-check interruptions, EXECUTE,
// halfword/multiply/divide/shift/decimal/floating-point and SS instructions.
`ifndef IBM_S360_CPU_SV
`define IBM_S360_CPU_SV

`timescale 1ns/1ps

module ibm_s360_cpu #(
    parameter logic [23:0] RESET_IA = 24'h00_0100
) (
    input  logic        clk,
    input  logic        rst_n,
    // Storage port.
    output logic [23:0] mem_addr,
    output logic        mem_we,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wbe,
    input  logic [31:0] mem_rdata,
    // Architectural status.
    output logic [63:0] psw,
    output logic        ovf_pending,
    output logic [15:0] int_code_dbg,
    output logic        int_taken,
    output logic        in_wait_state,
    output logic        retire,
    output logic [23:0] retire_ia,
    output logic [3:0]  retire_len,
    // Verification aid: flattened general registers, gpr[i] at bits 32*i+31:32*i.
    // It is pure wiring and adds no sequential logic.
    output logic [511:0] gpr_dbg
);

  `include "ibm_s360_defs.svh"

  localparam logic [23:0] PROGRAM_OLD_PSW = 24'h00_0028;
  localparam logic [23:0] PROGRAM_NEW_PSW = 24'h00_0068;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    S_CHECK     = 4'd0,   // wait-state and interruption check before fetch
    S_FETCH     = 4'd1,
    S_DECODE    = 4'd2,
    S_EXEC      = 4'd3,
    S_WRITE     = 4'd4,
    S_COMMIT    = 4'd5,
    S_INT_OLD0  = 4'd6,   // store old PSW bits 0-31
    S_INT_OLD1  = 4'd7,   // store old PSW bits 32-63
    S_INT_NEW0  = 4'd8,   // fetch new PSW bits 0-31
    S_INT_NEW1  = 4'd9,   // fetch new PSW bits 32-63
    S_INT_LOAD  = 4'd10,  // make the new PSW current
    S_LPSW_LO   = 4'd11,  // LOAD PSW doubleword, first word
    S_LPSW_HI   = 4'd12,  // LOAD PSW doubleword, second word
    S_LPSW_LOAD = 4'd13   // replace the current PSW
  } state_e;

  state_e state;

  logic [31:0] gpr [0:15];

  logic [23:0] ia_cur;   // address of the instruction in flight
  logic [2:0]  cnt;      // index of the next instruction byte to fetch
  logic [3:0]  len;      // instruction length in bytes
  logic [7:0]  ib [0:5]; // fetched instruction bytes

  logic [23:0] ea_q;     // effective/branch address of the instruction
  logic [31:0] opnd_q;   // operand word read at ea_q
  logic [7:0]  str_q;    // operand byte read at ea_q
  logic [3:0]  len_q;
  logic [1:0]  ilc_q;

  logic        wr_en_q;
  logic [3:0]  wr_idx_q;
  logic [31:0] res_q;
  logic        cc_we_q;
  logic [1:0]  cc_q;
  logic [23:0] next_ia_q;

  logic [31:0] st_data_q;
  logic [3:0]  st_be_q;

  // Status-switching operands captured in S_EXEC.
  logic        pmask_en_q;
  logic [3:0]  pmask_q;
  logic        spm_cc_en_q;
  logic [1:0]  spm_cc_q;
  logic        sysmask_en_q;
  logic [7:0]  sysmask_q;

  // Interruption state.
  logic [15:0] int_code_q;
  logic [63:0] int_psw_q;
  logic        int_pending_q;
  logic        ovf_int_q;      // this instruction's overflow must interrupt
  logic [15:0] int_code_dbg_q;
  logic [31:0] new_lo_q;
  logic [31:0] new_hi_q;
  logic [31:0] lpsw_lo_q;
  logic [31:0] lpsw_hi_q;

  logic        ovf_q;

  // ---------------------------------------------------------------------------
  // Decode
  // ---------------------------------------------------------------------------
  s360_dec_t dec;
  assign dec = s360_decode(ib[0]);

  logic [7:0] b1, b2, b3;
  assign b1 = ib[1];
  assign b2 = ib[2];
  assign b3 = ib[3];

  logic [3:0]  r1_f;
  logic [3:0]  r2_f;   // RR second register / RX index field
  logic [3:0]  b_f;    // base field of the second halfword
  logic [11:0] d_f;
  logic [7:0]  i2_f;

  assign r1_f = s360_r1(b1);
  assign r2_f = s360_r2_or_x2(b1);
  assign b_f  = s360_b(b2);
  assign d_f  = s360_d(b2, b3);
  assign i2_f = b1;

  // The index field exists only in the RX format; SI uses B|D with no index.
  logic [3:0] x_f;
  assign x_f = (dec.fmt == FMT_RX) ? r2_f : 4'd0;

  logic [23:0] ea;
  ibm_s360_addr u_addr (
      .b_field(b_f),
      .x_field(x_f),
      .b_val  (gpr[b_f]),
      .x_val  (gpr[r2_f]),
      .disp   (d_f),
      .addr   (ea)
  );

  // ---------------------------------------------------------------------------
  // PSW
  // ---------------------------------------------------------------------------
  logic [63:0] psw_word;
  logic [23:0] psw_ia;
  // The ILC and the non-overflow program-mask bits are observed through the
  // 64-bit PSW word, so their dedicated ports are left unused here.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [1:0]  psw_ilc;
  logic [3:0]  psw_pmask;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [1:0]  psw_cc;
  logic        psw_problem;
  logic        psw_wait;

  logic        psw_load;
  logic [63:0] psw_load_data;
  logic        psw_set_ia;
  logic [23:0] psw_ia_in;
  logic        psw_set_ilc;
  logic [1:0]  psw_ilc_in;
  logic        psw_set_cc;
  logic [1:0]  psw_cc_in;
  logic        psw_set_pmask;
  logic [3:0]  psw_pmask_in;
  logic        psw_set_sysmask;
  logic [7:0]  psw_sysmask_in;

  ibm_s360_psw u_psw (
      .clk       (clk),
      .rst_n     (rst_n),
      .reset_ia  (RESET_IA),
      .load      (psw_load),
      .load_data (psw_load_data),
      .set_ia    (psw_set_ia),
      .ia_in     (psw_ia_in),
      .set_ilc   (psw_set_ilc),
      .ilc_in    (psw_ilc_in),
      .set_cc    (psw_set_cc),
      .cc_in     (psw_cc_in),
      .set_pmask (psw_set_pmask),
      .pmask_in  (psw_pmask_in),
      .set_sysmask(psw_set_sysmask),
      .sysmask_in(psw_sysmask_in),
      .psw       (psw_word),
      .ia        (psw_ia),
      .ilc       (psw_ilc),
      .cc        (psw_cc),
      .pmask     (psw_pmask),
      .problem   (psw_problem),
      .wait_state(psw_wait)
  );

  assign psw = psw_word;

  // ---------------------------------------------------------------------------
  // ALU wiring
  // ---------------------------------------------------------------------------
  s360_alu_op_e alu_op;
  logic [31:0] alu_a, alu_b;
  logic [31:0] alu_y;
  logic [1:0]  alu_cc;
  logic        alu_ovf;

  logic        sets_cc;
  logic        is_store;
  logic        is_branch;

  always_comb begin
    alu_op    = ALU_ADD;
    sets_cc   = 1'b0;
    is_store  = 1'b0;
    is_branch = 1'b0;
    unique case (dec.op)
      OP_LR:  alu_op = ALU_ADD;
      OP_LTR: begin alu_op = ALU_TEST; sets_cc = 1'b1; end
      OP_AR:  begin alu_op = ALU_ADD;  sets_cc = 1'b1; end
      OP_SR:  begin alu_op = ALU_SUB;  sets_cc = 1'b1; end
      OP_CR:  begin alu_op = ALU_CMP;  sets_cc = 1'b1; end
      OP_CLR: begin alu_op = ALU_CLR;  sets_cc = 1'b1; end
      OP_NR:  begin alu_op = ALU_AND;  sets_cc = 1'b1; end
      OP_OR:  begin alu_op = ALU_OR;   sets_cc = 1'b1; end
      OP_XR:  begin alu_op = ALU_XOR;  sets_cc = 1'b1; end
      OP_A:   begin alu_op = ALU_ADD;  sets_cc = 1'b1; end
      OP_S:   begin alu_op = ALU_SUB;  sets_cc = 1'b1; end
      OP_C:   begin alu_op = ALU_CMP;  sets_cc = 1'b1; end
      OP_CL:  begin alu_op = ALU_CLR;  sets_cc = 1'b1; end
      OP_N:   begin alu_op = ALU_AND;  sets_cc = 1'b1; end
      OP_O:   begin alu_op = ALU_OR;   sets_cc = 1'b1; end
      OP_X:   begin alu_op = ALU_XOR;  sets_cc = 1'b1; end
      OP_CLI: begin alu_op = ALU_CLR;  sets_cc = 1'b1; end
      OP_ST:  is_store = 1'b1;
      OP_MVI: is_store = 1'b1;
      OP_BC:  is_branch = 1'b1;
      OP_BCR: is_branch = 1'b1;
      default: ;
    endcase
  end

  // First operand: the CLI immediate byte, the LTR second register (the value
  // that LOAD AND TEST copies and tests), or the R1 register.
  always_comb begin
    if (dec.op == OP_CLI) begin
      alu_a = {24'd0, i2_f};
    end else if (dec.op == OP_LTR) begin
      alu_a = gpr[r2_f];
    end else begin
      alu_a = gpr[r1_f];
    end
  end

  // Second operand: the storage operand for RX/SI operations, otherwise the
  // R2 register (unused by LOAD AND TEST).
  always_comb begin
    if (dec.op == OP_CLI) begin
      alu_b = {24'd0, str_q};
    end else if (dec.fmt == FMT_RR) begin
      alu_b = gpr[r2_f];
    end else begin
      alu_b = opnd_q;
    end
  end

  ibm_s360_alu u_alu (
      .op (alu_op),
      .a  (alu_a),
      .b  (alu_b),
      .y  (alu_y),
      .cc (alu_cc),
      .ovf(alu_ovf)
  );

  // ---------------------------------------------------------------------------
  // Branch decision (A22-6821-7 p. 74): mask bit position 8 is CC 0 and bit 11
  // is CC 3, so the selected mask bit is mask[3 - cc]. The RR form with R2 = 0
  // never branches.
  // ---------------------------------------------------------------------------
  logic [3:0]  branch_mask;
  logic [23:0] branch_target;
  logic        branch_taken;

  assign branch_mask = b1[7:4];

  always_comb begin
    if (dec.op == OP_BCR) begin
      branch_target = gpr[r2_f][23:0];
      branch_taken  = (r2_f != 4'd0) && branch_mask[3 - psw_cc];
    end else begin
      branch_target = ea;
      branch_taken  = branch_mask[3 - psw_cc];
    end
  end

  // ---------------------------------------------------------------------------
  // Program-check detection (A22-6821-7 pp. 71-74).
  // ---------------------------------------------------------------------------
  logic lpsw_unaligned;
  logic privileged;
  logic suppress;
  logic [15:0] suppress_code;

  assign privileged     = (dec.op == OP_LPSW) || (dec.op == OP_SSM);
  assign lpsw_unaligned = (dec.op == OP_LPSW) && (ea[2:0] != 3'b000);

  always_comb begin
    suppress      = 1'b0;
    suppress_code = 16'd0;
    if (!dec.valid) begin
      suppress      = 1'b1;
      suppress_code = 16'd1;   // operation
    end else if (privileged && psw_problem) begin
      suppress      = 1'b1;
      suppress_code = 16'd2;   // privileged operation
    end else if (lpsw_unaligned) begin
      suppress      = 1'b1;
      suppress_code = 16'd6;   // specification
    end
  end

  // Old PSW for a suppressed instruction: current PSW fields with the updated
  // instruction address and the instruction length code, plus the code.
  logic [63:0] int_psw_suppressed;
  assign int_psw_suppressed = {psw_word[63:48], suppress_code, s360_ilc(dec.fmt),
                               psw_word[29:24], (ia_cur + {20'd0, len})};

  // ---------------------------------------------------------------------------
  // Storage reads: the port returns the aligned 32-bit word containing the
  // byte address. The byte at offset k is bits [8*(3-k) +: 8]. Word operands
  // must be aligned.
  // ---------------------------------------------------------------------------
  logic [1:0]  rd_off;
  logic [4:0]  byte_sel;
  logic [31:0] read_word;
  logic [7:0]  read_byte;

  assign rd_off = (state == S_FETCH)  ? (ia_cur[1:0] + cnt[1:0])
                : (state == S_DECODE) ? ea[1:0]
                                      : ea_q[1:0];
  assign read_word = mem_rdata;
  assign byte_sel = (5'd3 - {3'b000, rd_off}) << 3;
  assign read_byte = mem_rdata[byte_sel +: 8];

  // ---------------------------------------------------------------------------
  // Storage port
  // ---------------------------------------------------------------------------
  logic [23:0] fetch_addr;
  assign fetch_addr = ia_cur + {21'd0, cnt};

  always_comb begin
    mem_addr  = ia_cur;
    mem_we    = 1'b0;
    mem_wdata = 32'd0;
    mem_wbe   = 4'd0;
    unique case (state)
      S_FETCH:  mem_addr = fetch_addr;
      S_DECODE: mem_addr = ea;
      S_WRITE: begin
        mem_addr  = ea_q;
        mem_we    = 1'b1;
        mem_wdata = st_data_q;
        mem_wbe   = st_be_q;
      end
      S_INT_OLD0: begin
        mem_addr  = PROGRAM_OLD_PSW;
        mem_we    = 1'b1;
        mem_wdata = int_psw_q[63:32];
        mem_wbe   = 4'hF;
      end
      S_INT_OLD1: begin
        mem_addr  = PROGRAM_OLD_PSW + 24'd4;
        mem_we    = 1'b1;
        mem_wdata = int_psw_q[31:0];
        mem_wbe   = 4'hF;
      end
      S_INT_NEW0: mem_addr = PROGRAM_NEW_PSW;
      S_INT_NEW1: mem_addr = PROGRAM_NEW_PSW + 24'd4;
      S_LPSW_LO:  mem_addr = ea_q;
      S_LPSW_HI:  mem_addr = ea_q + 24'd4;
      default:    mem_addr = ia_cur;
    endcase
  end

  // ---------------------------------------------------------------------------
  // PSW control
  // ---------------------------------------------------------------------------
  assign psw_load      = (state == S_INT_LOAD) || (state == S_LPSW_LOAD);
  assign psw_load_data = (state == S_INT_LOAD) ? {new_lo_q, new_hi_q}
                                               : {lpsw_lo_q, lpsw_hi_q};
  assign psw_set_ia    = (state == S_COMMIT);
  assign psw_ia_in     = next_ia_q;
  assign psw_set_ilc   = (state == S_COMMIT);
  assign psw_ilc_in    = ilc_q;
  assign psw_set_cc    = (state == S_COMMIT) && (cc_we_q || spm_cc_en_q);
  assign psw_cc_in     = spm_cc_en_q ? spm_cc_q : cc_q;
  assign psw_set_pmask = (state == S_COMMIT) && pmask_en_q;
  assign psw_pmask_in  = pmask_q;
  assign psw_set_sysmask = (state == S_COMMIT) && sysmask_en_q;
  assign psw_sysmask_in  = sysmask_q;

  // ---------------------------------------------------------------------------
  // Sequencer
  // ---------------------------------------------------------------------------
  logic [3:0] len_of_first_byte;
  assign len_of_first_byte = s360_len_bytes(read_byte[7:6]);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state        <= S_CHECK;
      ia_cur       <= RESET_IA;
      cnt          <= 3'd0;
      len          <= 4'd0;
      len_q        <= 4'd0;
      ilc_q        <= 2'd0;
      ea_q         <= 24'd0;
      opnd_q       <= 32'd0;
      str_q        <= 8'd0;
      wr_en_q      <= 1'b0;
      wr_idx_q     <= 4'd0;
      res_q        <= 32'd0;
      cc_we_q      <= 1'b0;
      cc_q         <= 2'd0;
      next_ia_q    <= RESET_IA;
      st_data_q    <= 32'd0;
      st_be_q      <= 4'd0;
      pmask_en_q   <= 1'b0;
      pmask_q      <= 4'd0;
      spm_cc_en_q  <= 1'b0;
      spm_cc_q     <= 2'd0;
      sysmask_en_q <= 1'b0;
      sysmask_q    <= 8'd0;
      int_code_q   <= 16'd0;
      int_psw_q    <= 64'd0;
      int_pending_q<= 1'b0;
      ovf_int_q    <= 1'b0;
      int_code_dbg_q <= 16'd0;
      new_lo_q     <= 32'd0;
      new_hi_q     <= 32'd0;
      lpsw_lo_q    <= 32'd0;
      lpsw_hi_q    <= 32'd0;
      ovf_q        <= 1'b0;
      for (int i = 0; i < GPR_COUNT; i++) begin
        gpr[i] <= 32'd0;
      end
      for (int i = 0; i < 6; i++) begin
        ib[i] <= 8'd0;
      end
    end else begin
      unique case (state)
        S_CHECK: begin
          if (psw_wait) begin
            // No instruction is fetched in the wait state. Without I/O and
            // external interruptions no new PSW can arrive, so the CPU stays
            // here; this is the documented M2 behaviour.
            state <= S_CHECK;
          end else if (int_pending_q) begin
            state <= S_INT_OLD0;
          end else begin
            ia_cur <= psw_ia;
            cnt    <= 3'd0;
            len    <= 4'd0;
            state  <= S_FETCH;
          end
        end

        S_FETCH: begin
          ib[cnt] <= read_byte;
          if (cnt == 3'd0) begin
            len   <= len_of_first_byte;
            cnt   <= 3'd1;
            state <= S_FETCH;
          end else if ((cnt + 3'd1) == len) begin
            state <= S_DECODE;
          end else begin
            cnt   <= cnt + 3'd1;
            state <= S_FETCH;
          end
        end

        S_DECODE: begin
          if (suppress) begin
            int_code_q    <= suppress_code;
            int_psw_q     <= int_psw_suppressed;
            int_pending_q <= 1'b1;
            state         <= S_CHECK;
          end else begin
            ea_q   <= ea;
            opnd_q <= read_word;
            str_q  <= read_byte;
            len_q  <= len;
            ilc_q  <= s360_ilc(dec.fmt);
            state  <= S_EXEC;
          end
        end

        S_EXEC: begin
          res_q      <= 32'd0;
          wr_en_q    <= 1'b0;
          cc_we_q    <= 1'b0;
          cc_q       <= psw_cc;
          st_data_q  <= 32'd0;
          st_be_q    <= 4'd0;
          pmask_en_q <= 1'b0;
          spm_cc_en_q<= 1'b0;
          sysmask_en_q <= 1'b0;
          ovf_int_q  <= 1'b0;
          next_ia_q  <= ia_cur + {20'd0, len_q};
          if (sets_cc && alu_ovf) begin
            ovf_q <= 1'b1;
            // Fixed-point overflow interrupts only when program-mask bit 36
            // (psw[27]) is one.
            if (psw_pmask[0]) begin
              ovf_int_q <= 1'b1;
            end
          end
          unique case (dec.op)
            OP_LR: begin
              wr_en_q  <= 1'b1;
              wr_idx_q <= r1_f;
              res_q    <= gpr[r2_f];
            end
            OP_LTR, OP_AR, OP_SR, OP_NR, OP_OR, OP_XR,
            OP_A, OP_S, OP_N, OP_O, OP_X: begin
              wr_en_q  <= 1'b1;
              wr_idx_q <= r1_f;
              res_q    <= alu_y;
            end
            OP_LA: begin
              wr_en_q  <= 1'b1;
              wr_idx_q <= r1_f;
              res_q    <= {8'd0, ea_q};
            end
            OP_L: begin
              wr_en_q  <= 1'b1;
              wr_idx_q <= r1_f;
              res_q    <= opnd_q;
            end
            OP_ST: begin
              st_data_q <= gpr[r1_f];
              st_be_q   <= 4'hF;
            end
            OP_MVI: begin
              st_data_q <= {4{i2_f}};
              st_be_q   <= 4'b1000 >> ea_q[1:0];
            end
            OP_SPM: begin
              // Register bits 2-3 replace CC, bits 4-7 replace the program
              // mask (A22-6821-7 p. 73).
              spm_cc_en_q <= 1'b1;
              spm_cc_q    <= gpr[r1_f][3:2];
              pmask_en_q  <= 1'b1;
              pmask_q     <= gpr[r1_f][7:4];
            end
            OP_SSM: begin
              sysmask_en_q <= 1'b1;
              sysmask_q    <= str_q;
            end
            default: ;
          endcase
          if (sets_cc) begin
            cc_we_q <= 1'b1;
            cc_q    <= alu_cc;
          end
          if (is_branch && branch_taken) begin
            next_ia_q <= branch_target;
          end
          if (dec.op == OP_LPSW) begin
            state <= S_LPSW_LO;
          end else if (is_store) begin
            state <= S_WRITE;
          end else begin
            state <= S_COMMIT;
          end
        end

        S_WRITE: state <= S_COMMIT;

        S_COMMIT: begin
          if (wr_en_q) begin
            gpr[wr_idx_q] <= res_q;
          end
          if (ovf_int_q) begin
            // The instruction completed: the old PSW carries the new CC, the
            // updated instruction address and the instruction length code.
            int_code_q    <= 16'd8;
            int_psw_q     <= {psw_word[63:48], 16'd8, ilc_q, cc_q,
                              psw_word[27:24], next_ia_q};
            int_pending_q <= 1'b1;
          end
          state <= S_CHECK;
        end

        S_INT_OLD0: state <= S_INT_OLD1;
        S_INT_OLD1: state <= S_INT_NEW0;
        S_INT_NEW0: begin
          new_lo_q <= mem_rdata;
          state    <= S_INT_NEW1;
        end
        S_INT_NEW1: begin
          new_hi_q <= mem_rdata;
          state    <= S_INT_LOAD;
        end
        S_INT_LOAD: begin
          int_pending_q  <= 1'b0;
          int_code_dbg_q <= int_code_q;
          state          <= S_CHECK;
        end

        S_LPSW_LO: begin
          lpsw_lo_q <= mem_rdata;
          state     <= S_LPSW_HI;
        end
        S_LPSW_HI: begin
          lpsw_hi_q <= mem_rdata;
          state     <= S_LPSW_LOAD;
        end
        S_LPSW_LOAD: state <= S_CHECK;

        default: state <= S_CHECK;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign ovf_pending   = ovf_q;
  assign int_code_dbg  = int_code_dbg_q;
  assign int_taken     = (state == S_INT_LOAD);
  assign in_wait_state = psw_wait;
  // LOAD PSW completes without passing through S_COMMIT (it replaces the PSW
  // instead of updating fields), so it announces completion here.
  assign retire        = (state == S_COMMIT) || (state == S_LPSW_LOAD);
  assign retire_ia     = ia_cur;
  assign retire_len    = len_q;

  always_comb begin
    for (int i = 0; i < GPR_COUNT; i++) begin
      gpr_dbg[32*i +: 32] = gpr[i];
    end
  end

`ifdef FORMAL
  // Structural facts that hold in every state, including the unconstrained
  // initial one. The temporal interruption and retirement contracts live in
  // formal/ibm_s360_cpu_props.sv, which guards its checks with a completed
  // reset cycle.
  always_comb begin
    assert (!mem_we || (state == S_WRITE) ||
            (state == S_INT_OLD0) || (state == S_INT_OLD1));
    assert ((state == S_COMMIT) || (state == S_LPSW_LOAD) || !retire);
  end
`endif

`ifdef FORMAL
  ibm_s360_cpu_props formal_properties (
      .clk             (clk),
      .rst_n           (rst_n),
      .state           (state),
      .dec_valid       (dec.valid),
      .op              (dec.op),
      .len_q           (len_q),
      .ilc_q           (ilc_q),
      .ia_cur          (ia_cur),
      .next_ia_q       (next_ia_q),
      .branch_target   (branch_target),
      .branch_taken    (branch_taken),
      .is_branch       (is_branch),
      .is_store        (is_store),
      .wr_en_q         (wr_en_q),
      .suppress        (suppress),
      .suppress_code   (suppress_code),
      .len             (len),
      .int_pending     (int_pending_q),
      .int_code        (int_code_q),
      .int_psw         (int_psw_q),
      .mem_we          (mem_we),
      .mem_addr        (mem_addr),
      .mem_wbe         (mem_wbe),
      .psw             (psw_word),
      .psw_problem     (psw_problem),
      .psw_wait        (psw_wait),
      .gpr_dbg         (gpr_dbg),
      .retire          (retire),
      .retire_len      (retire_len),
      .int_taken       (int_taken),
      .ovf_pending     (ovf_q)
  );
`endif

endmodule

`endif
