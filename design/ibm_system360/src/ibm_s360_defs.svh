// IBM System/360 architectural constants, instruction formats and the
// operation table implemented by the M1 core.
//
// This header is included inside each module body rather than wrapped in a
// package: the Yosys 0.69 SystemVerilog frontend rejects `import pkg::*` in a
// module, and the repository's formal flow runs on Yosys. Types and functions
// are therefore declared at module scope, which Verilator and Yosys both
// accept. Include it once per module, after the module declaration.
//
// Sources (see ../spec/sources.md for the ledger and page references):
//   A22-6821-7, IBM System/360 Principles of Operation, eighth edition
//   (September 1968 reprint of A22-6821-6 with Technical Newsletter changes).
//   - "Instruction Format", pp. 12-13, Figure 13 "Five Basic Instruction Formats"
//   - "Instruction Length Recording", p. 13
//   - "Program Status Word Format", p. 15, Figure 14
//   - Instruction tables and descriptions for fixed-point, logical and
//     branching instructions (pp. 26-32, 53-56, 64-65, 73-74)
//
// Only the encodings that the M1 core executes are listed. Instructions that
// the manual defines but this core does not implement decode as OP_ILLEGAL and
// are reported to the caller instead of being silently ignored.

// A shared definition header is included by several modules, so each module
// necessarily leaves some constants unused.
/* verilator lint_off UNUSEDPARAM */

// -----------------------------------------------------------------------------
// Byte-addressable storage and register geometry (A22-6821-7 pp. 8-13).
// -----------------------------------------------------------------------------
localparam int GPR_COUNT = 16;

// -----------------------------------------------------------------------------
// PSW field positions, expressed as bit ranges of the 64-bit PSW word where
// bit 63 is the manual's bit 0 (Figure 14, p. 15). The full layout is
// documented in ibm_s360_psw.sv; only the fields the M1 core writes are named.
// -----------------------------------------------------------------------------
localparam int PSW_ILC_MSB = 31;  // manual bits 32-33
localparam int PSW_CC_MSB  = 29;  // manual bits 34-35
localparam int PSW_IA_MSB  = 23;  // manual bits 40-63
localparam int PSW_IA_LSB  = 0;
localparam int PSW_SYSMASK_MSB = 63;  // manual bits 0-7
localparam int PSW_INTCODE_MSB = 47;  // manual bits 16-31
localparam int PSW_PMASK_MSB   = 27;  // manual bits 36-39
localparam int PSW_PROBLEM_BIT = 48;  // manual bit 15
localparam int PSW_WAIT_BIT    = 49;  // manual bit 14

// -----------------------------------------------------------------------------
// Instruction formats. The first two bits of the operation code select the
// length and format class (A22-6821-7 p. 13).
// -----------------------------------------------------------------------------
typedef enum logic [1:0] {
  FMT_RR    = 2'b00,  // one halfword
  FMT_RX    = 2'b01,  // two halfwords
  FMT_RS_SI = 2'b10,  // two halfwords
  FMT_SS    = 2'b11   // three halfwords
} s360_fmt_e;

