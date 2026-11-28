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
//   M9  decimal conversions and arithmetic (pp. 31-32, 35-40):
//         conversions  PACK, UNPK, MVO               (pp. 39-40)
//         register     CVB, CVD                      (pp. 31-32)
//         arithmetic   ZAP, CP, AP, SP, MP, DP       (pp. 37-39)
//       with the data (7), decimal-overflow (10, mask bit 37) and
//       decimal-divide (11) program interruptions, and the correction of the
//       SET PROGRAM MASK bit order (register bits 2-3 -> CC, 4-7 -> program
//       mask, p. 72).
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
// Not implemented: SET STORAGE KEY/INSERT STORAGE KEY, instruction-fetch
// protection, DAT, I/O and machine-check interruptions, ED/EDMK and floating
// point.
`ifndef IBM_S360_CPU_SV
`define IBM_S360_CPU_SV

`timescale 1ns/1ps

module ibm_s360_cpu #(
    parameter logic [23:0] RESET_IA = 24'h00_0100,
    // Installed storage. A reference at or beyond this address raises an
    // addressing exception (A22-6821-7 p. 34, code 5).
    parameter logic [23:0] MEM_SIZE_BYTES = 24'h01_0000
) (
    input  logic        clk,
    input  logic        rst_n,
    // External-interruption request (interval timer). Held until taken.
    input  logic        ext_timer_req,
    // Storage-key array load port (test aid until SET STORAGE KEY exists).
    input  logic        key_we,
    input  logic [5:0]  key_block,
    input  logic [3:0]  key_data,
    input  logic        key_fetch_protect,
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
  localparam logic [15:0] CODE_PROTECTION  = 16'd4;
  localparam logic [15:0] CODE_ADDRESSING  = 16'd5;
  localparam logic [15:0] CODE_DATA        = 16'd7;
  localparam logic [15:0] CODE_DEC_OVERFLOW= 16'd10;
  localparam logic [15:0] CODE_DEC_DIVIDE  = 16'd11;
  localparam int KEY_BLOCKS = 64;   // 2 KiB blocks covering 128 KiB
  localparam logic [15:0] CODE_TIMER       = 16'h0080;
  localparam logic [23:0] EXTERNAL_OLD_PSW = 24'h00_0018;
  localparam logic [23:0] EXTERNAL_NEW_PSW = 24'h00_0058;

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
    S_SS_C      = 5'd16,  // merge/store or compare, then step the loop
    // Decimal datapath (M9). One fetch, compute or store step per state.
    S_DEC_A     = 5'd17,  // fetch an operand byte (or the CVB first word)
    S_DEC_B     = 5'd18,  // fetch the second operand byte (or CVB second word)
    S_DEC_C     = 5'd19,  // compute/store one byte, step the loop
    S_DEC_ST    = 5'd20,  // store one result byte from a register (no fetch)
    S_DEC_MP    = 5'd21,  // MP multiply step: product += A * b_j
    S_DEC_DIV   = 5'd22,  // DP bring-down plus trial-subtract step
    S_DEC_CVB   = 5'd23,  // CVB Horner conversion step
    S_DEC_CVD   = 5'd24   // CVD double-dabble step
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

  // ---------------------------------------------------------------------------
  // Decimal datapath (M9, A22-6821-7 pp. 31-32, 35-40)
  //
  // Packed fields are processed right to left, one byte at a time, exactly as
  // pp. 35-36 prescribe ("fetched right to left from storage, eight bits at a
  // time, just before they are processed ... placed in storage, eight bits at
  // a time, as soon as they are generated"), so overlapped operands produce
  // the architectural result. A field of n bytes holds digit positions
  // 0..2n-2 plus the sign nibble in the low nibble of its rightmost byte:
  // byte k>=1 carries digit 2k in its high nibble and digit 2k-1 in its low
  // nibble; byte 0 carries digit 0 high and the sign low.
  //
  // Captured operands are held digit-ordered: acc nibble i = digit i, so
  // result byte k>=1 is acc[8*(2k-1) +: 8] and byte 0 is {acc[3:0], sign}.
  // ---------------------------------------------------------------------------
  localparam int DEC_ACC_DIGITS = 32;  // covers a 16-byte field (31 digits)

  logic [4:0]  dec_n1_q;        // op1 field bytes (L1+1), up to 16
  logic [4:0]  dec_n2_q;        // op2 field bytes (L2+1), up to 16
  logic [23:0] dec_addr1_q;     // leftmost byte of operand 1
  logic [23:0] dec_addr2_q;     // leftmost byte of operand 2
  logic [4:0]  dec_k_q;         // byte index from the right (0 = rightmost)
  logic [2:0]  dec_phase_q;     // per-instruction phase counter
  logic [7:0]  dec_ba_q;        // fetched operand-1 byte
  logic [7:0]  dec_bb_q;        // fetched operand-2 byte
  logic [7:0]  dec_bb_prev_q;   // previous operand-2 byte (PACK/MVO)
  logic [3:0]  dec_lo_a_q;      // operand-1 rightmost low nibble (MVO)
  logic [3:0]  dec_s1_q;        // operand-1 sign class nibble
  logic [3:0]  dec_s2_q;        // operand-2 sign nibble (flipped for SP)
  logic        dec_carry_q;     // BCD carry (add) or borrow state
  logic        dec_big_a_q;     // magnitude of operand 1 is the larger
  logic        dec_diff_q;      // magnitudes differ (compare tracker)
  logic        dec_zero_q;      // true result magnitude is zero
  logic        dec_ovf_q;       // decimal overflow detected
  logic        dec_pass2_q;     // add-type: second (store) pass
  logic        dec_fin_q;       // add-type/compare: finalize cycle next
  logic        dec_div9_q;      // CVB result out of range -> code 9
  logic        dec_decovf_q;    // completed decimal overflow -> code 10
  logic [DEC_ACC_DIGITS*4-1:0] dec_acc1_q;  // operand-1 digits (multiplicand / dividend)
  logic [DEC_ACC_DIGITS*4-1:0] dec_prod_q;  // MP product / DP quotient digits
  logic [63:0] dec_acc2_q;      // operand-2 digits (multiplier / divisor)
  logic [71:0] dec_rem_q;       // DP remainder register (2n2+1 digits <= 17)
  logic [63:0] dec_dbl_q;       // CVB captured doubleword / CVD bcd register
  logic [55:0] dec_bin_q;       // CVB Horner accumulator / CVD binary input
  logic [5:0]  dec_step_q;      // MP j / DP p / CVB digit / CVD dabble counter
  logic [4:0]  dec_j_q;         // UNPK result index / DP trial counter

  logic        dec_ascii;       // PSW bit 12 (A): ASCII-8 preferred codes
  assign dec_ascii = psw_word[51];

  // Sign and digit validity (p. 36): digits 0000-1001; the sign position takes
  // 1010-1111, of which 1011 and 1101 are minus.
  function automatic logic dec_digit_ok(input logic [3:0] n);
    dec_digit_ok = (n <= 4'd9);
  endfunction
  function automatic logic dec_sign_ok(input logic [3:0] n);
    dec_sign_ok = (n >= 4'd10);
  endfunction
  function automatic logic dec_sign_minus(input logic [3:0] n);
    dec_sign_minus = (n == 4'd11) || (n == 4'd13);
  endfunction

  // Preferred result codes for the current PSW bit 12 (pp. 36, 39).
  function automatic logic [3:0] dec_pref_plus(input logic ascii);
    dec_pref_plus = ascii ? 4'hA : 4'hC;
  endfunction
  function automatic logic [3:0] dec_pref_minus(input logic ascii);
    dec_pref_minus = ascii ? 4'hB : 4'hD;
  endfunction
  function automatic logic [3:0] dec_pref_zone(input logic ascii);
    dec_pref_zone = ascii ? 4'h5 : 4'hF;
  endfunction

  // Whole-field reference permission. A decimal field is at most 16 bytes, so
  // it spans at most two 2 KiB protection blocks and its two end bytes cover
  // every byte of the field. The same bound holds for the character SS group
  // (at most 256 bytes) and the translate table (256 bytes).
  function automatic logic dec_range_perm(input logic [23:0] lo, input logic [23:0] hi,
                                          input logic store);
    if (store) begin
      dec_range_perm = store_permitted(lo) && store_permitted(hi);
    end else begin
      dec_range_perm = fetch_permitted(lo) && fetch_permitted(hi);
    end
  endfunction

  // Whole-field installed-storage check (two end bytes for a contiguous field).
  function automatic logic dec_range_in_mem(input logic [23:0] lo, input logic [23:0] hi);
    dec_range_in_mem = !out_of_range(lo) && !out_of_range(hi);
  endfunction

  // Digit i of a captured digit-ordered operand.
  logic [31:0] dec_step_i;
  assign dec_step_i = {26'd0, dec_step_q};
  // Yosys 0.69 cannot part-select a function result, so the DP trial
  // subtraction goes through a named signal.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [DEC_ACC_DIGITS*4-1:0] dec_div_sub;
  /* verilator lint_on UNUSEDSIGNAL */
  assign dec_div_sub = dec_sub({56'd0, dec_rem_q}, {64'd0, dec_acc2_q});
  function automatic logic [3:0] dec_dig(input logic [DEC_ACC_DIGITS*4-1:0] acc,
                                         input int i);
    dec_dig = acc[4*i +: 4];
  endfunction

  // Digit i of a packed 8-byte doubleword, nibble 15 being the sign.
  function automatic logic [3:0] dec_dbl_dig(input logic [63:0] w, input int i);
    dec_dbl_dig = w[4*i +: 4];
  endfunction

  // Magnitude comparison of two digit-ordered BCD registers, leading zeros
  // included (a >= b).
  function automatic logic dec_ge(input logic [DEC_ACC_DIGITS*4-1:0] a,
                                  input logic [DEC_ACC_DIGITS*4-1:0] b);
    logic gt, eq;
    gt = 1'b0;
    eq = 1'b1;
    for (int i = DEC_ACC_DIGITS-1; i >= 0; i--) begin
      if (eq && (a[4*i +: 4] != b[4*i +: 4])) begin
        gt = (a[4*i +: 4] > b[4*i +: 4]);
        eq = 1'b0;
      end
    end
    dec_ge = gt || eq;
  endfunction

  // BCD magnitude subtraction a - b with borrow, over DEC_ACC_DIGITS digits.
  function automatic logic [DEC_ACC_DIGITS*4-1:0] dec_sub(input logic [DEC_ACC_DIGITS*4-1:0] a,
                                                          input logic [DEC_ACC_DIGITS*4-1:0] b);
    logic       borrow;
    logic [4:0] t;
    borrow = 1'b0;
    for (int i = 0; i < DEC_ACC_DIGITS; i++) begin
      t = {1'b0, a[4*i +: 4]} - {1'b0, b[4*i +: 4]} - {4'd0, borrow};
      if (t[4]) begin
        t = t + 5'd10;
        borrow = 1'b1;
      end else begin
        borrow = 1'b0;
      end
      dec_sub[4*i +: 4] = t[3:0];
    end
  endfunction

  // MP multiply step: product += (A * m) shifted left by off digits. The
  // leading-zero data check of p. 38 keeps every partial sum below 10^(2n1-1),
  // so 32 digits never overflow.
  function automatic logic [DEC_ACC_DIGITS*4-1:0] dec_mul_step(
      input logic [DEC_ACC_DIGITS*4-1:0] p,
      input logic [DEC_ACC_DIGITS*4-1:0] a,
      input logic [3:0] m,
      input int off);
    logic [DEC_ACC_DIGITS*4-1:0] pp;
    logic [6:0] t;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [6:0] md, mc;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [3:0] c;
    logic [4:0] s;
    logic       cin;
    // Partial product A * m: per-digit 4x4 multiply with BCD carry. The digit
    // product is at most 9*9+8 = 89, so t fits seven bits.
    c = 4'd0;
    for (int i = 0; i < DEC_ACC_DIGITS; i++) begin
      t  = a[4*i +: 4] * m + {3'd0, c};
      md = t % 7'd10;
      mc = t / 7'd10;
      pp[4*i +: 4] = md[3:0];
      c = mc[3:0];
    end
    // Add the partial product, digit-shifted by off, into p with BCD carry.
    cin = 1'b0;
    for (int i = 0; i < DEC_ACC_DIGITS; i++) begin
      if (i >= off) begin
        s = {1'b0, p[4*i +: 4]} + {1'b0, pp[4*(i-off) +: 4]} + {4'd0, cin};
        dec_mul_step[4*i +: 4] = s[3:0];
        cin = (s >= 5'd10);
      end else begin
        dec_mul_step[4*i +: 4] = p[4*i +: 4];
      end
    end
  endfunction

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
  logic        ext_pending_q;   // timer request waiting for an unmasked entry

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
  logic dec_ss_op;        // decimal SS-format operation (L1/L2 length fields)
  logic dec_mp_dp;        // MULTIPLY/DECIMAL DIVIDE (specification checks)
  logic needs_operand_fetch;  // fetches a storage operand (not an instruction)
  logic needs_store;          // writes storage

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
    needs_operand_fetch =
        (dec.op == OP_L) || (dec.op == OP_A) || (dec.op == OP_S) ||
        (dec.op == OP_C) || (dec.op == OP_CL) || (dec.op == OP_N) ||
        (dec.op == OP_O) || (dec.op == OP_X) || (dec.op == OP_LH) ||
        (dec.op == OP_AH) || (dec.op == OP_SH) || (dec.op == OP_CH) ||
        (dec.op == OP_MH) || (dec.op == OP_CLI) || (dec.op == OP_TM) ||
        (dec.op == OP_SSM) || (dec.op == OP_LPSW) || (dec.op == OP_CVB);
    needs_store = (dec.op == OP_ST) || (dec.op == OP_STH) ||
                  (dec.op == OP_MVI) || (dec.op == OP_MVC) ||
                  (dec.op == OP_MVN) || (dec.op == OP_MVZ) ||
                  (dec.op == OP_NC) || (dec.op == OP_OC) ||
                  (dec.op == OP_XC) || (dec.op == OP_TR);
    ss_op          = (dec.op == OP_MVC) || (dec.op == OP_MVN) ||
                     (dec.op == OP_MVZ) || (dec.op == OP_NC) ||
                     (dec.op == OP_OC) || (dec.op == OP_XC) ||
                     (dec.op == OP_CLC) || (dec.op == OP_TR) ||
                     (dec.op == OP_TRT);
    dec_ss_op      = (dec.op == OP_PACK) || (dec.op == OP_UNPK) ||
                     (dec.op == OP_MVO)  || (dec.op == OP_ZAP) ||
                     (dec.op == OP_CP)   || (dec.op == OP_AP) ||
                     (dec.op == OP_SP)   || (dec.op == OP_MP) ||
                     (dec.op == OP_DP);
    dec_mp_dp      = (dec.op == OP_MP) || (dec.op == OP_DP);
  end

  // ---------------------------------------------------------------------------
  // Program-check detection (A22-6821-7 pp. 31, 34, 71-74)
  // ---------------------------------------------------------------------------
  // Storage keys: one 4-bit key and a fetch-protection bit per 2 KiB block
  // (A22-6821-7 pp. 68-70). Reset to zero, which marks every block
  // unprotected, so behaviour is unchanged until a test loads keys.
  logic [4:0] st_key [0:KEY_BLOCKS-1];

  logic [3:0] psw_key;
  assign psw_key = psw_word[55:52];

  /* verilator lint_off UNUSEDSIGNAL */
  function automatic logic [5:0] key_index(input logic [23:0] a);
    key_index = a[16:11];
  endfunction

  function automatic logic fetch_permitted(input logic [23:0] a);
    logic [4:0] k;
    k = st_key[key_index(a)];
    fetch_permitted = (k[3:0] == 4'd0) || (k[3:0] == psw_key) || !k[4];
  endfunction

  function automatic logic store_permitted(input logic [23:0] a);
    logic [4:0] k;
    k = st_key[key_index(a)];
    store_permitted = (k[3:0] == 4'd0) || (k[3:0] == psw_key);
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  // Any operand or instruction reference outside installed storage.
  function automatic logic out_of_range(input logic [23:0] a);
    out_of_range = (a >= MEM_SIZE_BYTES);
  endfunction

  logic operand_out_of_range;
  assign operand_out_of_range = out_of_range(ea);

  logic lpsw_unaligned;
  logic privileged;
  logic odd_pair_register;
  logic odd_halfword_address;
  logic ex_odd_address;
  logic ex_of_ex;
  logic suppress;
  logic [15:0] suppress_code;

  // Whole-field range check for SS operations, evaluated when the instruction
  // is about to start (deviation A-8: the core suppresses instead of
  // terminating part way).
  logic [23:0] ss_last1, ss_last2;
  logic        ss_range_bad;
  assign ss_last1 = ss_addr1 + {15'd0, ib[1]};
  assign ss_last2 = ss_addr2 + {15'd0, ib[1]};
  always_comb begin
    ss_range_bad = ss_op && (out_of_range(ss_addr1) || out_of_range(ss_last1) ||
                             out_of_range(ss_addr2) || out_of_range(ss_last2));
    if ((dec.op == OP_TR) || (dec.op == OP_TRT)) begin
      ss_range_bad = ss_range_bad || out_of_range(ss_addr2 + 24'h00_00FF);
    end
  end

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
    end else if (operand_out_of_range) begin
      suppress      = 1'b1;
      suppress_code = CODE_ADDRESSING;
    end else if (needs_operand_fetch && !fetch_permitted(ea)) begin
      // Operand fetch from a protected block with a different key (pp. 68-70).
      suppress      = 1'b1;
      suppress_code = CODE_PROTECTION;
    end else if (lpsw_unaligned || odd_pair_register || odd_halfword_address ||
                 ex_odd_address || cvb_cvd_unaligned) begin
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
      // The storage byte is the first operand and the immediate byte is the
      // second, so a low first operand gives CC 1 (p. 54).
      alu_a = {24'd0, str_q};
    end else if (dec.op == OP_LTR) begin
      alu_a = gpr[r2_f];
    end else begin
      alu_a = gpr[r1_f];
    end
  end

  always_comb begin
    if (dec.op == OP_CLI) begin
      alu_b = {24'd0, i2_f};
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
                : (state == S_DEC_A)  ? dec_rd_a_addr[1:0]
                : (state == S_DEC_B)  ? dec_rd_b_addr[1:0]
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

  // Whole-field protection for the character SS group. A field of at most 256
  // bytes spans at most two 2 KiB blocks, so its two end bytes cover it.
  logic ss_prot_bad;
  assign ss_prot_bad = ss_op &&
      ((ss_writes && !dec_range_perm(ss_addr1, ss_last1, 1'b1)) ||
       !dec_range_perm(ss_addr1, ss_last1, 1'b0) ||
       !dec_range_perm(ss_addr2, ss_last2, 1'b0) ||
       (((dec.op == OP_TR) || (dec.op == OP_TRT)) &&
        !dec_range_perm(ss_addr2, ss_addr2 + 24'h00_00FF, 1'b0)));

  // ---------------------------------------------------------------------------
  // Decimal field checks (pp. 34, 38-40), evaluated before the first byte.
  // ---------------------------------------------------------------------------
  logic [23:0] dec_last1, dec_last2;
  logic        dec_range_bad;
  logic        dec_prot_bad;
  logic        dec_spec_bad;
  assign dec_last1 = ss_addr1 + {20'd0, ib[1][7:4]};
  assign dec_last2 = ss_addr2 + {20'd0, ib[1][3:0]};
  always_comb begin
    dec_range_bad = dec_ss_op &&
        (!dec_range_in_mem(ss_addr1, dec_last1) ||
         !dec_range_in_mem(ss_addr2, dec_last2));
    // Store side: operand 1 of every decimal SS instruction except COMPARE
    // DECIMAL. Fetch side: operand 2 always; operand 1 also for the
    // instructions that read it (AP, SP, CP, MP, DP). MVO reads operand 1's
    // rightmost byte, which a store-permitted reference already covers.
    dec_prot_bad = dec_ss_op &&
        (((dec.op != OP_CP) && !dec_range_perm(ss_addr1, dec_last1, 1'b1)) ||
         (((dec.op == OP_AP) || (dec.op == OP_SP) || (dec.op == OP_CP) ||
           dec_mp_dp) && !dec_range_perm(ss_addr1, dec_last1, 1'b0)) ||
         !dec_range_perm(ss_addr2, dec_last2, 1'b0));
    // MULTIPLY/DECIMAL DIVIDE: a second-operand length code larger than seven
    // or not smaller than the first is a specification exception (pp. 38-39).
    dec_spec_bad = dec_mp_dp &&
        ((ib[1][3:0] > 4'd7) || (ib[1][3:0] >= ib[1][7:4]));
  end

  // CVB/CVD doubleword checks (pp. 31-32): the operand address must have its
  // three low-order bits zero, and the whole doubleword is referenced.
  logic        cvb_cvd_op;
  logic        cvb_cvd_unaligned;
  logic        cvb_cvd_range_bad;
  logic        cvb_cvd_prot_bad;
  assign cvb_cvd_op = (dec.op == OP_CVB) || (dec.op == OP_CVD);
  assign cvb_cvd_unaligned = cvb_cvd_op && (ea[2:0] != 3'b000);
  always_comb begin
    cvb_cvd_range_bad = cvb_cvd_op && !dec_range_in_mem(ea, ea + 24'd7);
    cvb_cvd_prot_bad  = (dec.op == OP_CVB) ? !dec_range_perm(ea, ea + 24'd7, 1'b0)
                                           : !dec_range_perm(ea, ea + 24'd7, 1'b1);
  end

  // ---------------------------------------------------------------------------
  // Decimal datapath combinational logic
  // ---------------------------------------------------------------------------
  // Byte j (0 = rightmost) of an n-byte field whose leftmost byte is `base`.
  function automatic logic [23:0] dec_byte_addr(input logic [23:0] base,
                                                input logic [4:0] n,
                                                input logic [4:0] j);
    dec_byte_addr = base + {19'd0, (n - 5'd1)} - {19'd0, j};
  endfunction

  logic [4:0] dec_n1_w, dec_n2_w;
  assign dec_n1_w = dec_n1_q;
  assign dec_n2_w = dec_n2_q;
  logic [4:0] dec_max_n;
  assign dec_max_n = (dec_n1_w > dec_n2_w) ? dec_n1_w : dec_n2_w;
  logic [31:0] dec_n1_i, dec_n2_i;
  assign dec_n1_i = {27'd0, dec_n1_w};
  assign dec_n2_i = {27'd0, dec_n2_w};
  logic [6:0] dec_qlen;        // DP quotient digit count 2(n1-n2)-1
  logic [4:0] dec_ndiff;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [7:0] dec_qlen_t;
  /* verilator lint_on UNUSEDSIGNAL */
  assign dec_ndiff  = dec_n1_w - dec_n2_w;
  assign dec_qlen_t = {1'b0, dec_ndiff, 1'b0} - 8'd1;
  assign dec_qlen   = dec_qlen_t[6:0];
  logic [5:0] dec_mp_lim;      // MP multiplier digit limit 2n2-2
  assign dec_mp_lim = {dec_n2_w, 1'b0} - 6'd2;

  // Read addressing and validity for S_DEC_A / S_DEC_B.
  logic [23:0] dec_rd_a_addr;
  logic        dec_rd_a_real;
  logic [23:0] dec_rd_b_addr;
  logic        dec_rd_b_real;
  always_comb begin
    dec_rd_a_addr = dec_addr1_q;
    dec_rd_a_real = 1'b0;
    unique case (dec.op)
      OP_PACK: begin
        // Result byte k consumes zoned bytes 2k-1 (A step) and 2k (B step);
        // byte 0 of the result consumes zoned byte 0 only.
        if (dec_k_q == 5'd0) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, 5'd0);
          dec_rd_a_real = 1'b1;
        end else if ((dec_k_q << 1) - 5'd1 < dec_n2_w) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, (dec_k_q << 1) - 5'd1);
          dec_rd_a_real = 1'b1;
        end
      end
      OP_UNPK: begin
        // Result byte 0 comes from packed byte 0; result bytes 2b-1 and 2b
        // come from packed byte b, so the loop advances one operand byte per
        // fetch and stores up to two result bytes from it (p. 39).
        if (dec_k_q < dec_n2_w) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q);
          dec_rd_a_real = 1'b1;
        end
      end
      OP_MVO: begin
        if (dec_phase_q == 3'd0) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, 5'd0);
          dec_rd_a_real = 1'b1;                 // operand-1 rightmost byte
        end else if (dec_k_q < dec_n2_w) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q);
          dec_rd_a_real = 1'b1;
        end
      end
      OP_ZAP: begin
        // Both passes scan operand 2 only; operand 1 is overwritten.
        if (dec_k_q < dec_n2_w) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q);
          dec_rd_a_real = 1'b1;
        end
      end
      OP_AP, OP_SP, OP_CP, OP_MP, OP_DP: begin
        if (dec_mp_dp && (dec_phase_q == 3'd1)) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q);
          dec_rd_a_real = 1'b1;                 // capture operand 2
        end else if (dec_k_q < dec_n1_w) begin
          dec_rd_a_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_k_q);
          dec_rd_a_real = 1'b1;
        end
      end
      OP_CVB: begin
        dec_rd_a_addr = ea_q;
        dec_rd_a_real = 1'b1;
      end
      default: ;
    endcase
  end
  always_comb begin
    dec_rd_b_addr = dec_addr2_q;
    dec_rd_b_real = 1'b0;
    unique case (dec.op)
      OP_PACK: begin
        if ((dec_k_q != 5'd0) && ((dec_k_q << 1) < dec_n2_w)) begin
          dec_rd_b_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q << 1);
          dec_rd_b_real = 1'b1;
        end
      end
      OP_AP, OP_SP, OP_CP: begin
        if (dec_k_q < dec_n2_w) begin
          dec_rd_b_addr = dec_byte_addr(dec_addr2_q, dec_n2_w, dec_k_q);
          dec_rd_b_real = 1'b1;
        end
      end
      OP_CVB: begin
        dec_rd_b_addr = ea_q + 24'd4;
        dec_rd_b_real = 1'b1;
      end
      default: ;
    endcase
  end

  // Store addressing for S_DEC_C / S_DEC_ST.
  logic [23:0] dec_store_addr;
  logic        dec_store_en;
  always_comb begin
    dec_store_addr = dec_addr1_q;
    dec_store_en   = 1'b0;
    unique case (dec.op)
      OP_PACK, OP_MVO: begin
        dec_store_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_k_q);
        dec_store_en   = 1'b1;
      end
      OP_UNPK: begin
        // The unpack loop stores result bytes 2b-1 and 2b from operand byte b;
        // dec_j_q holds the result index of the pending store.
        dec_store_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_j_q);
        dec_store_en   = 1'b1;
      end
      OP_AP, OP_SP: begin
        dec_store_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_k_q);
        dec_store_en   = dec_pass2_q && !dec_fin_q && (dec_k_q < dec_n1_w);
      end
      OP_ZAP: begin
        dec_store_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_k_q);
        dec_store_en   = dec_pass2_q && !dec_fin_q;
      end
      OP_MP, OP_DP: begin
        dec_store_addr = dec_byte_addr(dec_addr1_q, dec_n1_w, dec_k_q);
        dec_store_en   = (dec_phase_q == 3'd3);
      end
      OP_CVD: begin
        dec_store_addr = ea_q + {19'd0, (5'd7 - dec_k_q)};
        dec_store_en   = (dec_phase_q == 3'd1);
      end
      default: ;
    endcase
  end

  // Effective sign classes. SUBTRACT DECIMAL flips the second operand's sign
  // class after the operand is obtained (p. 37).
  logic dec_min1, dec_min2_eff, dec_min2_raw, dec_same_sign;
  assign dec_min1     = dec_sign_minus(dec_s1_q);
  assign dec_min2_raw = dec_sign_minus(dec_s2_q);
  assign dec_min2_eff = (dec.op == OP_SP) ? !dec_min2_raw : dec_min2_raw;
  assign dec_same_sign = (dec_min1 == dec_min2_eff);

  // Digit nibbles of the bytes fetched for the add-type scan. Byte 0 carries
  // digit 0 in its high nibble and the sign in its low nibble; byte k>=1
  // carries digit 2k high and digit 2k-1 low.
  logic [3:0] dec_a_lo, dec_a_hi, dec_b_lo, dec_b_hi;
  assign dec_a_lo = dec_ba_q[3:0];
  assign dec_a_hi = dec_ba_q[7:4];
  assign dec_b_lo = dec_bb_q[3:0];
  assign dec_b_hi = dec_bb_q[7:4];

  // Sign classes still unknown at byte 0: taken from the bytes being scanned.
  logic dec_min1_now, dec_min2_now, dec_same_now;
  assign dec_min1_now = (dec_k_q == 5'd0) ? dec_sign_minus(dec_a_lo) : dec_min1;
  assign dec_min2_now = (dec_k_q == 5'd0)
      ? ((dec.op == OP_SP) ? !dec_sign_minus(dec_b_lo) : dec_sign_minus(dec_b_lo))
      : dec_min2_eff;
  assign dec_same_now = (dec_min1_now == dec_min2_now);

  // Same-sign add of the current byte: digit 2k-1 (low nibbles) first, then
  // digit 2k (high nibbles); byte 0 contributes digit 0 only, so its carry
  // input is the registered carry rather than the low-nibble chain.
  logic [4:0] dec_t1, dec_t2;
  // The digit results hold 0-9; their bit 4 is unused by construction.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [4:0] dec_d1, dec_d2;
  /* verilator lint_on UNUSEDSIGNAL */
  logic       dec_c1, dec_c2;
  always_comb begin
    dec_t1 = {1'b0, dec_a_lo} + {1'b0, dec_b_lo} + {4'd0, dec_carry_q};
    dec_d1 = (dec_t1 >= 5'd10) ? (dec_t1 - 5'd10) : {1'b0, dec_t1[3:0]};
    dec_c1 = (dec_t1 >= 5'd10);
    dec_t2 = {1'b0, dec_a_hi} + {1'b0, dec_b_hi}
           + {4'd0, ((dec_k_q == 5'd0) ? dec_carry_q : dec_c1)};
    dec_d2 = (dec_t2 >= 5'd10) ? (dec_t2 - 5'd10) : {1'b0, dec_t2[3:0]};
    dec_c2 = (dec_t2 >= 5'd10);
  end

  // Different-sign pass 2: subtract the smaller magnitude from the larger.
  logic [3:0] dec_x_lo, dec_x_hi, dec_y_lo, dec_y_hi;
  assign dec_x_lo = dec_big_a_q ? dec_a_lo : dec_b_lo;
  assign dec_x_hi = dec_big_a_q ? dec_a_hi : dec_b_hi;
  assign dec_y_lo = dec_big_a_q ? dec_b_lo : dec_a_lo;
  assign dec_y_hi = dec_big_a_q ? dec_b_hi : dec_a_hi;
  logic [4:0] dec_s1t, dec_s2t;
  logic [3:0] dec_sd1, dec_sd2;
  logic       dec_sb1, dec_sb2;
  always_comb begin
    dec_s1t = {1'b0, dec_x_lo} - {1'b0, dec_y_lo} - {4'd0, dec_carry_q};
    if (dec_s1t[4]) begin
      dec_sd1 = dec_s1t[3:0] + 4'd10;
      dec_sb1 = 1'b1;
    end else begin
      dec_sd1 = dec_s1t[3:0];
      dec_sb1 = 1'b0;
    end
    dec_s2t = {1'b0, dec_x_hi} - {1'b0, dec_y_hi}
            - {4'd0, ((dec_k_q == 5'd0) ? dec_carry_q : dec_sb1)};
    if (dec_s2t[4]) begin
      dec_sd2 = dec_s2t[3:0] + 4'd10;
      dec_sb2 = 1'b1;
    end else begin
      dec_sd2 = dec_s2t[3:0];
      dec_sb2 = 1'b0;
    end
  end

  // Add-type operand-code validity for the byte being scanned (p. 40). ZAP
  // checks only the second operand (p. 37).
  logic dec_add_bad;
  always_comb begin
    if (dec.op == OP_ZAP) begin
      dec_add_bad = (dec_k_q == 5'd0)
          ? (!dec_digit_ok(dec_b_hi) || !dec_sign_ok(dec_b_lo))
          : (!dec_digit_ok(dec_b_lo) || !dec_digit_ok(dec_b_hi));
    end else begin
      dec_add_bad = (dec_k_q == 5'd0)
          ? (!dec_digit_ok(dec_a_hi) || !dec_digit_ok(dec_b_hi) ||
             !dec_sign_ok(dec_a_lo) || !dec_sign_ok(dec_b_lo))
          : (!dec_digit_ok(dec_a_lo) || !dec_digit_ok(dec_a_hi) ||
             !dec_digit_ok(dec_b_lo) || !dec_digit_ok(dec_b_hi));
    end
  end

  // Preferred result signs. MP/DP derive them from the captured sign classes;
  // CVD from the converted register value; the DP remainder keeps the dividend
  // sign even when it is zero (p. 39).
  logic [3:0] dec_sign_mp, dec_sign_rem, dec_sign_cvd;
  assign dec_sign_mp  = (dec_min1 != dec_min2_eff)
      ? dec_pref_minus(dec_ascii) : dec_pref_plus(dec_ascii);
  assign dec_sign_rem = dec_min1 ? dec_pref_minus(dec_ascii)
                                 : dec_pref_plus(dec_ascii);
  assign dec_sign_cvd = dec_s1_q[0] ? dec_pref_minus(dec_ascii)
                                    : dec_pref_plus(dec_ascii);

  // Result byte for the current store step (S_DEC_C / S_DEC_ST). Byte k>=1 of
  // a digit-ordered register occupies bits 4*(2k-1) +: 8 (digits 2k-1 low,
  // 2k high); byte 0 is {digit 0, sign}.
  logic [3:0] dec_res_sign;   // preferred sign/zone nibble of result byte 0
  logic [7:0] dec_res_byte;
  logic       dec_res_minus;  // true result sign class (add-type)
  always_comb begin
    dec_res_minus = 1'b0;
    unique case (dec.op)
      OP_ZAP:   dec_res_minus = dec_min2_now;
      OP_AP,
      OP_SP:    dec_res_minus = dec_same_now ? dec_min1_now
                                             : (dec_big_a_q ? dec_min1_now : dec_min2_now);
      default:  dec_res_minus = 1'b0;
    endcase
    // An unoverflowed zero result is positive; an overflow keeps the sign of
    // the true result (pp. 37, 40).
    dec_res_sign = (dec.op == OP_UNPK)
        ? dec_pref_zone(dec_ascii)
        : (((dec.op == OP_ZAP) || (dec.op == OP_AP) || (dec.op == OP_SP))
            ? ((dec_zero_q && !dec_ovf_q) ? dec_pref_plus(dec_ascii)
             : (dec_res_minus ? dec_pref_minus(dec_ascii) : dec_pref_plus(dec_ascii)))
            : 4'h0);
    unique case (dec.op)
      OP_PACK: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_bb_q[3:0], dec_bb_q[7:4]}
          : {dec_bb_prev_q[3:0], dec_bb_q[3:0]};
      // Zoned byte 0 carries the sign in the zone (high) position and the
      // digit low (Figure 9, p. 35), so it is the nibble swap of packed
      // byte 0, which stores {digit, sign}.
      OP_UNPK: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_bb_q[3:0], dec_bb_q[7:4]}
          : {dec_res_sign, (dec_pass2_q ? dec_bb_q[7:4] : dec_bb_q[3:0])};
      OP_MVO: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_bb_q[3:0], dec_lo_a_q}
          : {dec_bb_q[3:0], dec_bb_prev_q[7:4]};
      OP_ZAP: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_b_hi, dec_res_sign}
          : {dec_b_hi, dec_b_lo};
      OP_AP, OP_SP: dec_res_byte = (dec_k_q == 5'd0)
          ? {(dec_same_now ? dec_d2[3:0] : dec_sd2), dec_res_sign}
          : {(dec_same_now ? dec_d2[3:0] : dec_sd2),
             (dec_same_now ? dec_d1[3:0] : dec_sd1)};
      OP_MP: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_prod_q[3:0], dec_sign_mp}
          : dec_prod_q[4*(2*dec_k_q - 1) +: 8];
      OP_DP: dec_res_byte = (dec_k_q < dec_n2_w)
          ? ((dec_k_q == 5'd0) ? {dec_rem_q[3:0], dec_sign_rem}
                               : dec_rem_q[4*(2*dec_k_q - 1) +: 8])
          : (((dec_k_q - dec_n2_w) == 5'd0)
              ? {dec_prod_q[3:0], dec_sign_mp}
              : dec_prod_q[4*(2*(dec_k_q - dec_n2_w) - 1) +: 8]);
      OP_CVD: dec_res_byte = (dec_k_q == 5'd0)
          ? {dec_dbl_q[3:0], dec_sign_cvd}
          : dec_dbl_q[4*(2*dec_k_q - 1) +: 8];
      default: dec_res_byte = 8'h00;
    endcase
  end

  // Digit i of the CVB doubleword captured as {word at ea, word at ea+4}, with
  // byte j from the right at w[8*j +: 8] (p. 31).
  function automatic logic [3:0] dec_cvb_dig(input logic [63:0] w, input int i);
    if (i == 0) begin
      dec_cvb_dig = w[4 +: 4];
    end else if (i[0] == 1'b0) begin
      dec_cvb_dig = w[8*(i/2) + 4 +: 4];
    end else begin
      dec_cvb_dig = w[8*((i+1)/2) +: 4];
    end
  endfunction

  // Captured-operand validity for MP/DP (p. 40) and the MP leading-zero rule:
  // the multiplicand must have high-order zero digits for the whole
  // multiplier field size (p. 38).
  logic dec_cap1_bad, dec_cap2_bad, dec_mp_lead_ok, dec_dv_zero;
  always_comb begin
    dec_cap1_bad = !dec_sign_ok(dec_s1_q);
    for (int i = 0; i < DEC_ACC_DIGITS; i++) begin
      if ((i == 0) || (i <= 2*dec_n1_i - 2)) begin
        dec_cap1_bad |= !dec_digit_ok(dec_acc1_q[4*i +: 4]);
      end
    end
    dec_cap2_bad = !dec_sign_ok(dec_s2_q);
    for (int i = 0; i < 16; i++) begin
      if ((i == 0) || (i <= 2*dec_n2_i - 2)) begin
        dec_cap2_bad |= !dec_digit_ok(dec_acc2_q[4*i +: 4]);
      end
    end
    dec_mp_lead_ok = 1'b1;
    for (int i = 0; i < DEC_ACC_DIGITS; i++) begin
      if ((i >= 2*(dec_n1_i - dec_n2_i)) && (i <= 2*dec_n1_i - 2)) begin
        dec_mp_lead_ok &= (dec_acc1_q[4*i +: 4] == 4'd0);
      end
    end
    dec_dv_zero = 1'b1;
    for (int i = 0; i < 16; i++) begin
      if (i <= 2*dec_n2_i - 2) begin
        dec_dv_zero &= (dec_acc2_q[4*i +: 4] == 4'd0);
      end
    end
  end

  // CVB operand validity (p. 31): digits 0-9 and a valid sign nibble. In
  // S_DEC_B the second word is being captured, so validation reads the
  // composite of the first word and the incoming second word.
  logic [63:0] dec_cvb_word;
  logic dec_cvb_bad;
  assign dec_cvb_word = (state == S_DEC_B) ? {dec_dbl_q[63:32], read_word}
                                            : dec_dbl_q;
  always_comb begin
    dec_cvb_bad = !dec_sign_ok(dec_cvb_word[3:0]);
    for (int i = 0; i < 16; i++) begin
      if (i <= 14) begin
        dec_cvb_bad |= !dec_digit_ok(dec_cvb_dig(dec_cvb_word, i));
      end
    end
  end

  // CVD double-dabble adjustment (add 3 to every nibble of 5 or more). The
  // shift below discards the top bit by design.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [63:0] dec_dbl_adj;
  /* verilator lint_on UNUSEDSIGNAL */
  always_comb begin
    for (int i = 0; i < 16; i++) begin
      dec_dbl_adj[4*i +: 4] = (dec_dbl_q[4*i +: 4] >= 4'd5)
          ? dec_dbl_q[4*i +: 4] + 4'd3 : dec_dbl_q[4*i +: 4];
    end
  end

  // CVB Horner digit and converted value.
  logic [55:0] dec_cvb_next;
  assign dec_cvb_next = dec_bin_q * 7'd10 + {52'd0, dec_cvb_dig(dec_dbl_q, dec_step_i)};
  logic [31:0] dec_cvb_val;
  logic        dec_cvb_ovf;
  // The stored result is the low 32 bits of the signed value (p. 31), which
  // two's-complement arithmetic produces directly in 32 bits.
  assign dec_cvb_val = dec_min1 ? (32'd0 - dec_bin_q[31:0]) : dec_bin_q[31:0];
  assign dec_cvb_ovf = dec_min1 ? ({8'd0, dec_bin_q} > 64'd2147483648)
                                : ({8'd0, dec_bin_q} > 64'd2147483647);

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
      S_DEC_A: mem_addr = dec_rd_a_addr;
      S_DEC_B: mem_addr = dec_rd_b_addr;
      S_DEC_C,
      S_DEC_ST: begin
        mem_addr  = dec_store_addr;
        mem_we    = dec_store_en;
        mem_wdata = {4{dec_res_byte}};
        mem_wbe   = dec_store_en ? (4'b1000 >> dec_store_addr[1:0]) : 4'd0;
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
      dec_n1_q     <= 5'd0;
      dec_n2_q     <= 5'd0;
      dec_addr1_q  <= 24'd0;
      dec_addr2_q  <= 24'd0;
      dec_k_q      <= 5'd0;
      dec_j_q      <= 5'd0;
      dec_phase_q  <= 3'd0;
      dec_ba_q     <= 8'd0;
      dec_bb_q     <= 8'd0;
      dec_bb_prev_q<= 8'd0;
      dec_lo_a_q   <= 4'd0;
      dec_s1_q     <= 4'd0;
      dec_s2_q     <= 4'd0;
      dec_carry_q  <= 1'b0;
      dec_big_a_q  <= 1'b0;
      dec_diff_q   <= 1'b0;
      dec_zero_q   <= 1'b0;
      dec_ovf_q    <= 1'b0;
      dec_pass2_q  <= 1'b0;
      dec_fin_q    <= 1'b0;
      dec_div9_q   <= 1'b0;
      dec_decovf_q <= 1'b0;
      dec_acc1_q   <= '0;
      dec_prod_q   <= '0;
      dec_acc2_q   <= 64'd0;
      dec_rem_q    <= 72'd0;
      dec_dbl_q    <= 64'd0;
      dec_bin_q    <= 56'd0;
      dec_step_q   <= 6'd0;
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
      ext_pending_q <= 1'b0;
      for (int i = 0; i < GPR_COUNT; i++) begin
        gpr[i] <= 32'd0;
      end
      for (int i = 0; i < 6; i++) begin
        ib[i] <= 8'd0;
      end
    end else begin
      if (ext_timer_req) begin
        ext_pending_q <= 1'b1;
      end
      if (key_we) begin
        st_key[key_block] <= {key_fetch_protect, key_data};
      end
      unique case (state)
        S_CHECK: begin
          // An external (timer) interruption is accepted before any fetch and
          // also ends the wait state (A22-6821-7 p. 17). A masked request
          // stays pending until the system-mask bit 7 is set.
          if (ext_pending_q && psw_word[56]) begin
            int_code_q     <= CODE_TIMER;
            int_psw_q      <= {psw_word[63:48], CODE_TIMER, psw_word[31:0]};
            int_old_addr_q <= EXTERNAL_OLD_PSW;
            int_new_addr_q <= EXTERNAL_NEW_PSW;
            ext_pending_q  <= 1'b0;
            state          <= S_INT_OLD0;
          end else if (psw_wait) begin
            state <= S_CHECK;
          end else if (int_pending_q) begin
            state <= S_INT_OLD0;
          end else if (out_of_range(psw_ia)) begin
            // Instruction halfword outside installed storage (p. 72). No
            // instruction was fetched, so the old PSW keeps the instruction
            // address and records ILC 0 (assumption A-9).
            int_code_q     <= CODE_ADDRESSING;
            int_psw_q      <= {psw_word[63:48], CODE_ADDRESSING, 2'd0, psw_word[29:0]};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
            state          <= S_CHECK;
          end else if (psw_ia[0]) begin
            // "A specification exception occurs when the instruction address in
            // the psw is odd" (p. 72).
            int_code_q     <= CODE_SPECIF;
            int_psw_q      <= {psw_word[63:48], CODE_SPECIF, 2'd0, psw_word[29:0]};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
            state          <= S_CHECK;
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
          ovf_int_q    <= 1'b0;
          dec_div9_q   <= 1'b0;
          dec_decovf_q <= 1'b0;
          next_ia_q    <= ia_cur + {20'd0, len_q};

          // A store into a protected block with a different key is suppressed
          // and raises the protection exception (A22-6821-7 p. 69). SS
          // operations are checked with their fields below.
          if (needs_store && !ss_op && !store_permitted(ea_q)) begin
            int_code_q     <= CODE_PROTECTION;
            int_psw_q      <= {psw_word[63:48], CODE_PROTECTION, ilc_q,
                               psw_word[29:24], (ia_cur + {20'd0, len_q})};
            int_pending_q  <= 1'b1;
            int_old_addr_q <= PROGRAM_OLD_PSW;
            int_new_addr_q <= PROGRAM_NEW_PSW;
            state          <= S_CHECK;
          end else if (is_divide_op && div_overflow) begin
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
                // "A 32-bit signed remainder and a 32-bit signed quotient
                // replace the dividend in the even-numbered and odd-numbered
                // registers, respectively" (p. 31).
                wr_en_q   <= 1'b1;
                wr_idx_q  <= r1_f;
                res_q     <= div_remainder;
                wr_en2_q  <= 1'b1;
                wr_idx2_q <= r1_f | 4'd1;
                res2_q    <= div_quotient[31:0];
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
                // bits 24-31 of the R1 register ORed into its second byte;
                // R1 = 0 means no modification (p. 67). The PSW address
                // advances by EXECUTE's own length.
                ex_active_q    <= 1'b1;
                ex_ia_q        <= ia_cur;
                ex_return_ia_q <= ia_cur + {20'd0, len_q};
                ex_byte_q      <= (r1_f == 4'd0) ? 8'h00 : gpr[r1_f][7:0];
                ia_cur         <= ea_q;
                cnt            <= 3'd0;
              end
              OP_SPM: begin
                // "Bits 2-7 of the general register specified by the R1 field
                // replace the condition code and the program mask bits of the
                // current psw" (p. 72): register bit 2 -> PSW bit 34 (CC high),
                // register bit 4 -> PSW bit 36 (fixed-point-overflow mask).
                spm_cc_en_q <= 1'b1;
                spm_cc_q    <= {gpr[r1_f][2], gpr[r1_f][3]};
                pmask_en_q  <= 1'b1;
                pmask_q     <= {gpr[r1_f][4], gpr[r1_f][5], gpr[r1_f][6], gpr[r1_f][7]};
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
            // The mask bit is PSW bit 36, the most significant bit of the
            // program-mask field (psw_pmask[3], Figure 14 p. 15).
            if ((is_addsub && alu_ovf) || (is_shift_op && shift_ovf)) begin
              ovf_q <= 1'b1;
              if (psw_pmask[3]) begin
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
            if (ss_op && (ss_range_bad || ss_prot_bad)) begin
              int_code_q     <= ss_range_bad ? CODE_ADDRESSING : CODE_PROTECTION;
              int_psw_q      <= {psw_word[63:48],
                                 ss_range_bad ? CODE_ADDRESSING : CODE_PROTECTION,
                                 ilc_q, psw_word[29:24],
                                 (ia_cur + {20'd0, len_q})};
              int_pending_q  <= 1'b1;
              int_old_addr_q <= PROGRAM_OLD_PSW;
              int_new_addr_q <= PROGRAM_NEW_PSW;
              state          <= S_CHECK;
            end else if (dec_ss_op && (dec_range_bad || dec_prot_bad || dec_spec_bad)) begin
              // Whole-field addressing, protection and the MULTIPLY/DECIMAL
              // DIVIDE length-code checks, before the first byte (pp. 34,
              // 38-40). Suppression before any store is deviation A-8 style.
              int_code_q     <= dec_range_bad ? CODE_ADDRESSING
                              : dec_prot_bad  ? CODE_PROTECTION
                                              : CODE_SPECIF;
              int_psw_q      <= {psw_word[63:48],
                                 dec_range_bad ? CODE_ADDRESSING
                               : dec_prot_bad  ? CODE_PROTECTION
                                               : CODE_SPECIF,
                                 ilc_q, psw_word[29:24],
                                 (ia_cur + {20'd0, len_q})};
              int_pending_q  <= 1'b1;
              int_old_addr_q <= PROGRAM_OLD_PSW;
              int_new_addr_q <= PROGRAM_NEW_PSW;
              state          <= S_CHECK;
            end else if (cvb_cvd_op && (cvb_cvd_range_bad || cvb_cvd_prot_bad)) begin
              int_code_q     <= cvb_cvd_range_bad ? CODE_ADDRESSING : CODE_PROTECTION;
              int_psw_q      <= {psw_word[63:48],
                                 cvb_cvd_range_bad ? CODE_ADDRESSING : CODE_PROTECTION,
                                 ilc_q, psw_word[29:24],
                                 (ia_cur + {20'd0, len_q})};
              int_pending_q  <= 1'b1;
              int_old_addr_q <= PROGRAM_OLD_PSW;
              int_new_addr_q <= PROGRAM_NEW_PSW;
              state          <= S_CHECK;
            end else if (dec.op == OP_LPSW) begin
              state <= S_LPSW_LO;
            end else if (dec.op == OP_EX) begin
              state <= S_FETCH;
            end else if (ss_op) begin
              state <= S_SS_A;
            end else if (dec_ss_op || cvb_cvd_op) begin
              // Decimal entry: field geometry, loop indices and flags.
              dec_addr1_q   <= ss_addr1;
              dec_addr2_q   <= ss_addr2;
              dec_n1_q      <= {1'b0, ib[1][7:4]} + 5'd1;
              dec_n2_q      <= {1'b0, ib[1][3:0]} + 5'd1;
              dec_k_q       <= 5'd0;
              dec_j_q       <= 5'd0;
              dec_phase_q   <= 3'd0;
              dec_pass2_q   <= 1'b0;
              dec_fin_q     <= 1'b0;
              dec_carry_q   <= 1'b0;
              dec_big_a_q   <= 1'b0;
              dec_diff_q    <= 1'b0;
              dec_zero_q    <= 1'b1;
              dec_ovf_q     <= 1'b0;
              dec_div9_q    <= 1'b0;
              dec_decovf_q  <= 1'b0;
              dec_bb_prev_q <= 8'd0;
              dec_lo_a_q    <= 4'd0;
              dec_acc1_q    <= '0;
              dec_prod_q    <= '0;
              dec_acc2_q    <= 64'd0;
              dec_rem_q     <= 72'd0;
              dec_dbl_q     <= 64'd0;
              dec_bin_q     <= 56'd0;
              dec_step_q    <= 6'd0;
              dec_s1_q      <= 4'd0;
              dec_s2_q      <= 4'd0;
              unique case (dec.op)
                OP_CVB: begin
                  state <= S_DEC_A;          // capture the two words first
                end
                OP_CVD: begin
                  // Magnitude and sign of R1 (p. 32); the preferred sign is
                  // applied when the result bytes are stored.
                  dec_bin_q  <= {24'd0,
                                 (gpr[r1_f][31] ? (~gpr[r1_f] + 32'd1) : gpr[r1_f])};
                  dec_s1_q   <= {3'b000, gpr[r1_f][31]};
                  dec_step_q <= 6'd0;
                  state      <= S_DEC_CVD;
                end
                OP_MP, OP_DP: begin
                  dec_phase_q <= 3'd0;       // capture operand 1, then operand 2
                  state       <= S_DEC_A;
                end
                OP_MVO: begin
                  dec_phase_q <= 3'd0;       // phase 0 captures op1's low nibble
                  state       <= S_DEC_A;
                end
                default: begin
                  state <= S_DEC_A;
                end
              endcase
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
          if (ovf_int_q || dec_div9_q) begin
            // Completed-then-interrupted causes: fixed-point overflow (8)
            // from the ALU and shifts, decimal overflow (10) from the
            // add-type decimal instructions when mask bit 37 is one, and the
            // CVB fixed-point divide (9), which has no mask bit (pp. 31, 40).
            int_code_q     <= dec_div9_q ? CODE_DIVIDE
                            : dec_decovf_q ? CODE_DEC_OVERFLOW : CODE_OVERFLOW;
            int_psw_q      <= {psw_word[63:48],
                               dec_div9_q ? CODE_DIVIDE
                             : dec_decovf_q ? CODE_DEC_OVERFLOW : CODE_OVERFLOW,
                               ilc_q, cc_q, psw_word[27:24], next_ia_q};
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

        // -------------------------------------------------------------------
        // Decimal datapath (M9). Fetch, compute and store steps follow the
        // manual's right-to-left byte procedure so overlapped operands see
        // the architectural result.
        // -------------------------------------------------------------------
        S_DEC_A: begin
          unique case (dec.op)
            OP_CVB: begin
              dec_dbl_q[63:32] <= read_word;
              state <= S_DEC_B;
            end
            OP_MVO: begin
              if (dec_phase_q == 3'd0) begin
                // Operand 1's rightmost byte is fetched before any store; its
                // low nibble survives in result byte 0 (p. 40).
                dec_lo_a_q  <= read_byte[3:0];
                dec_phase_q <= 3'd1;
              end else begin
                dec_bb_q <= dec_rd_a_real ? read_byte : 8'd0;
                state    <= S_DEC_C;
              end
            end
            OP_PACK: begin
              // The A fetch is operand 2 byte 2k-1 (byte 0 for k=0): it is the
              // low digit of the result byte, so it lands in dec_bb_q.
              dec_bb_q <= dec_rd_a_real ? read_byte : 8'd0;
              if (!dec_rd_b_real) begin
                dec_bb_prev_q <= 8'd0;    // digit 2k beyond operand 2
              end
              state <= dec_rd_b_real ? S_DEC_B : S_DEC_C;
            end
            OP_MP, OP_DP: begin
              dec_ba_q <= dec_rd_a_real ? read_byte : 8'd0;
              state    <= S_DEC_C;
            end
            OP_UNPK, OP_ZAP: begin
              dec_bb_q <= dec_rd_a_real ? read_byte : 8'd0;
              state    <= S_DEC_C;
            end
            default: begin  // AP, SP, CP: operand 1 byte, then operand 2
              dec_ba_q <= dec_rd_a_real ? read_byte : 8'd0;
              state    <= S_DEC_B;
            end
          endcase
        end

        S_DEC_B: begin
          unique case (dec.op)
            OP_CVB: begin
              dec_dbl_q[31:0] <= read_word;
              if (dec_cvb_bad) begin
                int_code_q     <= CODE_DATA;
                int_psw_q      <= {psw_word[63:48], CODE_DATA, ilc_q,
                                   psw_word[29:24], (ia_cur + {20'd0, len_q})};
                int_pending_q  <= 1'b1;
                int_old_addr_q <= PROGRAM_OLD_PSW;
                int_new_addr_q <= PROGRAM_NEW_PSW;
                state          <= S_CHECK;
              end else begin
                dec_s1_q   <= read_word[3:0];   // sign nibble of byte ea+7
                dec_bin_q  <= 56'd0;
                dec_step_q <= 6'd14;
                state      <= S_DEC_CVB;
              end
            end
            OP_PACK: begin
              dec_bb_prev_q <= dec_rd_b_real ? read_byte : 8'd0;
              state <= S_DEC_C;
            end
            default: begin  // AP, SP, CP
              dec_bb_q <= dec_rd_b_real ? read_byte : 8'd0;
              state    <= S_DEC_C;
            end
          endcase
        end

        S_DEC_C: begin
          unique case (dec.op)
            // ---- move type: store one result byte and advance --------------
            OP_PACK, OP_MVO: begin
              if (dec.op == OP_MVO) begin
                dec_bb_prev_q <= dec_bb_q;
              end
              if (dec_k_q == (dec_n1_w - 5'd1)) begin
                state <= S_COMMIT;
              end else begin
                dec_k_q <= dec_k_q + 5'd1;
                state   <= S_DEC_A;
              end
            end
            OP_UNPK: begin
              // Operand byte b stores result 2b-1 (and 2b when it exists);
              // byte 0 stores result 0 only.
              if (dec_k_q == 5'd0) begin
                dec_j_q <= 5'd1;
                dec_k_q <= 5'd1;
                if (dec_n1_w == 5'd1) begin
                  state <= S_COMMIT;
                end else begin
                  state <= S_DEC_A;
                end
              end else if ((dec_k_q << 1) < dec_n1_w) begin
                dec_j_q     <= dec_k_q << 1;
                dec_pass2_q <= 1'b1;
                state       <= S_DEC_ST;
              end else begin
                dec_k_q <= dec_k_q + 5'd1;
                if (((dec_k_q + 5'd1) << 1) - 5'd1 < dec_n1_w) begin
                  state <= S_DEC_A;
                end else begin
                  state <= S_COMMIT;
                end
              end
            end
            // ---- add type: pass 1 validates and sets flags -----------------
            OP_ZAP, OP_AP, OP_SP: begin
              if (dec_fin_q) begin
                // Flags settled one cycle earlier: condition code, then the
                // masked decimal overflow interruption (pp. 37, 40).
                cc_we_q <= 1'b1;
                cc_q    <= dec_ovf_q ? 2'd3
                         : (dec_zero_q ? 2'd0
                            : ((dec.op == OP_ZAP) ? dec_min2_eff
                               : (dec_same_sign ? dec_min1
                                  : (dec_big_a_q ? dec_min1 : dec_min2_eff)))
                              ? 2'd1 : 2'd2);
                if (dec_ovf_q && psw_pmask[2]) begin
                  ovf_int_q    <= 1'b1;
                  dec_decovf_q <= 1'b1;
                end
                state <= S_COMMIT;
              end else if (!dec_pass2_q) begin
                if (dec_add_bad) begin
                  int_code_q     <= CODE_DATA;
                  int_psw_q      <= {psw_word[63:48], CODE_DATA, ilc_q,
                                     psw_word[29:24], (ia_cur + {20'd0, len_q})};
                  int_pending_q  <= 1'b1;
                  int_old_addr_q <= PROGRAM_OLD_PSW;
                  int_new_addr_q <= PROGRAM_NEW_PSW;
                  state          <= S_CHECK;
                end else begin
                  if (dec_k_q == 5'd0) begin
                    dec_s1_q <= dec_a_lo;
                    dec_s2_q <= dec_b_lo;
                  end
                  if (dec.op == OP_ZAP) begin
                    dec_zero_q <= dec_zero_q && (dec_b_hi == 4'd0) &&
                                  ((dec_k_q == 5'd0) || (dec_b_lo == 4'd0));
                    dec_ovf_q  <= dec_ovf_q ||
                                  ((dec_k_q >= dec_n1_w) &&
                                   ((dec_b_hi != 4'd0) ||
                                    ((dec_k_q != 5'd0) && (dec_b_lo != 4'd0))));
                  end else if (dec_same_now) begin
                    dec_zero_q  <= dec_zero_q && (dec_d2[3:0] == 4'd0) &&
                                   ((dec_k_q == 5'd0) || (dec_d1[3:0] == 4'd0));
                    dec_ovf_q   <= dec_ovf_q ||
                                   (dec_c2 && ((dec_k_q + 5'd1) >= dec_n1_w)) ||
                                   ((dec_k_q >= dec_n1_w) &&
                                    ((dec_d2[3:0] != 4'd0) ||
                                     ((dec_k_q != 5'd0) && (dec_d1[3:0] != 4'd0))));
                    dec_carry_q <= dec_c2;
                  end else begin
                    // Different signs: compare magnitudes right to left; the
                    // most significant difference decides (p. 38).
                    if ((dec_k_q != 5'd0) && (dec_a_lo != dec_b_lo)) begin
                      dec_diff_q  <= 1'b1;
                      dec_big_a_q <= (dec_a_lo > dec_b_lo);
                    end
                    if (dec_a_hi != dec_b_hi) begin
                      dec_diff_q  <= 1'b1;
                      dec_big_a_q <= (dec_a_hi > dec_b_hi);
                    end
                  end
                  if (dec_k_q == ((dec.op == OP_ZAP) ? (dec_n2_w - 5'd1)
                                                     : (dec_max_n - 5'd1))) begin
                    dec_pass2_q <= 1'b1;
                    dec_carry_q <= 1'b0;
                    dec_k_q     <= 5'd0;
                    if (dec.op != OP_ZAP) begin
                      dec_zero_q <= dec_same_now ? dec_zero_q : !dec_diff_q;
                    end
                    state <= S_DEC_A;          // pass 2 refetches byte 0
                  end else begin
                    dec_k_q <= dec_k_q + 5'd1;
                    state   <= S_DEC_A;
                  end
                end
              end else begin
                // ---- pass 2: recompute and store ---------------------------
                dec_carry_q <= dec_same_now ? dec_c2 : dec_sb2;
                if (!dec_same_now && (dec.op != OP_ZAP)) begin
                  // Overflow of the difference: a nonzero digit at or beyond
                  // position 2n1-1 (pp. 37, 40).
                  dec_ovf_q <= dec_ovf_q ||
                               ((dec_k_q >= dec_n1_w) &&
                                ((dec_sd2 != 4'd0) ||
                                 ((dec_k_q != 5'd0) && (dec_sd1 != 4'd0))));
                end
                if (dec_k_q == ((dec.op == OP_ZAP) ? (dec_n1_w - 5'd1)
                                                   : (dec_max_n - 5'd1))) begin
                  dec_fin_q <= 1'b1;   // finalize with settled flags
                end else begin
                  dec_k_q <= dec_k_q + 5'd1;
                  state   <= S_DEC_A;
                end
              end
            end
            // ---- COMPARE DECIMAL: one validating compare pass --------------
            OP_CP: begin
              if (dec_fin_q) begin
                // Finalize: 0 equal, 1 first low, 2 first high (p. 38); a
                // zero value compares equal regardless of the sign nibble.
                cc_we_q <= 1'b1;
                cc_q    <= dec_zero_q ? 2'd0
                         : (dec_min1 != dec_min2_eff) ?
                           (dec_min1 ? 2'd1 : 2'd2)
                         : (dec_diff_q ? (dec_big_a_q ? 2'd2 : 2'd1) : 2'd0);
                state   <= S_COMMIT;
              end else if (dec_add_bad) begin
                int_code_q     <= CODE_DATA;
                int_psw_q      <= {psw_word[63:48], CODE_DATA, ilc_q,
                                   psw_word[29:24], (ia_cur + {20'd0, len_q})};
                int_pending_q  <= 1'b1;
                int_old_addr_q <= PROGRAM_OLD_PSW;
                int_new_addr_q <= PROGRAM_NEW_PSW;
                state          <= S_CHECK;
              end else begin
                if (dec_k_q == 5'd0) begin
                  dec_s1_q <= dec_a_lo;
                  dec_s2_q <= dec_b_lo;
                end
                if ((dec_k_q != 5'd0) && (dec_a_lo != dec_b_lo)) begin
                  dec_diff_q  <= 1'b1;
                  dec_big_a_q <= (dec_a_lo > dec_b_lo);
                end
                if (dec_a_hi != dec_b_hi) begin
                  dec_diff_q  <= 1'b1;
                  dec_big_a_q <= (dec_a_hi > dec_b_hi);
                end
                dec_zero_q <= dec_zero_q && (dec_a_hi == 4'd0) &&
                              (dec_b_hi == 4'd0) &&
                              ((dec_k_q == 5'd0) ||
                               ((dec_a_lo == 4'd0) && (dec_b_lo == 4'd0)));
                if (dec_k_q == (dec_max_n - 5'd1)) begin
                  dec_fin_q <= 1'b1;   // finalize with settled flags
                end else begin
                  dec_k_q <= dec_k_q + 5'd1;
                  state   <= S_DEC_A;
                end
              end
            end
            // ---- MP/DP operand capture -------------------------------------
            OP_MP, OP_DP: begin
              if (dec_phase_q == 3'd0) begin
                if (dec_k_q == 5'd0) begin
                  dec_acc1_q[3:0] <= dec_ba_q[7:4];   // digit 0
                  dec_s1_q        <= dec_ba_q[3:0];   // sign
                end else begin
                  dec_acc1_q[4*(2*dec_k_q - 1) +: 8] <= dec_ba_q;
                end
                if (dec_k_q == (dec_n1_w - 5'd1)) begin
                  dec_phase_q <= 3'd1;
                  dec_k_q     <= 5'd0;
                end else begin
                  dec_k_q <= dec_k_q + 5'd1;
                end
                state <= S_DEC_A;
              end else if (dec_phase_q == 3'd1) begin
                if (dec_k_q == 5'd0) begin
                  dec_acc2_q[3:0] <= dec_ba_q[7:4];
                  dec_s2_q        <= dec_ba_q[3:0];
                end else begin
                  dec_acc2_q[4*(2*dec_k_q - 1) +: 8] <= dec_ba_q;
                end
                if (dec_k_q == (dec_n2_w - 5'd1)) begin
                  // The captured registers update at this edge, so the
                  // validation runs one cycle later in phase 2.
                  dec_phase_q <= 3'd2;
                end else begin
                  dec_k_q <= dec_k_q + 5'd1;
                  state   <= S_DEC_A;
                end
              end else if (dec_phase_q == 3'd2) begin
                // Validate the captured operands (p. 40).
                if (dec_cap1_bad || dec_cap2_bad ||
                    ((dec.op == OP_MP) && !dec_mp_lead_ok)) begin
                  // Invalid sign or digit code, or a multiplicand without
                  // the required high-order zeros: data exception (p. 40).
                  int_code_q     <= CODE_DATA;
                  int_psw_q      <= {psw_word[63:48], CODE_DATA, ilc_q,
                                     psw_word[29:24],
                                     (ia_cur + {20'd0, len_q})};
                  int_pending_q  <= 1'b1;
                  int_old_addr_q <= PROGRAM_OLD_PSW;
                  int_new_addr_q <= PROGRAM_NEW_PSW;
                  state          <= S_CHECK;
                end else if ((dec.op == OP_DP) && dec_dv_zero) begin
                  // Division by zero: decimal-divide exception, suppressed
                  // (pp. 39-40).
                  int_code_q     <= CODE_DEC_DIVIDE;
                  int_psw_q      <= {psw_word[63:48], CODE_DEC_DIVIDE, ilc_q,
                                     psw_word[29:24],
                                     (ia_cur + {20'd0, len_q})};
                  int_pending_q  <= 1'b1;
                  int_old_addr_q <= PROGRAM_OLD_PSW;
                  int_new_addr_q <= PROGRAM_NEW_PSW;
                  state          <= S_CHECK;
                end else begin
                  dec_k_q <= 5'd0;
                  if (dec.op == OP_MP) begin
                    dec_step_q <= 6'd0;
                    state      <= S_DEC_MP;
                  end else begin
                    dec_step_q  <= {dec_n1_w, 1'b0} - 6'd2;   // 2n1-2
                    dec_pass2_q <= 1'b0;
                    dec_j_q     <= 5'd0;
                    state       <= S_DEC_DIV;
                  end
                end
              end else begin
                state <= S_COMMIT;
              end
            end
            // ---- CVB finish: register write, then a possible code 9 --------
            OP_CVB: begin
              wr_en_q    <= 1'b1;
              wr_idx_q   <= r1_f;
              res_q      <= dec_cvb_val;
              dec_div9_q <= dec_cvb_ovf;
              state      <= S_COMMIT;
            end
            default: state <= S_COMMIT;
          endcase
        end

        S_DEC_ST: begin
          unique case (dec.op)
            OP_UNPK: begin
              // Second result byte 2b of operand byte b.
              dec_j_q     <= dec_j_q + 5'd1;
              dec_k_q     <= dec_k_q + 5'd1;
              dec_pass2_q <= 1'b0;
              if (((dec_k_q + 5'd1) << 1) - 5'd1 < dec_n1_w) begin
                state <= S_DEC_A;
              end else begin
                state <= S_COMMIT;
              end
            end
            OP_MP, OP_DP, OP_CVD: begin
              if (dec_k_q == ((dec.op == OP_CVD) ? 5'd7 : (dec_n1_w - 5'd1))) begin
                state <= S_COMMIT;
              end else begin
                dec_k_q <= dec_k_q + 5'd1;
              end
            end
            default: state <= S_COMMIT;
          endcase
        end

        // CVB conversion step: Horner v = v*10 + digit, most significant
        // digit first (p. 31).
        S_DEC_CVB: begin
          dec_bin_q <= dec_cvb_next;
          if (dec_step_q == 6'd0) begin
            state <= S_DEC_C;          // finish: register write, code 9 check
          end else begin
            dec_step_q <= dec_step_q - 6'd1;
          end
        end

        // CVD conversion step: double-dabble, one bit of the magnitude per
        // cycle into the 16-nibble BCD register (p. 32).
        S_DEC_CVD: begin
          dec_dbl_q <= {dec_dbl_adj[62:0], dec_bin_q[31]};
          dec_bin_q <= {dec_bin_q[54:0], 1'b0};
          if (dec_step_q == 6'd31) begin
            dec_phase_q <= 3'd1;
            dec_k_q     <= 5'd0;
            state       <= S_DEC_ST;
          end else begin
            dec_step_q <= dec_step_q + 6'd1;
          end
        end

        // MP step: product += A * digit j of the multiplier (p. 38).
        S_DEC_MP: begin
          dec_prod_q <= dec_mul_step(dec_prod_q, dec_acc1_q,
                                     dec_acc2_q[4*dec_step_q +: 4], dec_step_i);
          if (dec_step_q == dec_mp_lim) begin
            dec_phase_q <= 3'd3;
            dec_k_q     <= 5'd0;
            state       <= S_DEC_ST;
          end else begin
            dec_step_q <= dec_step_q + 6'd1;
          end
        end

        // DP step: bring down one dividend digit, then trial-subtract the
        // divisor until the remainder is below it (p. 39).
        S_DEC_DIV: begin
          if (!dec_pass2_q) begin
            dec_rem_q[71:4] <= dec_rem_q[67:0];
            dec_rem_q[3:0]  <= dec_dig(dec_acc1_q, dec_step_i);
            dec_pass2_q     <= 1'b1;
          end else if (dec_ge({56'd0, dec_rem_q}, {64'd0, dec_acc2_q})) begin
            dec_rem_q <= dec_div_sub[71:0];
            dec_j_q   <= dec_j_q + 5'd1;
          end else begin
            // Quotient digit dec_j_q at position dec_step_q. A nonzero digit
            // at or beyond the quotient field is the decimal-divide
            // exception; the operation is suppressed (pp. 39-40).
            if (({1'b0, dec_step_q} >= dec_qlen) && (dec_j_q != 5'd0)) begin
              int_code_q     <= CODE_DEC_DIVIDE;
              int_psw_q      <= {psw_word[63:48], CODE_DEC_DIVIDE, ilc_q,
                                 psw_word[29:24], (ia_cur + {20'd0, len_q})};
              int_pending_q  <= 1'b1;
              int_old_addr_q <= PROGRAM_OLD_PSW;
              int_new_addr_q <= PROGRAM_NEW_PSW;
              state          <= S_CHECK;
            end else begin
              if ({1'b0, dec_step_q} < dec_qlen) begin
                // Digits are emitted from the most significant position down,
                // so a shift-left assembly leaves digit 0 in the low nibble.
                dec_prod_q <= {dec_prod_q[123:0], dec_j_q[3:0]};
              end
              if (dec_step_q == 6'd0) begin
                dec_phase_q <= 3'd3;
                dec_k_q     <= 5'd0;
                state       <= S_DEC_ST;
              end else begin
                dec_step_q  <= dec_step_q - 6'd1;
                dec_pass2_q <= 1'b0;
                dec_j_q     <= 5'd0;
              end
            end
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

  // Decimal suppressed causes (data 7, decimal-divide 11) are raised from the
  // decimal states with the condition code and storage unchanged.
  logic dec_raise;
  assign dec_raise = ((state == S_DEC_B) || (state == S_DEC_C) ||
                      (state == S_DEC_DIV)) && int_pending_q;
  assign int_raise = ((state == S_DECODE) && suppress) ||
                     ((state == S_EXEC) && ((is_divide_op && div_overflow) ||
                                            (dec.op == OP_SVC))) ||
                     dec_raise ||
                     ((state == S_COMMIT) && ovf_int_q);
  assign int_raise_cc_same = ((state == S_DECODE) && suppress) ||
                             ((state == S_EXEC) && ((is_divide_op && div_overflow) ||
                                                    (dec.op == OP_SVC))) ||
                             dec_raise;
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
            (state == S_DEC_C) || (state == S_DEC_ST) ||
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
