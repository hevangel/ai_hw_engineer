// Shared combinational helpers for the Intel 80386 execution core.
//
// Operand sizes are encoded as 0 = byte, 1 = word, 2 = doubleword. Flag
// vectors use EFLAGS bit positions (CF=0, PF=2, AF=4, ZF=6, SF=7, OF=11).
// Arithmetic semantics follow Intel 386 DX Programmer's Reference Manual,
// order 230985-001, chapter 17 instruction descriptions. Flags that manual
// leaves undefined are produced by the rules noted per function; the
// physical-capture replay masks them with the capture set's f_umask column.
package intel_80386_pkg;
  // The helpers take full 32-bit operands and use only the bits that the
  // operand size selects; the ALU_XOR code is the decode default.
  /* verilator lint_off UNUSEDSIGNAL */
  /* verilator lint_off UNUSEDPARAM */

  localparam int unsigned FLAG_CF = 0;
  localparam int unsigned FLAG_PF = 2;
  localparam int unsigned FLAG_AF = 4;
  localparam int unsigned FLAG_ZF = 6;
  localparam int unsigned FLAG_SF = 7;
  localparam int unsigned FLAG_TF = 8;
  localparam int unsigned FLAG_IF = 9;
  localparam int unsigned FLAG_DF = 10;
  localparam int unsigned FLAG_OF = 11;

  // Mask of the six arithmetic status flags.
  localparam logic [31:0] STATUS_FLAGS = 32'h0000_08D5;

  // ALU operation codes. 0..7 follow the x86 /reg and opcode[5:3] encoding.
  localparam logic [3:0] ALU_ADD = 4'd0;
  localparam logic [3:0] ALU_OR  = 4'd1;
  localparam logic [3:0] ALU_ADC = 4'd2;
  localparam logic [3:0] ALU_SBB = 4'd3;
  localparam logic [3:0] ALU_AND = 4'd4;
  localparam logic [3:0] ALU_SUB = 4'd5;
  localparam logic [3:0] ALU_XOR = 4'd6;
  localparam logic [3:0] ALU_CMP = 4'd7;
  localparam logic [3:0] ALU_INC = 4'd8;
  localparam logic [3:0] ALU_DEC = 4'd9;
  localparam logic [3:0] ALU_NEG = 4'd10;

  function automatic logic [31:0] size_mask(input logic [1:0] size);
    case (size)
      2'd0:    size_mask = 32'h0000_00FF;
      2'd1:    size_mask = 32'h0000_FFFF;
      default: size_mask = 32'hFFFF_FFFF;
    endcase
  endfunction

  function automatic logic sign_bit(input logic [31:0] value, input logic [1:0] size);
    case (size)
      2'd0:    sign_bit = value[7];
      2'd1:    sign_bit = value[15];
      default: sign_bit = value[31];
    endcase
  endfunction

  function automatic logic [31:0] sign_extend(input logic [31:0] value, input logic [1:0] size);
    case (size)
      2'd0:    sign_extend = {{24{value[7]}}, value[7:0]};
      2'd1:    sign_extend = {{16{value[15]}}, value[15:0]};
      default: sign_extend = value;
    endcase
  endfunction

  // PF, ZF and SF for a result of the given size, in EFLAGS positions.
  function automatic logic [31:0] result_flags(input logic [31:0] value, input logic [1:0] size);
    logic [31:0] f;
    f = 32'b0;
    f[FLAG_PF] = ~^value[7:0];
    f[FLAG_ZF] = (value & size_mask(size)) == 32'b0;
    f[FLAG_SF] = sign_bit(value, size);
    result_flags = f;
  endfunction

  // Returns {flags[31:0], result[31:0]}. Only CF/PF/AF/ZF/SF/OF are driven.
  // INC and DEC return the input CF so callers may merge all six flags.
  // ASSUMPTION: A3. Logical operations clear AF (the manual leaves it
  // undefined); the capture replay masks AF for those opcodes.
  function automatic logic [63:0] alu(input logic [3:0] op, input logic [1:0] size,
                                      input logic [31:0] a_in, input logic [31:0] b_in,
                                      input logic carry_in);
    logic [31:0] mask, a, b, r, f;
    logic [32:0] wide;
    logic arithmetic, subtract;
    mask = size_mask(size);
    a = a_in & mask;
    b = b_in & mask;
    wide = 33'b0;
    arithmetic = 1'b1;
    subtract = 1'b0;
    case (op)
      ALU_ADD: wide = {1'b0, a} + {1'b0, b};
      ALU_ADC: wide = {1'b0, a} + {1'b0, b} + {32'b0, carry_in};
      ALU_SUB, ALU_CMP: begin wide = {1'b0, a} - {1'b0, b}; subtract = 1'b1; end
      ALU_SBB: begin wide = {1'b0, a} - {1'b0, b} - {32'b0, carry_in}; subtract = 1'b1; end
      ALU_INC: begin b = 32'd1; wide = {1'b0, a} + 33'd1; end
      ALU_DEC: begin b = 32'd1; wide = {1'b0, a} - 33'd1; subtract = 1'b1; end
      ALU_NEG: begin b = a; a = 32'b0; wide = 33'b0 - {1'b0, b}; subtract = 1'b1; end
      ALU_OR:  begin wide = {1'b0, a | b}; arithmetic = 1'b0; end
      ALU_AND: begin wide = {1'b0, a & b}; arithmetic = 1'b0; end
      default: begin wide = {1'b0, a ^ b}; arithmetic = 1'b0; end
    endcase
    r = wide[31:0] & mask;
    f = result_flags(r, size);
    if (arithmetic) begin
      case (size)
        2'd0:    f[FLAG_CF] = wide[8];
        2'd1:    f[FLAG_CF] = wide[16];
        default: f[FLAG_CF] = wide[32];
      endcase
      f[FLAG_AF] = a[4] ^ b[4] ^ r[4];
      if (subtract)
        f[FLAG_OF] = sign_bit((a ^ b) & (a ^ r), size);
      else
        f[FLAG_OF] = sign_bit((a ^ r) & (b ^ r), size);
      if (op == ALU_INC || op == ALU_DEC) f[FLAG_CF] = carry_in;
    end
    alu = {f, r};
  endfunction

  // Shift/rotate group (/reg encoding 0..7: ROL ROR RCL RCR SHL SHR SAL SAR).
  // Returns {update_mask[31:0], flags[31:0], result[31:0]}.
  // The count is masked to five bits as on the 386; RCL/RCR rotate through
  // CF modulo size+1. CF is the last bit shifted or rotated out. Whenever the
  // masked count is nonzero, OF is recomputed from the final result:
  // ROL/RCL/SHL/SAL use MSB(result) XOR CF, the right shifts and rotates use
  // MSB(result) XOR MSB-1(result). These rules, the OF update of an RCL/RCR
  // whose effective count is zero, and the byte SHL/SHR carry for counts 16
  // and 24 (CF as for a count of 8) were measured on the pinned 386EX
  // captures (files D2.x, D3.x) where the manual leaves the flags undefined.
  function automatic logic [95:0] shift(input logic [2:0] op, input logic [1:0] size,
                                        input logic [31:0] value, input logic [7:0] count_in,
                                        input logic [31:0] flags_in);
    logic [31:0] mask, r, f, update;
    logic [5:0] count;
    logic cf, top, prev_top;
    integer i;
    mask = size_mask(size);
    r = value & mask;
    f = flags_in;
    cf = flags_in[FLAG_CF];
    count = {1'b0, count_in[4:0]};
    update = 32'b0;
    if (count != 6'd0) begin
      if (op == 3'd2 || op == 3'd3) begin
        if (size == 2'd0) count = count % 6'd9;
        else if (size == 2'd1) count = count % 6'd17;
      end
      for (i = 0; i < 32; i = i + 1) begin
        if (i < count) begin
          top = sign_bit(r, size);
          case (op)
            3'd0: begin cf = top; r = ((r << 1) | {31'b0, top}) & mask; end
            3'd1: begin cf = r[0];
                        r = (r >> 1) | (cf ? (mask & ~(mask >> 1)) : 32'b0); end
            3'd2: begin prev_top = top; r = ((r << 1) | {31'b0, cf}) & mask; cf = prev_top; end
            3'd3: begin prev_top = r[0];
                        r = (r >> 1) | (cf ? (mask & ~(mask >> 1)) : 32'b0);
                        cf = prev_top; end
            3'd4, 3'd6: begin cf = top; r = (r << 1) & mask; end
            3'd5: begin cf = r[0]; r = r >> 1; end
            default: begin cf = r[0];
                           r = (r >> 1) | (top ? (mask & ~(mask >> 1)) : 32'b0); end
          endcase
        end
      end
      if (size == 2'd0 && count_in[4:3] != 2'b00 && count_in[4:3] != 2'b01 &&
          count_in[2:0] == 3'd0 && (op == 3'd4 || op == 3'd5 || op == 3'd6))
        cf = (op == 3'd5) ? value[7] : value[0];
      update[FLAG_CF] = 1'b1;
      update[FLAG_OF] = 1'b1;
      if (op >= 3'd4) begin
        f = (f & ~(32'h0000_00D4)) | result_flags(r, size);
        f[FLAG_AF] = 1'b0;
        update[FLAG_PF] = 1'b1;
        update[FLAG_AF] = 1'b1;
        update[FLAG_ZF] = 1'b1;
        update[FLAG_SF] = 1'b1;
      end
      f[FLAG_CF] = cf;
      if (op == 3'd0 || op == 3'd2 || op == 3'd4 || op == 3'd6)
        f[FLAG_OF] = sign_bit(r, size) ^ cf;
      else
        f[FLAG_OF] = sign_bit(r, size) ^ sign_bit(r << 1, size);
    end
    shift = {update, f, r};
  endfunction

  // SHLD (left=1) / SHRD (left=0): shift dest by count, filling from src.
  // Returns {update_mask, flags, result} like shift(). Count is masked to
  // five bits; a zero count changes nothing.
  // For 16-bit operands with count > 16 (manual: result undefined) the
  // pinned 386EX captures (0F A4/A5/AC/AD) match a 48-bit field
  // dest:src:src (SHLD) or src:src:dest (SHRD): the source refills itself.
  function automatic logic [95:0] double_shift(input logic left, input logic [1:0] size,
                                               input logic [31:0] dest, input logic [31:0] src,
                                               input logic [7:0] count_in,
                                               input logic [31:0] flags_in);
    logic [31:0] mask, r, s, f, update;
    logic cf, of, top;
    integer i;
    mask = size_mask(size);
    r = dest & mask;
    s = src & mask;
    f = flags_in;
    cf = flags_in[FLAG_CF];
    of = flags_in[FLAG_OF];
    update = 32'b0;
    if (count_in[4:0] != 5'd0) begin
      for (i = 0; i < 32; i = i + 1) begin
        if (i < count_in[4:0]) begin
          top = sign_bit(r, size);
          if (left) begin
            cf = top;
            r = ((r << 1) | {31'b0, sign_bit(s, size)}) & mask;
            s = ((s << 1) | {31'b0, sign_bit(s, size)}) & mask;
          end else begin
            cf = r[0];
            r = (r >> 1) | (s[0] ? (mask & ~(mask >> 1)) : 32'b0);
            s = (s >> 1) | (s[0] ? (mask & ~(mask >> 1)) : 32'b0);
          end
          of = top ^ sign_bit(r, size);
        end
      end
      f = (f & ~(32'h0000_00D4)) | result_flags(r, size);
      f[FLAG_AF] = 1'b0;
      f[FLAG_CF] = cf;
      f[FLAG_OF] = of;
      update = STATUS_FLAGS;
    end
    double_shift = {update, f, r};
  endfunction

  // Condition codes for Jcc/SETcc (low four opcode bits).
  function automatic logic condition(input logic [3:0] cc, input logic [31:0] fl);
    logic c;
    case (cc[3:1])
      3'd0: c = fl[FLAG_OF];
      3'd1: c = fl[FLAG_CF];
      3'd2: c = fl[FLAG_ZF];
      3'd3: c = fl[FLAG_CF] | fl[FLAG_ZF];
      3'd4: c = fl[FLAG_SF];
      3'd5: c = fl[FLAG_PF];
      3'd6: c = fl[FLAG_SF] ^ fl[FLAG_OF];
      default: c = (fl[FLAG_SF] ^ fl[FLAG_OF]) | fl[FLAG_ZF];
    endcase
    condition = c ^ cc[0];
  endfunction

  /* verilator lint_on UNUSEDPARAM */
  /* verilator lint_on UNUSEDSIGNAL */
endpackage