// Operation selectors implemented by the core. Six bits are needed because the
// fixed-point group alone contributes more than 32 distinct operations.
typedef enum logic [5:0] {
  OP_ILLEGAL = 6'd0,
  // RR format, fixed point and branching
  OP_BCR  = 6'd1,   // 07
  OP_LTR  = 6'd2,   // 12
  OP_NR   = 6'd3,   // 14
  OP_CLR  = 6'd4,   // 15
  OP_OR   = 6'd5,   // 16
  OP_XR   = 6'd6,   // 17
  OP_LR   = 6'd7,   // 18
  OP_CR   = 6'd8,   // 19
  OP_AR   = 6'd9,   // 1A
  OP_SR   = 6'd10,  // 1B
  // RX format, fixed point
  OP_LA   = 6'd11,  // 41
  OP_BC   = 6'd12,  // 47
  OP_ST   = 6'd13,  // 50
  OP_N    = 6'd14,  // 54
  OP_CL   = 6'd15,  // 55
  OP_O    = 6'd16,  // 56
  OP_X    = 6'd17,  // 57
  OP_L    = 6'd18,  // 58
  OP_C    = 6'd19,  // 59
  OP_A    = 6'd20,  // 5A
  OP_S    = 6'd21,  // 5B
  // SI format
  OP_MVI  = 6'd22,  // 92
  OP_CLI  = 6'd23,  // 95
  OP_SSM  = 6'd24,  // 80
  OP_LPSW = 6'd25,  // 82
  // RR format, status switching and supervisor call
  OP_SPM  = 6'd26,  // 04
  OP_SVC  = 6'd27,  // 0A
  // RX format, halfword group (pp. 26-30)
  OP_LH   = 6'd28,  // 48
  OP_STH  = 6'd29,  // 40
  OP_AH   = 6'd30,  // 4A
  OP_SH   = 6'd31,  // 4B
  OP_CH   = 6'd32,  // 49
  OP_MH   = 6'd33,  // 4C
  // RR/RX multiply and divide (pp. 30-31)
  OP_MR   = 6'd34,  // 1C
  OP_M    = 6'd35,  // 5C
  OP_DR   = 6'd36,  // 1D
  OP_D    = 6'd37,  // 5D
  // RS format shifts (pp. 32-34)
  OP_SLA  = 6'd38,  // 8B
  OP_SRA  = 6'd39,  // 8A
  OP_SLDA = 6'd40,  // 8F
  OP_SRDA = 6'd41,  // 8E
  // Character and SS-format logical group (pp. 53-57)
  OP_MVC  = 6'd42,  // D2
  OP_MVN  = 6'd43,  // D1
  OP_MVZ  = 6'd44,  // D3
  OP_NC   = 6'd45,  // D4
  OP_OC   = 6'd46,  // D6
  OP_XC   = 6'd47,  // D7
  OP_CLC  = 6'd48,  // D5
  OP_TM   = 6'd49,  // 91
  OP_IC   = 6'd50,  // 43
  OP_STC  = 6'd51   // 42
} s360_op_e;

typedef struct packed {
  logic     valid;  // opcode is implemented by this core
  logic [1:0] fmt;  // instruction format (s360_fmt_e)
  s360_op_e op;     // operation selector
} s360_dec_t;

// -----------------------------------------------------------------------------
// Arithmetic unit operation selectors. The condition-code rules implemented by
// each selector are documented in ibm_s360_alu.sv.
// -----------------------------------------------------------------------------
typedef enum logic [2:0] {
  ALU_ADD  = 3'd0,
  ALU_SUB  = 3'd1,
  ALU_CMP  = 3'd2,  // algebraic comparison of signed 32-bit integers
  ALU_CLR  = 3'd3,  // binary (unsigned) comparison
  ALU_AND  = 3'd4,
  ALU_OR   = 3'd5,
  ALU_XOR  = 3'd6,
  ALU_TEST = 3'd7   // pass the first operand through and set CC by sign
} s360_alu_op_e;

// -----------------------------------------------------------------------------
// Instruction length code: the PSW records the instruction length in halfwords
// (A22-6821-7 p. 13). The byte length is twice the ILC.
// -----------------------------------------------------------------------------
function automatic logic [1:0] s360_ilc(input logic [1:0] fmt);
  case (fmt)
    FMT_RR:    s360_ilc = 2'd1;  // 2 bytes
    FMT_RX,
    FMT_RS_SI: s360_ilc = 2'd2;  // 4 bytes
    default:   s360_ilc = 2'd3;  // SS: 6 bytes
  endcase
endfunction

