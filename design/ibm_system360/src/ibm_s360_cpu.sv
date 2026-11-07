// IBM System/360 common CPU engine -- M1 core.
//
// This is the first functional increment of the shared S/360 engine tracked by
// issue #384. It implements a byte-addressable fetch/decode/execute loop over a
// single storage port and retires one instruction at a time. The implemented
// instruction set is deliberately small; every other operation code decodes as
// an illegal instruction of the correct length, raises a sticky program-check
// flag and stops the machine instead of executing something unintended.
//
// Behaviour is taken from A22-6821-7 (Principles of Operation, eighth edition):
//   - instruction formats and length recording, pp. 12-13, Figure 13;
//   - address arithmetic and zero base/index fields, pp. 13-14;
//   - PSW layout and sequential instruction execution, pp. 14-15;
//   - BRANCH ON CONDITION mask ordering (mask bit 8 <-> CC 0 ... bit 11 <->
//     CC 3) and the "R2 = 0 means no branch" rule for the RR form, pp. 73-74;
//   - LOAD ADDRESS inserts the address in bits 8-31 of the register and
//     zeroes bits 0-7, p. 65;
//   - fixed-point, logical and compare condition codes, pp. 26-32, 53-56;
//   - LOAD AND TEST replaces the first operand and sets the code by sign, p. 27.
//
// Storage interface: the read port is combinational (the aligned word
// containing mem_addr is returned in the same cycle) and the write port takes
// one cycle. This models storage contents functionally; access timing,
// interleaving and channel contention are not modelled and belong to a later
// milestone. Operands must be naturally aligned; specification (alignment)
// exceptions are not yet detected.
//
// Not implemented in M1 (each is tracked by its own issue):
//   halfword, multiply/divide, shift, decimal and floating-point operations;
//   SS instructions; protection keys and DAT; interruptions and PSW swapping;
//   wait/problem state; EXECUTE; channel I/O.

