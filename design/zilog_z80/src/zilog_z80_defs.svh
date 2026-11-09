// Zilog Z80 shared types and constants.
//
// Plain include header rather than a SystemVerilog package: the Yosys
// SystemVerilog frontend does not accept `import`, so the shared typedefs and
// constants are textually included behind a guard. Verilator accepts the same
// form.
//
// Flag bit positions follow the manufacturer manual and the exerciser summary:
// S=7, Z=6, F5=5 (undocumented), H=4, F3=3 (undocumented), P/V=2, N=1, C=0.
`ifndef ZILOG_Z80_DEFS_SVH
`define ZILOG_Z80_DEFS_SVH

// Flag bit positions inside the F byte.
localparam int FLAG_C  = 0;
localparam int FLAG_N  = 1;
localparam int FLAG_PV = 2;
localparam int FLAG_F3 = 3;
localparam int FLAG_H  = 4;
localparam int FLAG_F5 = 5;
localparam int FLAG_Z  = 6;
localparam int FLAG_S  = 7;

// 8-bit register indices used by the decoder; 6 selects memory (HL)/(IX+d).
localparam logic [2:0] REG_B = 3'd0;
localparam logic [2:0] REG_C = 3'd1;
localparam logic [2:0] REG_D = 3'd2;
localparam logic [2:0] REG_E = 3'd3;
localparam logic [2:0] REG_H = 3'd4;
localparam logic [2:0] REG_L = 3'd5;
localparam logic [2:0] REG_M = 3'd6;
localparam logic [2:0] REG_A = 3'd7;

// 16-bit pair indices.
localparam logic [1:0] PAIR_BC = 2'd0;
localparam logic [1:0] PAIR_DE = 2'd1;
localparam logic [1:0] PAIR_HL = 2'd2;
localparam logic [1:0] PAIR_SP = 2'd3;

// ALU operations.
typedef enum logic [4:0] {
  ALU_ADD,   // a + b + cin
  ALU_ADC,   // a + b + cin, documented ADC
  ALU_SUB,   // a - b - cin
  ALU_SBC,   // a - b - cin, documented SBC
  ALU_AND,
  ALU_OR,
  ALU_XOR,
  ALU_CP,    // subtract without writing back
  ALU_INC,   // preserves C
  ALU_DEC,   // preserves C
  ALU_RLC,
  ALU_RRC,
  ALU_RL,
  ALU_RR,
  ALU_SLA,
  ALU_SRA,
  ALU_SLL,   // undocumented shift-left-with-one
  ALU_SRL,
  ALU_DAA,
  ALU_CPL,
  ALU_NEG,
  ALU_BIT    // flags only, y = a
} alu_op_t;

// Condition codes, encoded as the instruction's cc field.
localparam logic [2:0] CC_NZ = 3'd0;
localparam logic [2:0] CC_Z  = 3'd1;
localparam logic [2:0] CC_NC = 3'd2;
localparam logic [2:0] CC_C  = 3'd3;
localparam logic [2:0] CC_PO = 3'd4;
localparam logic [2:0] CC_PE = 3'd5;
localparam logic [2:0] CC_P  = 3'd6;
localparam logic [2:0] CC_M  = 3'd7;

`endif