function automatic logic [3:0] s360_len_bytes(input logic [1:0] fmt);
  s360_len_bytes = {2'b00, s360_ilc(fmt)} << 1;
endfunction

// -----------------------------------------------------------------------------
// Operation table. Encodings are taken from the instruction tables in
// A22-6821-7; each comment names the manual page holding the table entry.
// -----------------------------------------------------------------------------
function automatic s360_dec_t s360_decode(input logic [7:0] opcode);
  s360_dec_t d;
  d.valid = 1'b1;
  d.fmt   = FMT_RR;
  d.op    = OP_ILLEGAL;
  // The format class always follows the two high-order opcode bits, even for
  // unimplemented operations, so that an unknown instruction is retired with
  // the correct length instead of desynchronising the fetch unit.
  d.fmt = opcode[7:6];
  case (opcode)
    // ---- Branching, pp. 73-74 ---------------------------------------------
    8'h07: d.op = OP_BCR;
    8'h47: d.op = OP_BC;
    // ---- Fixed-point, pp. 26-32 --------------------------------------------
    8'h12: d.op = OP_LTR;
    8'h14: d.op = OP_NR;
    8'h15: d.op = OP_CLR;
    8'h16: d.op = OP_OR;
    8'h17: d.op = OP_XR;
    8'h18: d.op = OP_LR;
    8'h19: d.op = OP_CR;
    8'h1A: d.op = OP_AR;
    8'h1B: d.op = OP_SR;
    8'h41: d.op = OP_LA;
    8'h50: d.op = OP_ST;
    8'h54: d.op = OP_N;
    8'h55: d.op = OP_CL;
    8'h56: d.op = OP_O;
    8'h57: d.op = OP_X;
    8'h58: d.op = OP_L;
    8'h59: d.op = OP_C;
    8'h5A: d.op = OP_A;
    8'h5B: d.op = OP_S;
    // ---- Logical, pp. 53-56 ------------------------------------------------
    8'h92: d.op = OP_MVI;
    8'h95: d.op = OP_CLI;
    // ---- Status switching, pp. 72-74 --------------------------------------
    8'h04: d.op = OP_SPM;
    8'h0A: d.op = OP_SVC;
    8'h80: d.op = OP_SSM;
    8'h82: d.op = OP_LPSW;
    // ---- Fixed-point halfword group, pp. 26-30 ----------------------------
    8'h40: d.op = OP_STH;
    8'h48: d.op = OP_LH;
    8'h49: d.op = OP_CH;
    8'h4A: d.op = OP_AH;
    8'h4B: d.op = OP_SH;
    8'h4C: d.op = OP_MH;
    // ---- Multiply and divide, pp. 30-31 -----------------------------------
    8'h1C: d.op = OP_MR;
    8'h1D: d.op = OP_DR;
    8'h5C: d.op = OP_M;
    8'h5D: d.op = OP_D;
    // ---- Shifts, pp. 32-34 ------------------------------------------------
    8'h8A: d.op = OP_SRA;
    8'h8B: d.op = OP_SLA;
    8'h8E: d.op = OP_SRDA;
    8'h8F: d.op = OP_SLDA;
    // ---- Character and SS-format logical group, pp. 53-57 -------------------
    8'h42: d.op = OP_STC;
    8'h43: d.op = OP_IC;
    8'h91: d.op = OP_TM;
    8'hD1: d.op = OP_MVN;
    8'hD2: d.op = OP_MVC;
    8'hD3: d.op = OP_MVZ;
    8'hD4: d.op = OP_NC;
    8'hD5: d.op = OP_CLC;
    8'hD6: d.op = OP_OC;
    8'hD7: d.op = OP_XC;
    default: begin
      d.valid = 1'b0;
      d.op    = OP_ILLEGAL;
    end
  endcase
  s360_decode = d;
endfunction

// Instruction field extraction helpers. `b` is the second byte of the
// instruction's first halfword (A22-6821-7 Figure 13, p. 13). Each helper
// deliberately ignores the half of the byte that is not its field.
/* verilator lint_off UNUSEDSIGNAL */
function automatic logic [3:0] s360_r1(input logic [7:0] byte_in);
  s360_r1 = byte_in[7:4];
endfunction

function automatic logic [3:0] s360_r2_or_x2(input logic [7:0] byte_in);
  s360_r2_or_x2 = byte_in[3:0];
endfunction

// The second halfword is always B|D (4-bit base, 12-bit displacement).
function automatic logic [3:0] s360_b(input logic [7:0] hi_byte);
  s360_b = hi_byte[7:4];
endfunction

function automatic logic [11:0] s360_d(input logic [7:0] hi_byte, input logic [7:0] lo_byte);
  s360_d = {hi_byte[3:0], lo_byte};
endfunction
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