`timescale 1ns/1ps

`ifndef IBM_S360_CPU_SV
`define IBM_S360_CPU_SV

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
    output logic        pc_check_pending,
    output logic        halted,
    output logic        retire,
    output logic [23:0] retire_ia,
    output logic [3:0]  retire_len,
    // Verification aid: flattened general registers, gpr[i] at bits 32*i+31:32*i.
    // It is pure wiring and adds no sequential logic.
    output logic [511:0] gpr_dbg
);

  `include "ibm_s360_defs.svh"

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_FETCH  = 3'd1,
    S_DECODE = 3'd2,
    S_EXEC   = 3'd3,
    S_WRITE  = 3'd4,
    S_COMMIT = 3'd5,
    S_HALT   = 3'd6
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

  logic        ovf_q;
  logic        pc_check_q;

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
  // PSW
  // ---------------------------------------------------------------------------
  logic [63:0] psw_word;
  logic [23:0] psw_ia;
  // Only used by the FORMAL properties below when assertions are disabled.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [1:0]  psw_ilc;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [1:0]  psw_cc;

  ibm_s360_psw u_psw (
      .clk      (clk),
      .rst_n    (rst_n),
      .reset_ia (RESET_IA),
      .load     (1'b0),
      .load_data(64'd0),
      .set_ia   (state == S_COMMIT),
      .ia_in    (next_ia_q),
      .set_ilc  (state == S_COMMIT),
      .ilc_in   (ilc_q),
      .set_cc   ((state == S_COMMIT) && cc_we_q),
      .cc_in    (cc_q),
      .psw      (psw_word),
      .ia       (psw_ia),
      .ilc      (psw_ilc),
      .cc       (psw_cc)
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
  // Storage reads: the port returns the aligned 32-bit word containing the
  // byte address. S/360 is byte-addressed with the byte at the lowest address
  // held in bits 31-24, so the byte at offset k is bits [8*(3-k) +: 8]. Word
  // operands must be aligned; unaligned word operands are not modelled (see
  // the header note on specification exceptions).
  // ---------------------------------------------------------------------------
  logic [1:0]  rd_off;
  logic [4:0]  byte_sel;
  logic [31:0] read_word;
  logic [7:0]  read_byte;

  assign rd_off = (state == S_FETCH)  ? (ia_cur[1:0] + cnt[1:0])
                : (state == S_DECODE) ? ea[1:0]
                                      : ea_q[1:0];
  assign read_word = mem_rdata;
  // Byte offset 0 occupies bits 31-24, offset 3 bits 7-0.
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
      default: mem_addr = ia_cur;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Sequencer
  // ---------------------------------------------------------------------------
  logic [3:0] len_of_first_byte;
  assign len_of_first_byte = s360_len_bytes(read_byte[7:6]);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      ia_cur     <= RESET_IA;
      cnt        <= 3'd0;
      len        <= 4'd0;
      len_q      <= 4'd0;
      ilc_q      <= 2'd0;
      ea_q       <= 24'd0;
      opnd_q     <= 32'd0;
      str_q      <= 8'd0;
      wr_en_q    <= 1'b0;
      wr_idx_q   <= 4'd0;
      res_q      <= 32'd0;
      cc_we_q    <= 1'b0;
      cc_q       <= 2'd0;
      next_ia_q  <= RESET_IA;
      st_data_q  <= 32'd0;
      st_be_q    <= 4'd0;
      ovf_q      <= 1'b0;
      pc_check_q <= 1'b0;
      for (int i = 0; i < GPR_COUNT; i++) begin
        gpr[i] <= 32'd0;
      end
      for (int i = 0; i < 6; i++) begin
        ib[i] <= 8'd0;
      end
    end else begin
      unique case (state)
        S_IDLE: begin
          ia_cur <= psw_ia;
          cnt    <= 3'd0;
          len    <= 4'd0;
          state  <= S_FETCH;
        end

        S_FETCH: begin
          ib[cnt] <= read_byte;
          if (cnt == 3'd0) begin
            // The opcode byte fixes the instruction length; a two-byte RR
            // instruction still has a second byte holding R1|R2.
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
          if (!dec.valid) begin
            pc_check_q <= 1'b1;
            state      <= S_HALT;
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
          res_q     <= 32'd0;
          wr_en_q   <= 1'b0;
          cc_we_q   <= 1'b0;
          cc_q      <= psw_cc;
          st_data_q <= 32'd0;
          st_be_q   <= 4'd0;
          next_ia_q <= ia_cur + {20'd0, len_q};
          // Only instructions that can overflow latch the fixed-point overflow
          // flag. LR drives the adder as a pass-through and must not raise it.
          if (sets_cc && alu_ovf) begin
            ovf_q <= 1'b1;
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
            default: ;
          endcase
          if (sets_cc) begin
            cc_we_q <= 1'b1;
            cc_q    <= alu_cc;
          end
          if (is_branch && branch_taken) begin
            next_ia_q <= branch_target;
          end
          state <= (is_store) ? S_WRITE : S_COMMIT;
        end

        S_WRITE: begin
          state <= S_COMMIT;
        end

        S_COMMIT: begin
          if (wr_en_q) begin
            gpr[wr_idx_q] <= res_q;
          end
          state <= S_IDLE;
        end

        S_HALT: state <= S_HALT;

        default: state <= S_IDLE;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign psw              = psw_word;
  assign ovf_pending      = ovf_q;
  assign pc_check_pending = pc_check_q;
  assign halted           = (state == S_HALT);
  assign retire           = (state == S_COMMIT);
  assign retire_ia        = ia_cur;
  assign retire_len       = len_q;

  always_comb begin
    for (int i = 0; i < GPR_COUNT; i++) begin
      gpr_dbg[32*i +: 32] = gpr[i];
    end
  end

`ifdef FORMAL
  // Structural facts that hold in every state, including the initial one. The
  // temporal retirement contract lives in formal/ibm_s360_cpu_props.sv, which
  // guards its checks with a completed reset cycle.
  always_comb begin
    assert (!mem_we || (state == S_WRITE));
    assert (retire == (state == S_COMMIT));
    assert (!(retire && halted));
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
      .mem_we          (mem_we),
      .mem_wbe         (mem_wbe),
      .psw             (psw_word),
      .gpr_dbg         (gpr_dbg),
      .retire          (retire),
      .retire_len      (retire_len),
      .halted          (halted),
      .pc_check_pending(pc_check_q),
      .ovf_pending     (ovf_q)
  );
`endif

endmodule

`endif
