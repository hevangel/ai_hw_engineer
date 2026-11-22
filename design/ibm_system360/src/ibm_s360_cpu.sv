// IBM System/360 common CPU engine -- M3 core.
//
// Increments:
//   M1  fetch/decode/execute, 23 fixed-point/logical/branching instructions,
//       PSW, address generation.
//   M2  status switching (SPM, SSM, LPSW) and program interruptions 1, 2, 6, 8.
//   M3  the rest of the fixed-point group and the supervisor call:
//         halfword  LH, STH, AH, SH, CH, MH          (pp. 26-30)
//         multiply  MR, M                            (p. 30)
//         divide    DR, D                            (p. 31)
//         shifts    SLA, SRA, SLDA, SRDA             (pp. 32-34)
//         SVC with the supervisor-call interruption  (p. 74)
//       plus the specification exceptions of p. 34 (halfword not on a 16-bit
//       boundary, odd register for a 64-bit pair) and the fixed-point divide
//       exception (code 9, p. 31/34).
//
// Semantics that are easy to get wrong and are implemented from the manual:
//   - MR/M take the multiplicand from the odd register of the R1 pair, replace
//     the pair with the 64-bit product, and raise a specification exception
//     when R1 is odd; no overflow is possible (p. 30).
//   - MH multiplies a fullword by a sign-extended halfword and keeps the low
//     32 bits, without overflow indication (p. 32).
//   - DR/D divide the 64-bit even/odd pair by the divisor, placing the quotient
//     in the even register and the remainder in the odd register; the dividend
//     is unchanged when the quotient does not fit, including division by zero
//     (pp. 31, 34).
//   - Shift amounts are the low six bits of the second-operand address, which
//     is not used to address storage (pp. 32-34). SLA/SLDA keep the sign bit
//     and report overflow when a bit unlike the sign leaves the integer field.
//   - SVC places instruction bits 8-15 in old-PSW bits 24-31 (bits 16-23 are
//     zero) and uses the supervisor-call old/new PSWs at 0x20 and 0x60 (p. 74).
//
// Storage interface: combinational read of the aligned word, one-cycle write.
// Access timing, interleaving and channel contention are not modelled.
//
// Not implemented: protection keys and storage protection, DAT, addressing
// exceptions, external/I/O/machine-check interruptions, EXECUTE, decimal,
// floating point, SS-format instructions and the character/logical group that
// is not yet in the table.
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

  localparam logic [23:0] PROGRAM_OLD_PSW     = 24'h00_0028;
  localparam logic [23:0] PROGRAM_NEW_PSW     = 24'h00_0068;
  localparam logic [23:0] SUPERVISOR_OLD_PSW  = 24'h00_0020;
  localparam logic [23:0] SUPERVISOR_NEW_PSW  = 24'h00_0060;

  localparam logic [15:0] CODE_OPERATION   = 16'd1;
  localparam logic [15:0] CODE_PRIVILEGED  = 16'd2;
  localparam logic [15:0] CODE_SPECIF      = 16'd6;
  localparam logic [15:0] CODE_OVERFLOW    = 16'd8;
  localparam logic [15:0] CODE_DIVIDE      = 16'd9;
  localparam logic [15:0] CODE_EXECUTE     = 16'd3;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  typedef enum logic [4:0] {
    S_CHECK     = 5'd0,
    S_FETCH     = 5'd1,
    S_DECODE    = 5'd2,
    S_EXEC      = 5'd3,
    S_WRITE     = 5'd4,
    S_COMMIT    = 5'd5,
    S_INT_OLD0  = 5'd6,
    S_INT_OLD1  = 5'd7,
    S_INT_NEW0  = 5'd8,
    S_INT_NEW1  = 5'd9,
    S_INT_LOAD  = 5'd10,
    S_LPSW_LO   = 5'd11,
    S_LPSW_HI   = 5'd12,
    S_LPSW_LOAD = 5'd13,
    S_SS_A      = 5'd14,  // read first operand byte
    S_SS_B      = 5'd15,  // read second operand byte (or the translate-table byte)
    S_SS_C      = 5'd16   // merge/store or compare, then step the loop
  } state_e;

  state_e state;

  logic [31:0] gpr [0:15];

  logic [23:0] ia_cur;
  logic [2:0]  cnt;
  logic [3:0]  len;
  logic [7:0]  ib [0:5];

  logic [23:0] ea_q;
  logic [31:0] opnd_q;
  logic [15:0] opnd_half_q;
  logic [7:0]  str_q;
  logic [3:0]  len_q;
  logic [1:0]  ilc_q;

  logic        wr_en_q;
  logic [3:0]  wr_idx_q;
  logic [31:0] res_q;
  logic        wr_en2_q;
  logic [3:0]  wr_idx2_q;
  logic [31:0] res2_q;
  logic        cc_we_q;
  logic [1:0]  cc_q;
  logic [23:0] next_ia_q;

  logic [31:0] st_data_q;
  logic [3:0]  st_be_q;

  logic        pmask_en_q;
  logic [3:0]  pmask_q;
  logic        spm_cc_en_q;
  logic [1:0]  spm_cc_q;
  logic        sysmask_en_q;
  logic [7:0]  sysmask_q;

  // EXECUTE state: the EX instruction remembers its own address, the return
  // address, and the byte ORed into the subject instruction.
  logic        ex_active_q;
  logic [23:0] ex_ia_q;
  logic [23:0] ex_return_ia_q;
  logic [7:0]  ex_byte_q;

  // SS-format loop state.
  logic [7:0]  ss_len_q;
  logic [23:0] ss_addr1_q;
  logic [23:0] ss_addr2_q;
  logic [8:0]  ss_i_q;
  logic [7:0]  ss_b1_q;
  logic [7:0]  ss_b2_q;

  logic [15:0] int_code_q;
  logic [63:0] int_psw_q;
  logic        int_pending_q;
  logic [23:0] int_old_addr_q;
  logic [23:0] int_new_addr_q;
  logic        ovf_int_q;
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
  logic [3:0]  r2_f;
  logic [3:0]  b_f;
  logic [11:0] d_f;
  logic [7:0]  i2_f;

  assign r1_f = s360_r1(b1);
  assign r2_f = s360_r2_or_x2(b1);
  assign b_f  = s360_b(b2);
  assign d_f  = s360_d(b2, b3);
  assign i2_f = b1;

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

  // SS-format address pair: B1|D1 in the second halfword, B2|D2 in the third.
  logic [23:0] ss_addr1;
  logic [23:0] ss_addr2;
  ibm_s360_addr u_addr_ss1 (
      .b_field(ib[2][7:4]),
      .x_field (4'd0),
      .b_val   (gpr[ib[2][7:4]]),
      .x_val   (32'd0),
      .disp    ({ib[2][3:0], ib[3]}),
      .addr    (ss_addr1)
  );
  ibm_s360_addr u_addr_ss2 (
      .b_field(ib[4][7:4]),
      .x_field (4'd0),
      .b_val   (gpr[ib[4][7:4]]),
      .x_val   (32'd0),
      .disp    ({ib[4][3:0], ib[5]}),
      .addr    (ss_addr2)
  );

  // ---------------------------------------------------------------------------
  // Operation classification
  // ---------------------------------------------------------------------------
  logic is_halfword_op;   // LH STH AH SH CH MH: halfword operand in storage
  logic is_pair_op;       // MR DR SLDA SRDA: R1 must be even
  logic is_divide_op;     // DR D
  logic is_shift_op;      // SLA SRA SLDA SRDA
  logic is_shift_double;
  logic is_addsub;        // ALU add/subtract that can overflow
  logic ss_op;            // SS-format storage-to-storage operation

  always_comb begin
    is_halfword_op = (dec.op == OP_LH) || (dec.op == OP_STH) ||
                     (dec.op == OP_AH) || (dec.op == OP_SH) ||
                     (dec.op == OP_CH) || (dec.op == OP_MH);
    is_pair_op     = (dec.op == OP_MR) || (dec.op == OP_DR) ||
                     (dec.op == OP_SLDA) || (dec.op == OP_SRDA);
    is_divide_op   = (dec.op == OP_DR) || (dec.op == OP_D);
    is_shift_op    = (dec.op == OP_SLA) || (dec.op == OP_SRA) ||
                     (dec.op == OP_SLDA) || (dec.op == OP_SRDA);
    is_shift_double = (dec.op == OP_SLDA) || (dec.op == OP_SRDA);
    is_addsub      = (dec.op == OP_AR) || (dec.op == OP_A) ||
                     (dec.op == OP_SR) || (dec.op == OP_S) ||
                     (dec.op == OP_AH) || (dec.op == OP_SH);
    ss_op          = (dec.op == OP_MVC) || (dec.op == OP_MVN) ||
                     (dec.op == OP_MVZ) || (dec.op == OP_NC) ||
                     (dec.op == OP_OC) || (dec.op == OP_XC) ||
                     (dec.op == OP_CLC) || (dec.op == OP_TR) ||
                     (dec.op == OP_TRT);
  end

  // ---------------------------------------------------------------------------
  // Program-check detection (A22-6821-7 pp. 31, 34, 71-74)
  // ---------------------------------------------------------------------------
  logic lpsw_unaligned;
  logic privileged;
  logic odd_pair_register;
  logic odd_halfword_address;
  logic ex_odd_address;
  logic ex_of_ex;
  logic suppress;
  logic [15:0] suppress_code;

  assign privileged = (dec.op == OP_LPSW) || (dec.op == OP_SSM);
  assign lpsw_unaligned = (dec.op == OP_LPSW) && (ea[2:0] != 3'b000);
  assign odd_pair_register = is_pair_op && r1_f[0];
  assign odd_halfword_address = is_halfword_op && ea[0];
  assign ex_odd_address = (dec.op == OP_EX) && ea[0];
  assign ex_of_ex      = (dec.op == OP_EX) && ex_active_q;

  always_comb begin
    suppress      = 1'b0;
    suppress_code = 16'd0;
    if (!dec.valid) begin
      suppress      = 1'b1;
      suppress_code = CODE_OPERATION;
    end else if (privileged && psw_problem) begin
      suppress      = 1'b1;
      suppress_code = CODE_PRIVILEGED;
    end else if (ex_of_ex) begin
      suppress      = 1'b1;
      suppress_code = CODE_EXECUTE;
    end else if (lpsw_unaligned || odd_pair_register || odd_halfword_address ||
                 ex_odd_address) begin
      suppress      = 1'b1;
      suppress_code = CODE_SPECIF;
    end
  end

  logic [63:0] int_psw_suppressed;
  assign int_psw_suppressed = {psw_word[63:48], suppress_code,
                               ex_active_q ? 2'd2 : s360_ilc(dec.fmt),
                               psw_word[29:24],
                               ex_active_q ? ex_return_ia_q
                                           : (ia_cur + {20'd0, len})};

  // ---------------------------------------------------------------------------
  // PSW
  // ---------------------------------------------------------------------------
  logic [63:0] psw_word;
  logic [23:0] psw_ia;
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
  logic        sets_alu_cc;
  logic        is_store;
  logic        is_branch;

  always_comb begin
    alu_op     = ALU_ADD;
    sets_alu_cc = 1'b0;
    is_store   = 1'b0;
    is_branch  = 1'b0;
    unique case (dec.op)
      OP_LR:  alu_op = ALU_ADD;
      OP_LTR: begin alu_op = ALU_TEST; sets_alu_cc = 1'b1; end
      OP_AR, OP_A, OP_AH: begin alu_op = ALU_ADD; sets_alu_cc = 1'b1; end
      OP_SR, OP_S, OP_SH: begin alu_op = ALU_SUB; sets_alu_cc = 1'b1; end
      OP_CR, OP_C, OP_CH: begin alu_op = ALU_CMP; sets_alu_cc = 1'b1; end
      OP_CLR, OP_CL: begin alu_op = ALU_CLR; sets_alu_cc = 1'b1; end
      OP_NR, OP_N: begin alu_op = ALU_AND; sets_alu_cc = 1'b1; end
      OP_OR, OP_O: begin alu_op = ALU_OR;  sets_alu_cc = 1'b1; end
      OP_XR, OP_X: begin alu_op = ALU_XOR; sets_alu_cc = 1'b1; end
      OP_CLI: begin alu_op = ALU_CLR; sets_alu_cc = 1'b1; end
      OP_ST, OP_STH, OP_STC: is_store = 1'b1;
      OP_MVI: is_store = 1'b1;
      OP_BC, OP_BCR: is_branch = 1'b1;
      default: ;
    endcase
  end

  logic [31:0] opnd_half_sx;
  assign opnd_half_sx = {{16{opnd_half_q[15]}}, opnd_half_q};

  always_comb begin
    if (dec.op == OP_CLI) begin
      alu_a = {24'd0, i2_f};
    end else if (dec.op == OP_LTR) begin
      alu_a = gpr[r2_f];
    end else begin
      alu_a = gpr[r1_f];
    end
  end

  always_comb begin
    if (dec.op == OP_CLI) begin
      alu_b = {24'd0, str_q};
    end else if (is_halfword_op && (dec.op != OP_MH)) begin
      alu_b = opnd_half_sx;
    end else if (dec.fmt == FMT_RR) begin
      alu_b = gpr[r2_f];
    end else begin
      alu_b = opnd_q;
    end
  end

  ibm_s360_alu u_alu (
      .op (alu_op), .a (alu_a), .b (alu_b),
      .y (alu_y), .cc (alu_cc), .ovf (alu_ovf)
  );

  // ---------------------------------------------------------------------------
  // Multiply, divide and shift datapaths
  // ---------------------------------------------------------------------------
  // Multiplier operand: the storage word for M, the R2 register for MR, or the
  // sign-extended halfword for MH.
  logic [31:0] mul_operand;
  assign mul_operand = (dec.op == OP_MH) ? opnd_half_sx
                     : (dec.fmt == FMT_RR) ? gpr[r2_f]
                                           : opnd_q;

  // MR/M: multiplicand in the odd register of the pair, product replaces the
  // pair. MH: multiplicand is R1 and only the low 32 bits of the product are
  // kept.
  logic signed [31:0] mul_multiplicand;
  assign mul_multiplicand = (dec.op == OP_MH) ? $signed(gpr[r1_f])
                                              : $signed(gpr[r1_f | 4'd1]);
  logic signed [63:0] mul_product;
  assign mul_product = mul_multiplicand * $signed(mul_operand);

  // DR/D: 64-bit dividend in the pair, 32-bit divisor, quotient in the even
  // register and remainder in the odd register.
  logic signed [63:0] div_dividend;
  logic signed [63:0] div_divisor;
  logic signed [63:0] div_quotient;
  // Only the low 32 bits of the remainder are architecturally visible: the
  // remainder replaces the odd register as a 32-bit signed value (p. 31).
  /* verilator lint_off UNUSEDSIGNAL */
  logic signed [63:0] div_remainder64;
  /* verilator lint_on UNUSEDSIGNAL */
  logic signed [31:0] div_remainder;
  logic               div_overflow;

  // Divisor: the R2 register for DR, the storage word for D.
  logic [31:0] div_divisor_word;
  assign div_divisor_word = (dec.fmt == FMT_RR) ? gpr[r2_f] : opnd_q;

  assign div_dividend    = $signed({gpr[r1_f], gpr[r1_f | 4'd1]});
  assign div_divisor     = $signed({{32{div_divisor_word[31]}}, div_divisor_word});
  assign div_quotient    = (div_divisor == 64'sd0) ? 64'sd0 : div_dividend / div_divisor;
  assign div_remainder64 = (div_divisor == 64'sd0) ? 64'sd0 : div_dividend % div_divisor;
  assign div_remainder   = div_remainder64[31:0];
  assign div_overflow    = (div_divisor == 64'sd0) ||
                           (div_quotient > 64'sd2147483647) ||
                           (div_quotient < -64'sd2147483648);

  // Shifts: the amount is the low six bits of the second-operand address.
  logic [5:0]  shift_count;
  assign shift_count = ea_q[5:0];

  logic [95:0]  sla_wide;
  logic [127:0] slda_wide;
  logic         sla_ovf;
  logic         slda_ovf;
  logic [31:0]  sla_result;
  logic [63:0]  slda_result;
  logic [31:0]  sra_result;
  logic [63:0]  srda_result;

  assign sla_wide  = {65'd0, gpr[r1_f][30:0]} << shift_count;
  assign sla_ovf   = |(sla_wide[95:31] ^ {65{gpr[r1_f][31]}});
  assign sla_result = {gpr[r1_f][31], sla_wide[30:0]};

  assign slda_wide = {65'd0, gpr[r1_f][30:0], gpr[r1_f | 4'd1]} << shift_count;
  assign slda_ovf  = |(slda_wide[127:63] ^ {65{gpr[r1_f][31]}});
  assign slda_result = {gpr[r1_f][31], slda_wide[62:0]};

  assign sra_result  = $signed(gpr[r1_f]) >>> shift_count;
  assign srda_result = $signed({gpr[r1_f], gpr[r1_f | 4'd1]}) >>> shift_count;

  // Condition code for a shift result: zero, negative, positive, overflow.
  logic [1:0] shift_cc;
  logic [63:0] shift_result64;
  logic        shift_ovf;

  always_comb begin
    shift_result64 = is_shift_double ? ((dec.op == OP_SLDA) ? slda_result : srda_result)
                                     : {32'd0, ((dec.op == OP_SLA) ? sla_result : sra_result)};
    shift_ovf = ((dec.op == OP_SLA) && sla_ovf) || ((dec.op == OP_SLDA) && slda_ovf);
    shift_cc  = shift_ovf ? 2'd3
              : (shift_result64 == 64'd0) ? 2'd0
              : shift_result64[31] ? 2'd1 : 2'd2;
  end

  // ---------------------------------------------------------------------------
  // Branch decision (A22-6821-7 p. 74)
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
  // Storage reads
  // ---------------------------------------------------------------------------
  logic [1:0]  rd_off;
  logic [4:0]  byte_sel;
  logic [31:0] read_word;
  logic [7:0]  read_byte;

  // Current byte addresses of the SS loop.
  logic [23:0] ss_a1_cur;
  logic [23:0] ss_a2_cur;
  assign ss_a1_cur = ss_addr1_q + {15'd0, ss_i_q};
  assign ss_a2_cur = ss_addr2_q + {15'd0, ss_i_q};
  // TRANSLATE reads its function byte at table + argument, where the argument
  // is the byte read in the previous phase (p. 57).
  logic [23:0] ss_table_addr;
  assign ss_table_addr = ss_addr2_q + {16'd0, ss_b1_q};

  assign rd_off = (state == S_FETCH)  ? (ia_cur[1:0] + cnt[1:0])
                : (state == S_DECODE) ? ea[1:0]
                : (state == S_SS_A)   ? ss_a1_cur[1:0]
                : (state == S_SS_B)   ? ss_read_b_addr[1:0]
                : (state == S_SS_C)   ? ss_a1_cur[1:0]
                                      : ea_q[1:0];
  logic [23:0] ss_read_b_addr;
  assign ss_read_b_addr = ((dec.op == OP_TR) || (dec.op == OP_TRT)) ? ss_table_addr
                                                                    : ss_a2_cur;

  assign read_word = mem_rdata;
  assign byte_sel = (5'd3 - {3'b000, rd_off}) << 3;
  assign read_byte = mem_rdata[byte_sel +: 8];

  // Halfword at the decoded address (even).
  logic [15:0] half_at_ea;
  assign half_at_ea = ea[1] ? read_word[15:0] : read_word[31:16];

  // SS-format merge and write qualifier.
  logic [7:0] ss_merged_byte;
  logic       ss_writes;

  always_comb begin
    unique case (dec.op)
      OP_MVN:  ss_merged_byte = {ss_b1_q[7:4], ss_b2_q[3:0]};  // numerics
      OP_MVZ:  ss_merged_byte = {ss_b2_q[7:4], ss_b1_q[3:0]};  // zones
      OP_NC:   ss_merged_byte = ss_b1_q & ss_b2_q;
      OP_OC:   ss_merged_byte = ss_b1_q | ss_b2_q;
      OP_XC:   ss_merged_byte = ss_b1_q ^ ss_b2_q;
      OP_TR:   ss_merged_byte = ss_b2_q;   // translated function byte
      default: ss_merged_byte = ss_b2_q;                        // MVC and others
    endcase
    ss_writes = (dec.op == OP_MVC) || (dec.op == OP_MVN) || (dec.op == OP_MVZ) ||
                (dec.op == OP_NC) || (dec.op == OP_OC) || (dec.op == OP_XC) ||
                (dec.op == OP_TR);
  end

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
        mem_addr  = int_old_addr_q;
        mem_we    = 1'b1;
        mem_wdata = int_psw_q[63:32];
        mem_wbe   = 4'hF;
      end
      S_INT_OLD1: begin
        mem_addr  = int_old_addr_q + 24'd4;
        mem_we    = 1'b1;
        mem_wdata = int_psw_q[31:0];
        mem_wbe   = 4'hF;
      end
      S_SS_A: mem_addr = ss_a1_cur;
      S_SS_B: mem_addr = ss_read_b_addr;
      S_SS_C: begin
        mem_addr  = ss_a1_cur;
        mem_we    = ss_writes;
        mem_wdata = {4{ss_merged_byte}};
        mem_wbe   = ss_writes ? (4'b1000 >> ss_a1_cur[1:0]) : 4'd0;
      end
      S_INT_NEW0: mem_addr = int_new_addr_q;
      S_INT_NEW1: mem_addr = int_new_addr_q + 24'd4;
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
      opnd_half_q  <= 16'd0;
      str_q        <= 8'd0;
      wr_en_q      <= 1'b0;
      wr_idx_q     <= 4'd0;
      res_q        <= 32'd0;
      wr_en2_q     <= 1'b0;
      wr_idx2_q    <= 4'd0;
      res2_q       <= 32'd0;
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
      ex_active_q    <= 1'b0;
      ex_ia_q        <= 24'd0;
      ex_return_ia_q <= 24'd0;
      ex_byte_q      <= 8'd0;
      ss_len_q     <= 8'd0;
      ss_addr1_q   <= 24'd0;
      ss_addr2_q   <= 24'd0;
      ss_i_q       <= 9'd0;
      ss_b1_q      <= 8'd0;
      ss_b2_q      <= 8'd0;
      int_code_q   <= 16'd0;
      int_psw_q    <= 64'd0;
      int_pending_q<= 1'b0;
      int_old_addr_q <= PROGRAM_OLD_PSW;
      int_new_addr_q <= PROGRAM_NEW_PSW;
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
          // EXECUTE ORs its I1 byte into bits 8-15 of the subject instruction.
          if (ex_active_q && (cnt == 3'd1)) begin
            ib[cnt] <= read_byte | ex_byte_q;
          end else begin
            ib[cnt] <= read_byte;
          end
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
            int_code_q     <= suppress_code;
            int_psw_q      <= int_psw_suppressed;
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
            state          <= S_CHECK;
          end else begin
            ea_q        <= ea;
            opnd_q      <= read_word;
            opnd_half_q <= half_at_ea;
            str_q       <= read_byte;
            len_q       <= len;
            ilc_q       <= s360_ilc(dec.fmt);
            state       <= S_EXEC;
          end
        end

        S_EXEC: begin
          res_q      <= 32'd0;
          wr_en_q    <= 1'b0;
          wr_en2_q   <= 1'b0;
          cc_we_q    <= 1'b0;
          cc_q       <= psw_cc;
          st_data_q  <= 32'd0;
          st_be_q    <= 4'd0;
          pmask_en_q <= 1'b0;
          spm_cc_en_q<= 1'b0;
          sysmask_en_q <= 1'b0;
          ovf_int_q  <= 1'b0;
          next_ia_q  <= ia_cur + {20'd0, len_q};

          // Fixed-point divide exception: the division is suppressed and the
          // dividend registers are unchanged (A22-6821-7 pp. 31, 34).
          if (is_divide_op && div_overflow) begin
            int_code_q     <= CODE_DIVIDE;
            int_psw_q      <= {psw_word[63:48], CODE_DIVIDE, ilc_q,
                               psw_word[29:24], (ia_cur + {20'd0, len_q})};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
            state          <= S_CHECK;
          end else if (dec.op == OP_SVC) begin
            // Supervisor-call interruption: instruction bits 8-15 become old
            // PSW bits 24-31, bits 16-23 are zero, old/new PSWs at 0x20/0x60.
            int_code_q     <= {8'h00, b1};
            int_psw_q      <= {psw_word[63:48], 8'h00, b1, ilc_q,
                               psw_word[29:24], (ia_cur + {20'd0, len_q})};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= SUPERVISOR_OLD_PSW;
            int_new_addr_q <= SUPERVISOR_NEW_PSW;
            state          <= S_CHECK;
          end else begin
            unique case (dec.op)
              OP_LR: begin
                wr_en_q  <= 1'b1;
                wr_idx_q <= r1_f;
                res_q    <= gpr[r2_f];
              end
              OP_LTR, OP_AR, OP_SR, OP_NR, OP_OR, OP_XR,
              OP_A, OP_S, OP_N, OP_O, OP_X,
              OP_AH, OP_SH: begin
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
              OP_LH: begin
                wr_en_q  <= 1'b1;
                wr_idx_q <= r1_f;
                res_q    <= opnd_half_sx;
              end
              OP_ST: begin
                st_data_q <= gpr[r1_f];
                st_be_q   <= 4'hF;
              end
              OP_STH: begin
                st_data_q <= ea_q[1] ? {16'd0, gpr[r1_f][15:0]}
                                     : {gpr[r1_f][15:0], 16'd0};
                st_be_q   <= ea_q[1] ? 4'b0011 : 4'b1100;
              end
              OP_MVI: begin
                st_data_q <= {4{i2_f}};
                st_be_q   <= 4'b1000 >> ea_q[1:0];
              end
              OP_MR, OP_M: begin
                wr_en_q   <= 1'b1;
                wr_idx_q  <= r1_f;
                res_q     <= mul_product[63:32];
                wr_en2_q  <= 1'b1;
                wr_idx2_q <= r1_f | 4'd1;
                res2_q    <= mul_product[31:0];
              end
              OP_MH: begin
                wr_en_q  <= 1'b1;
                wr_idx_q <= r1_f;
                res_q    <= mul_product[31:0];
              end
              OP_DR, OP_D: begin
                wr_en_q   <= 1'b1;
                wr_idx_q  <= r1_f;
                res_q     <= div_quotient[31:0];
                wr_en2_q  <= 1'b1;
                wr_idx2_q <= r1_f | 4'd1;
                res2_q    <= div_remainder;
              end
              OP_SLA, OP_SRA: begin
                wr_en_q  <= 1'b1;
                wr_idx_q <= r1_f;
                res_q    <= (dec.op == OP_SLA) ? sla_result : sra_result;
              end
              OP_SLDA, OP_SRDA: begin
                wr_en_q   <= 1'b1;
                wr_idx_q  <= r1_f;
                res_q     <= is_shift_double && (dec.op == OP_SLDA) ? slda_result[63:32]
                                                                   : srda_result[63:32];
                wr_en2_q  <= 1'b1;
                wr_idx2_q <= r1_f | 4'd1;
                res2_q    <= (dec.op == OP_SLDA) ? slda_result[31:0] : srda_result[31:0];
              end
              OP_TM: begin
                // Mask test on the byte read at S_DECODE (p. 56).
                cc_we_q <= 1'b1;
                cc_q    <= ((str_q & i2_f) == 8'd0) ? 2'd0
                         : ((str_q & i2_f) == i2_f) ? 2'd3
                                                    : 2'd1;
              end
              OP_IC: begin
                // Byte into bit positions 24-31 of R1, other bits unchanged.
                wr_en_q  <= 1'b1;
                wr_idx_q <= r1_f;
                res_q    <= {gpr[r1_f][31:8], str_q};
              end
              OP_STC: begin
                st_data_q <= {4{gpr[r1_f][7:0]}};
                st_be_q   <= 4'b1000 >> ea_q[1:0];
              end
              OP_MVC, OP_MVN, OP_MVZ, OP_NC, OP_OC, OP_XC, OP_CLC,
              OP_TR, OP_TRT: begin
                ss_len_q   <= ib[1];
                ss_addr1_q <= ss_addr1;
                ss_addr2_q <= ss_addr2;
                ss_i_q     <= 9'd0;
              end
              OP_EX: begin
                // Execute the subject instruction at the operand address with
                // the I1 byte ORed into its second byte; the PSW address
                // advances by EXECUTE's own length (p. 67).
                ex_active_q    <= 1'b1;
                ex_ia_q        <= ia_cur;
                ex_return_ia_q <= ia_cur + {20'd0, len_q};
                ex_byte_q      <= b1;
                ia_cur         <= ea_q;
                cnt            <= 3'd0;
              end
              OP_SPM: begin
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

            // Condition code: ALU operations and shifts set it; the shifts use
            // their own overflow and sign rules.
            if (is_shift_op) begin
              cc_we_q <= 1'b1;
              cc_q    <= shift_cc;
            end else if (sets_alu_cc) begin
              cc_we_q <= 1'b1;
              cc_q    <= alu_cc;
            end

            // Fixed-point overflow: add/subtract from the ALU, and left shifts.
            if ((is_addsub && alu_ovf) || (is_shift_op && shift_ovf)) begin
              ovf_q <= 1'b1;
              if (psw_pmask[0]) begin
                ovf_int_q <= 1'b1;
              end
            end

            if (is_branch && branch_taken) begin
              next_ia_q <= branch_target;
            end
            if (ex_active_q) begin
              // The subject instruction does not advance the PSW address; a
              // successful branch still takes effect, everything else resumes
              // after EXECUTE with ILC 2.
              next_ia_q <= branch_taken ? branch_target : ex_return_ia_q;
              ilc_q     <= 2'd2;
            end
            if (dec.op == OP_LPSW) begin
              state <= S_LPSW_LO;
            end else if (dec.op == OP_EX) begin
              state <= S_FETCH;
            end else if (ss_op) begin
              state <= S_SS_A;
            end else if (is_store) begin
              state <= S_WRITE;
            end else begin
              state <= S_COMMIT;
            end
          end
        end

        S_WRITE: state <= S_COMMIT;

        S_COMMIT: begin
          if (wr_en_q) begin
            gpr[wr_idx_q] <= res_q;
          end
          if (wr_en2_q) begin
            gpr[wr_idx2_q] <= res2_q;
          end
          if (ex_active_q) begin
            ex_active_q <= 1'b0;
          end
          if (ovf_int_q) begin
            int_code_q     <= CODE_OVERFLOW;
            int_psw_q      <= {psw_word[63:48], CODE_OVERFLOW, ilc_q, cc_q,
                               psw_word[27:24], next_ia_q};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
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

        S_SS_A: begin
          ss_b1_q <= read_byte;
          state   <= S_SS_B;
        end

        S_SS_B: begin
          ss_b2_q <= read_byte;
          state   <= S_SS_C;
        end

        S_SS_C: begin
          if (dec.op == OP_TRT) begin
            // The subject uses fixed general registers 1 and 2: the manual
            // names "general register 1" and "general register 2" for TRT and
            // the SS format has no R fields (p. 57).
            if (ss_b2_q != 8'd0) begin
              wr_en_q   <= 1'b1;
              wr_idx_q  <= 4'd1;
              res_q     <= {gpr[1][31:24], ss_a1_cur[23:0]};
              wr_en2_q  <= 1'b1;
              wr_idx2_q <= 4'd2;
              res2_q    <= {gpr[2][31:8], ss_b2_q};
              cc_we_q   <= 1'b1;
              cc_q      <= (ss_i_q == {1'b0, ss_len_q}) ? 2'd2 : 2'd1;
              state     <= S_COMMIT;
            end else if (ss_i_q == {1'b0, ss_len_q}) begin
              cc_we_q <= 1'b1;
              cc_q    <= 2'd0;
              state   <= S_COMMIT;
            end else begin
              ss_i_q <= ss_i_q + 9'd1;
              state  <= S_SS_A;
            end
          end else if (dec.op == OP_CLC) begin
            if (ss_b1_q != ss_b2_q) begin
              cc_we_q <= 1'b1;
              cc_q    <= (ss_b1_q < ss_b2_q) ? 2'd1 : 2'd2;
              state   <= S_COMMIT;
            end else if (ss_i_q == {1'b0, ss_len_q}) begin
              cc_we_q <= 1'b1;
              cc_q    <= 2'd0;
              state   <= S_COMMIT;
            end else begin
              ss_i_q <= ss_i_q + 9'd1;
              state  <= S_SS_A;
            end
          end else if (ss_i_q == {1'b0, ss_len_q}) begin
            state <= S_COMMIT;
          end else begin
            ss_i_q <= ss_i_q + 9'd1;
            state  <= S_SS_A;
          end
        end

        default: state <= S_CHECK;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Interruption-raise summary (observed by the formal properties)
`ifdef FORMAL
  // Interruption-raise summary, observed by the formal properties only.
  logic       int_raise;
  logic       int_raise_cc_same;
  logic [3:0] int_raise_len;

  assign int_raise = ((state == S_DECODE) && suppress) ||
                     ((state == S_EXEC) && ((is_divide_op && div_overflow) ||
                                            (dec.op == OP_SVC))) ||
                     ((state == S_COMMIT) && ovf_int_q);
  assign int_raise_cc_same = ((state == S_DECODE) && suppress) ||
                             ((state == S_EXEC) && ((is_divide_op && div_overflow) ||
                                                    (dec.op == OP_SVC)));
  assign int_raise_len = ((state == S_DECODE) && suppress) ? len : len_q;
`endif

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign ovf_pending   = ovf_q;
  assign int_code_dbg  = int_code_dbg_q;
  assign int_taken     = (state == S_INT_LOAD);
  assign in_wait_state = psw_wait;
  assign retire        = (state == S_COMMIT) || (state == S_LPSW_LOAD);
  // An EXECUTE retires as itself, not as the subject instruction it ran.
  assign retire_ia     = ex_active_q ? ex_ia_q : ia_cur;
  assign retire_len    = ex_active_q ? 4'd4 : len_q;

  always_comb begin
    for (int i = 0; i < GPR_COUNT; i++) begin
      gpr_dbg[32*i +: 32] = gpr[i];
    end
  end

`ifdef FORMAL
  // Structural facts that hold in every state, including the unconstrained
  // initial one. The temporal contracts live in formal/ibm_s360_cpu_props.sv.
  always_comb begin
    assert (!mem_we || (state == S_WRITE) || (state == S_SS_C) ||
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
      .wr_en2_q        (wr_en2_q),
      .suppress        (suppress),
      .suppress_code   (suppress_code),
      .len             (len),
      .int_raise       (int_raise),
      .int_raise_len   (int_raise_len),
      .int_raise_cc_same(int_raise_cc_same),
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
