// PDP-1 Am29xx reconstruction: shared constants.
//
// Numeric conventions in this machine:
//   * An 18-bit word is `logic [17:0]`; bit 17 is the sign (DEC bit 0) and
//     bit 0 is the least significant (DEC bit 17).
//   * An instruction word is IR[17:13] = opcode, IR[12] = indirect / group
//     modifier bit, IR[11:0] = address field.
//
// Included inside each module body so that every module gets its own copy
// of the constants (Verilator and Yosys both accept module-scope localparams
// but not the same package import syntax).


  // Microcode D-bus sources. Must match scripts/ucasm.py `D`.
  localparam logic [4:0] D_ZERO = 5'd0;
  localparam logic [4:0] D_ONE = 5'd1;
  localparam logic [4:0] D_ONES = 5'd2;
  localparam logic [4:0] D_MB = 5'd3;
  localparam logic [4:0] D_MEM = 5'd4;
  localparam logic [4:0] D_ADDR = 5'd5;
  localparam logic [4:0] D_ADDR1 = 5'd6;
  localparam logic [4:0] D_PC = 5'd7;
  localparam logic [4:0] D_MA = 5'd8;
  localparam logic [4:0] D_TW = 5'd9;
  localparam logic [4:0] D_SS = 5'd10;
  localparam logic [4:0] D_Y = 5'd11;
  localparam logic [4:0] D_SHF = 5'd12;
  localparam logic [4:0] D_IMM = 5'd13;
  localparam logic [4:0] D_STATUS = 5'd14;
  localparam logic [4:0] D_DEVDATA = 5'd15;

  // Microcode conditions. Must match scripts/ucasm.py `CC`.
  localparam logic [4:0] CC_FALSE = 5'd0;
  localparam logic [4:0] CC_TRUE = 5'd1;
  localparam logic [4:0] CC_IR_IND = 5'd2;
  localparam logic [4:0] CC_AC_ZERO = 5'd3;
  localparam logic [4:0] CC_AC_SIGN = 5'd4;
  localparam logic [4:0] CC_IO_SIGN = 5'd5;
  localparam logic [4:0] CC_IO_LSB = 5'd6;
  localparam logic [4:0] CC_OV = 5'd7;
  localparam logic [4:0] CC_NFC_ZERO = 5'd8;
  localparam logic [4:0] CC_EAC = 5'd9;
  localparam logic [4:0] CC_IO_READY = 5'd10;
  localparam logic [4:0] CC_SBS_REQ = 5'd11;
  localparam logic [4:0] CC_IR_A7 = 5'd12;
  localparam logic [4:0] CC_IR_A8 = 5'd13;
  localparam logic [4:0] CC_IR_A9 = 5'd14;
  localparam logic [4:0] CC_IR_A10 = 5'd15;
  localparam logic [4:0] CC_IR_A11 = 5'd16;
  localparam logic [4:0] CC_IR_A3 = 5'd17;
  localparam logic [4:0] CC_IR_A6 = 5'd18;
  localparam logic [4:0] CC_SKIP_ANY = 5'd19;
  localparam logic [4:0] CC_IR_A2_0 = 5'd20;
  localparam logic [4:0] CC_IR_A5_3 = 5'd21;
  localparam logic [4:0] CC_PF_ALL_ZERO = 5'd22;
  localparam logic [4:0] CC_SS_ALL_ZERO = 5'd23;
  localparam logic [4:0] CC_SBS_ACTIVE = 5'd24;
  localparam logic [4:0] CC_IR_A5 = 5'd25;
  localparam logic [4:0] CC_IO_ZERO = 5'd26;
  localparam logic [4:0] CC_MEM_IDLE = 5'd27;
  localparam logic [4:0] CC_HALTED = 5'd28;
  localparam logic [4:0] CC_RESULT_ZERO = 5'd29;
  localparam logic [4:0] CC_IR_A12 = 5'd30;
  localparam logic [4:0] CC_ALWAYS = 5'd31;

  // Slice register-file words. Must match scripts/ucasm.py `REG`.
  localparam logic [3:0] REG_AC = 4'd0;
  localparam logic [3:0] REG_IO = 4'd1;

  // Am2901 destination field values used by the microcode.
  localparam logic [2:0] DEST_RAM_Y_A = 3'd2; // RAM[B] <- F, Y <- A
  localparam logic [2:0] DEST_RAM_Y_F = 3'd3; // RAM[B] <- F, Y <- F

  // Opcodes (IR[17:13]).
  localparam logic [4:0] OP_AND = 5'o01;
  localparam logic [4:0] OP_IOR = 5'o02;
  localparam logic [4:0] OP_XOR = 5'o03;
  localparam logic [4:0] OP_XCT = 5'o04;
  localparam logic [4:0] OP_CAL = 5'o07;
  localparam logic [4:0] OP_LAC = 5'o10;
  localparam logic [4:0] OP_LIO = 5'o11;
  localparam logic [4:0] OP_DAC = 5'o12;
  localparam logic [4:0] OP_DAP = 5'o13;
  localparam logic [4:0] OP_DIP = 5'o14;
  localparam logic [4:0] OP_DIO = 5'o15;
  localparam logic [4:0] OP_DZM = 5'o16;
  localparam logic [4:0] OP_ADD = 5'o20;
  localparam logic [4:0] OP_SUB = 5'o21;
  localparam logic [4:0] OP_IDX = 5'o22;
  localparam logic [4:0] OP_ISP = 5'o23;
  localparam logic [4:0] OP_SAD = 5'o24;
  localparam logic [4:0] OP_SAS = 5'o25;
  localparam logic [4:0] OP_MUS = 5'o26;
  localparam logic [4:0] OP_DIS = 5'o27;
  localparam logic [4:0] OP_JMP = 5'o30;
  localparam logic [4:0] OP_JSP = 5'o31;
  localparam logic [4:0] OP_SKP = 5'o32;
  localparam logic [4:0] OP_SFT = 5'o33;
  localparam logic [4:0] OP_LAW = 5'o34;
  localparam logic [4:0] OP_IOT = 5'o35;
  localparam logic [4:0] OP_OPR = 5'o37;

  // Shift direction / fill codes. Must match scripts/ucasm.py.
  localparam logic [1:0] SHF_LEFT = 2'd1;
  localparam logic [1:0] SHF_RIGHT = 2'd2;
  localparam logic [2:0] FILL_ZERO = 3'd0;
  localparam logic [2:0] FILL_SIGN = 3'd1;
  localparam logic [2:0] FILL_EXT_A = 3'd2;
  localparam logic [2:0] FILL_EXT_B = 3'd3;
  localparam logic [2:0] FILL_ROT = 3'd4;
  localparam logic [1:0] CAP_NONE = 2'd0;
  localparam logic [1:0] CAP_A = 2'd1;
  localparam logic [1:0] CAP_B = 2'd2;

  localparam logic [1:0] MEM_WRITE = 2'd2;

