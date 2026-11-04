// Zilog Z80 functional core (register-execution subset).
//
// Transaction-bus engine: one implementation step per rising edge, one bus
// transfer per step, architectural state advances only on an acknowledged
// transfer.
//
// Scope of this milestone: NOP; 8-bit and 16-bit loads that do not touch memory;
// LD r,r'; LD r,n; the ALU group on registers and immediates; INC/DEC (8- and
// 16-bit); ADD HL,rr; DAA; CPL; SCF; CCF; RLCA/RRCA/RLA/RRA; JR/JR cc/DJNZ;
// JP nn/JP cc,nn/JP (HL); EX AF,AF'/EX DE,HL/EXX; DI; EI; HALT; and the CB page
// on registers (rotate/shift/BIT/RES/SET).
//
// Any other encoding (memory operands, stack, CALL/RET/RST, PUSH/POP, the ED
// and DD/FD pages, block instructions, I/O) raises sticky fault_o and never
// retires, so a harness can distinguish "unimplemented" from "wrong".
//
// ASSUMPTION: general registers and F are undefined after reset on the real
// part; the model zeroes them so tests are reproducible.
// ASSUMPTION: interrupt entry, the EI one-instruction delay and the Q latch's
// effect on SCF/CCF are not implemented in this milestone.
module zilog_z80
  import zilog_z80_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    output logic        bus_req_o,
    input  logic        bus_ready_i,
    output logic        bus_write_o,
    output logic [15:0] bus_addr_o,
    output logic [7:0]  bus_wdata_o,
    input  logic [7:0]  bus_rdata_i,
    output logic        bus_io_o,
    output logic        bus_intack_o,

    input  logic        int_i,
    input  logic        nmi_i,

    output logic        retire_o,
    output logic        fault_o,
    output logic        halt_o,
    output logic        iff1_o,
    output logic [1:0]  im_o,

    output logic [15:0] pc_o,
    output logic [15:0] sp_o,
    output logic [15:0] ix_o,
    output logic [15:0] iy_o,
    output logic [15:0] wz_o,
    output logic [7:0]  i_o,
    output logic [7:0]  r_o,
    output logic [63:0] regs_o,   // {A,F,B,C,D,E,H,L}
    output logic [63:0] alt_o     // {A',F',B',C',D',E',H',L'}
);

  logic [7:0]  a, f, b, c, d, e, h, l;
  logic [7:0]  a_alt, f_alt, b_alt, c_alt, d_alt, e_alt, h_alt, l_alt;
  logic [15:0] ix, iy, sp, pc, wz;
  logic [7:0]  i_reg, r_reg;
  logic        iff1, iff2;
  logic [1:0]  im;
  logic        halted;

  logic [7:0]  ir;
  logic [7:0]  cb_op;
  logic [7:0]  imm1, imm2;

  typedef enum logic [2:0] {S_FETCH, S_PFX, S_IMM1, S_IMM2, S_EXEC, S_HALTED,
                            S_FAULT} state_t;
  state_t state;

  // ------------------------------------------------------------- register IO
  function automatic logic [7:0] get_r(input logic [2:0] idx);
    case (idx)
      3'd0: return b;
      3'd1: return c;
      3'd2: return d;
      3'd3: return e;
      3'd4: return h;
      3'd5: return l;
      3'd7: return a;
      default: return 8'h00;
    endcase
  endfunction

  function automatic logic [15:0] get_rp(input logic [1:0] idx);
    case (idx)
      2'd0: return {b, c};
      2'd1: return {d, e};
      2'd2: return {h, l};
      default: return sp;
    endcase
  endfunction

  function automatic logic cond_true(input logic [2:0] cc, input logic [7:0] ff);
    case (cc)
      CC_NZ:   return ~ff[FLAG_Z];
      CC_Z:    return ff[FLAG_Z];
      CC_NC:   return ~ff[FLAG_C];
      CC_C:    return ff[FLAG_C];
      CC_PO:   return ~ff[FLAG_PV];
      CC_PE:   return ff[FLAG_PV];
      CC_P:    return ~ff[FLAG_S];
      default: return ff[FLAG_S];
    endcase
  endfunction

  // Supported (implemented) encodings of this milestone.
  function automatic logic supported(input logic [7:0] op);
    if (op == 8'h00 || op == 8'h76) return 1'b1;                    // NOP / HALT
    if (op == 8'h08 || op == 8'hEB || op == 8'hD9) return 1'b1;      // EX/EXX
    if (op == 8'h07 || op == 8'h0F || op == 8'h17 || op == 8'h1F) return 1'b1;
    if (op == 8'h27 || op == 8'h2F || op == 8'h37 || op == 8'h3F) return 1'b1;
    if (op == 8'hF3 || op == 8'hFB || op == 8'hE9) return 1'b1;      // DI/EI/JP (HL)
    if (op == 8'h10 || op == 8'h18) return 1'b1;                     // DJNZ / JR
    if (op[7:3] == 5'b00100 && op[2:0] == 3'd0) return 1'b1;         // JR cc
    // LD rr,nn (low page only; 0x41/0x49/... are LD r,r')
    if (op[7:6] == 2'b00 && op[2:0] == 3'd1 && op[3] == 1'b0) return 1'b1;
    // INC/DEC rr
    if (op[2:0] == 3'd3 && op[7:6] == 2'b00) return 1'b1;
    if (op[7:6] == 2'b00 && op[2:0] == 3'd1 && op[3] == 1'b1) return 1'b1;  // ADD HL,rr
    // LD r,(HL) forms are NOT supported; the register forms follow.
    if (op >= 8'h40 && op <= 8'h7F) begin
      if (op[2:0] == 3'd6 || op[5:3] == 3'd6) return 1'b0;           // (HL)
      return 1'b1;
    end
    if (op >= 8'h70 && op <= 8'h77) return 1'b0;
    if (op >= 8'h80 && op <= 8'hBF) begin
      if (op[2:0] == 3'd6) return 1'b0;                              // (HL)
      return 1'b1;
    end
    // LD r,n on the low page must exclude 0x36 (LD (HL),n).
    if (op[7:6] == 2'b00 && op[2:0] == 3'd6) return (op[5:3] != 3'd6);
    if (op[7:6] == 2'b00 && (op[2:0] == 3'd4 || op[2:0] == 3'd5) &&
        op[5:3] != 3'd6) return 1'b1;                                // INC/DEC r
    // High page: ALU n, JP nn / JP cc,nn.
    if (op[7:6] == 2'b11 && op[2:0] == 3'd6) return 1'b1;            // ALU n
    if (op[7:6] == 2'b11 && op[2:0] == 3'd2) return 1'b1;            // JP cc,nn
    if (op == 8'hC3) return 1'b1;
    return 1'b0;
  endfunction

  // Immediate byte count for supported encodings.
  function automatic logic [1:0] imm_count(input logic [7:0] op);
    if (op[7:6] == 2'b00) begin
      if (op[2:0] == 3'd1 && op[3] == 1'b0) return 2'd2;   // LD rr,nn
      if (op[2:0] == 3'd6) return 2'd1;                    // LD r,n
      if (op == 8'h10 || op == 8'h18) return 2'd1;         // DJNZ / JR
      if (op[7:3] == 5'b00100 && op[2:0] == 3'd0) return 2'd1;  // JR cc
      return 2'd0;
    end
    if (op[7:6] == 2'b11) begin
      if (op[2:0] == 3'd6) return 2'd1;                    // ALU A,n
      if (op[2:0] == 3'd2) return 2'd2;                    // JP cc,nn
      if (op == 8'hC3) return 2'd2;                        // JP nn
      return 2'd0;
    end
    return 2'd0;
  endfunction

  // ------------------------------------------------------------- ALU request
  logic [7:0]  alu_a, alu_b, alu_y, alu_f;
  alu_op_t     alu_op;
  logic        alu_cin;
  logic [2:0]  alu_bitnum;

  always_comb begin
    alu_a      = a;
    alu_b      = 8'h00;
    alu_op     = ALU_ADD;
    alu_bitnum = 3'd0;

    if (ir == 8'hCB) begin
      alu_a      = get_r(cb_op[2:0]);
      alu_b      = get_r(cb_op[2:0]);
      alu_bitnum = cb_op[5:3];
      if (cb_op[7:6] == 2'b00) begin
        case (cb_op[5:3])
          3'd0: alu_op = ALU_RLC;
          3'd1: alu_op = ALU_RRC;
          3'd2: alu_op = ALU_RL;
          3'd3: alu_op = ALU_RR;
          3'd4: alu_op = ALU_SLA;
          3'd5: alu_op = ALU_SRA;
          3'd6: alu_op = ALU_SLL;
          default: alu_op = ALU_SRL;
        endcase
      end else if (cb_op[7:6] == 2'b01) begin
        alu_op = ALU_BIT;
      end
    end else if (ir >= 8'h80 && ir <= 8'hBF && ir[2:0] != 3'd6) begin
      alu_b = get_r(ir[2:0]);
      case (ir[5:3])
        3'd0: alu_op = ALU_ADD;
        3'd1: alu_op = ALU_ADC;
        3'd2: alu_op = ALU_SUB;
        3'd3: alu_op = ALU_SBC;
        3'd4: alu_op = ALU_AND;
        3'd5: alu_op = ALU_XOR;
        3'd6: alu_op = ALU_OR;
        default: alu_op = ALU_CP;
      endcase
    end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd6) begin
      alu_b = imm1;
      case (ir[5:3])
        3'd0: alu_op = ALU_ADD;
        3'd1: alu_op = ALU_ADC;
        3'd2: alu_op = ALU_SUB;
        3'd3: alu_op = ALU_SBC;
        3'd4: alu_op = ALU_AND;
        3'd5: alu_op = ALU_XOR;
        3'd6: alu_op = ALU_OR;
        default: alu_op = ALU_CP;
      endcase
    end else if (ir == 8'h27) begin
      alu_op = ALU_DAA;
    end else if (ir == 8'h2F) begin
      alu_op = ALU_CPL;
    end else if (ir == 8'h07) begin
      alu_op = ALU_RLC;
    end else if (ir == 8'h0F) begin
      alu_op = ALU_RRC;
    end else if (ir == 8'h17) begin
      alu_op = ALU_RL;
    end else if (ir == 8'h1F) begin
      alu_op = ALU_RR;
    end else if (ir[2:0] == 3'd4 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
      alu_a  = get_r(ir[5:3]);
      alu_b  = 8'h01;
      alu_op = ALU_INC;
    end else if (ir[2:0] == 3'd5 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
      alu_a  = get_r(ir[5:3]);
      alu_b  = 8'h01;
      alu_op = ALU_DEC;
    end

    // Only ADC/SBC/RL/RR consume the carry flag as a data input; plain
    // ADD/SUB/CP/AND/OR/XOR/INC/DEC must add zero.
    alu_cin = (alu_op == ALU_ADC || alu_op == ALU_SBC || alu_op == ALU_RL ||
               alu_op == ALU_RR) ? f[FLAG_C] : 1'b0;
  end

  zilog_z80_alu u_alu (
      .op     (alu_op),
      .a      (alu_a),
      .b      (alu_b),
      .cin    (alu_cin),
      .f_in   (f),
      .bitnum (alu_bitnum),
      .y      (alu_y),
      .flags  (alu_f)
  );

  // ------------------------------------------------------------- bus outputs
  always_comb begin
    bus_req_o    = (state == S_FETCH) || (state == S_PFX) || (state == S_IMM1) ||
                   (state == S_IMM2);
    bus_write_o  = 1'b0;
    bus_addr_o   = pc;
    bus_wdata_o  = 8'h00;
    bus_io_o     = 1'b0;
    bus_intack_o = 1'b0;
  end

  // --------------------------------------------------------------- sequencer
  logic [12:0] half_sum;
  logic [16:0] full_sum;
  logic [15:0] hl_val;
  logic [15:0] rp_val;

  always_comb begin
    hl_val   = {h, l};
    rp_val   = get_rp(ir[5:4]);
    half_sum = {1'b0, hl_val[11:0]} + {1'b0, rp_val[11:0]};
    full_sum = {1'b0, hl_val} + {1'b0, rp_val};
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state    <= S_FETCH;
      pc       <= 16'h0000;
      sp       <= 16'h0000;
      ix       <= 16'h0000;
      iy       <= 16'h0000;
      wz       <= 16'h0000;
      i_reg    <= 8'h00;
      r_reg    <= 8'h00;
      iff1     <= 1'b0;
      iff2     <= 1'b0;
      im       <= 2'b00;
      halted   <= 1'b0;
      fault_o  <= 1'b0;
      retire_o <= 1'b0;
      ir       <= 8'h00;
      cb_op    <= 8'h00;
      imm1     <= 8'h00;
      imm2     <= 8'h00;
      a <= 8'h00; f <= 8'h00; b <= 8'h00; c <= 8'h00;
      d <= 8'h00; e <= 8'h00; h <= 8'h00; l <= 8'h00;
      a_alt <= 8'h00; f_alt <= 8'h00; b_alt <= 8'h00; c_alt <= 8'h00;
      d_alt <= 8'h00; e_alt <= 8'h00; h_alt <= 8'h00; l_alt <= 8'h00;
    end else begin
      retire_o <= 1'b0;

      case (state)
        S_FETCH: begin
          if (bus_ready_i) begin
            ir    <= bus_rdata_i;
            pc    <= pc + 16'd1;
            r_reg <= {r_reg[7], r_reg[6:0] + 7'd1};
            imm1  <= 8'h00;
            imm2  <= 8'h00;
            if (bus_rdata_i == 8'hCB) begin
              state <= S_PFX;
            end else if (!supported(bus_rdata_i)) begin
              fault_o <= 1'b1;
              state   <= S_FAULT;
            end else if (imm_count(bus_rdata_i) == 2'd0) begin
              state <= S_EXEC;
            end else begin
              state <= S_IMM1;
            end
          end
        end

        S_PFX: begin
          if (bus_ready_i) begin
            cb_op <= bus_rdata_i;
            pc    <= pc + 16'd1;
            r_reg <= {r_reg[7], r_reg[6:0] + 7'd1};
            if (bus_rdata_i[2:0] == 3'd6) begin
              fault_o <= 1'b1;      // (HL) forms need the memory path
              state   <= S_FAULT;
            end else begin
              state <= S_EXEC;
            end
          end
        end

        S_IMM1: begin
          if (bus_ready_i) begin
            imm1  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            state <= (imm_count(ir) == 2'd2) ? S_IMM2 : S_EXEC;
          end
        end

        S_IMM2: begin
          if (bus_ready_i) begin
            imm2  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            state <= S_EXEC;
          end
        end

        S_EXEC: begin
          // ---- CB page (registers only) --------------------------------
          if (ir == 8'hCB) begin
            case (cb_op[7:6])
              2'b00: begin                        // rotate/shift
                case (cb_op[2:0])
                  3'd0: b <= alu_y;
                  3'd1: c <= alu_y;
                  3'd2: d <= alu_y;
                  3'd3: e <= alu_y;
                  3'd4: h <= alu_y;
                  3'd5: l <= alu_y;
                  default: a <= alu_y;
                endcase
                f <= alu_f;
              end
              2'b01: begin                        // BIT
                f <= alu_f;                       // ALU already keeps C
              end
              2'b10: begin                        // RES
                case (cb_op[2:0])
                  3'd0: b <= b & ~(8'h01 << cb_op[5:3]);
                  3'd1: c <= c & ~(8'h01 << cb_op[5:3]);
                  3'd2: d <= d & ~(8'h01 << cb_op[5:3]);
                  3'd3: e <= e & ~(8'h01 << cb_op[5:3]);
                  3'd4: h <= h & ~(8'h01 << cb_op[5:3]);
                  3'd5: l <= l & ~(8'h01 << cb_op[5:3]);
                  default: a <= a & ~(8'h01 << cb_op[5:3]);
                endcase
              end
              default: begin                      // SET
                case (cb_op[2:0])
                  3'd0: b <= b | (8'h01 << cb_op[5:3]);
                  3'd1: c <= c | (8'h01 << cb_op[5:3]);
                  3'd2: d <= d | (8'h01 << cb_op[5:3]);
                  3'd3: e <= e | (8'h01 << cb_op[5:3]);
                  3'd4: h <= h | (8'h01 << cb_op[5:3]);
                  3'd5: l <= l | (8'h01 << cb_op[5:3]);
                  default: a <= a | (8'h01 << cb_op[5:3]);
                endcase
              end
            endcase
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h00) begin         // NOP
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h76) begin         // HALT
            halted   <= 1'b1;
            retire_o <= 1'b1;
            state    <= S_HALTED;
          end else if (ir == 8'h08) begin         // EX AF,AF'
            a <= a_alt; f <= f_alt;
            a_alt <= a; f_alt <= f;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hEB) begin         // EX DE,HL
            {d, e} <= {h, l};
            {h, l} <= {d, e};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hD9) begin         // EXX
            {b, c, d, e, h, l} <= {b_alt, c_alt, d_alt, e_alt, h_alt, l_alt};
            {b_alt, c_alt, d_alt, e_alt, h_alt, l_alt} <= {b, c, d, e, h, l};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hF3) begin         // DI
            iff1 <= 1'b0; iff2 <= 1'b0;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hFB) begin         // EI
            iff1 <= 1'b1; iff2 <= 1'b1;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hE9) begin         // JP (HL)
            pc <= {h, l};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h10) begin         // DJNZ e
            b <= b - 8'h01;
            if ((b - 8'h01) != 8'h00)
              pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h18) begin         // JR e
            pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[7:3] == 5'b00100 && ir[2:0] == 3'd0) begin  // JR cc,e
            // The condition is encoded in bits 4:3; bit 5 belongs to the opcode.
            if (cond_true({1'b0, ir[4:3]}, f)) pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h27 || ir == 8'h2F) begin   // DAA / CPL
            a <= alu_y;
            f <= alu_f;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h37) begin         // SCF
            f <= {f[FLAG_S], f[FLAG_Z], a[5], 1'b0, a[3], f[FLAG_PV], 1'b0, 1'b1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h3F) begin         // CCF
            f <= {f[FLAG_S], f[FLAG_Z], a[5], f[FLAG_C], a[3], f[FLAG_PV],
                  1'b0, ~f[FLAG_C]};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'h07 || ir == 8'h0F || ir == 8'h17 || ir == 8'h1F) begin
            // A rotates: S, Z and P/V are preserved; H = 0, N = 0.
            a <= alu_y;
            f <= {f[FLAG_S], f[FLAG_Z], alu_f[FLAG_F5], 1'b0, alu_f[FLAG_F3],
                  f[FLAG_PV], 1'b0, alu_f[FLAG_C]};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd3 && ir[7:6] == 2'b00 && ir[3] == 1'b0) begin
            // INC rr
            case (ir[5:4])
              2'd0: {b, c} <= {b, c} + 16'd1;
              2'd1: {d, e} <= {d, e} + 16'd1;
              2'd2: {h, l} <= {h, l} + 16'd1;
              default: sp <= sp + 16'd1;
            endcase
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd3 && ir[7:6] == 2'b00 && ir[3] == 1'b1) begin
            // DEC rr
            case (ir[5:4])
              2'd0: {b, c} <= {b, c} - 16'd1;
              2'd1: {d, e} <= {d, e} - 16'd1;
              2'd2: {h, l} <= {h, l} - 16'd1;
              default: sp <= sp - 16'd1;
            endcase
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd1 && ir[3] == 1'b1 && ir[7:6] == 2'b00) begin
            // ADD HL,rr
            {h, l} <= full_sum[15:0];
            f <= {f[FLAG_S], f[FLAG_Z], full_sum[13], half_sum[12], full_sum[11],
                  f[FLAG_PV], 1'b0, full_sum[16]};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd1 && ir[3] == 1'b0 && ir[7:6] == 2'b00) begin
            // LD rr,nn
            case (ir[5:4])
              2'd0: {b, c} <= {imm2, imm1};
              2'd1: {d, e} <= {imm2, imm1};
              2'd2: {h, l} <= {imm2, imm1};
              default: sp <= {imm2, imm1};
            endcase
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir == 8'hC3) begin          // JP nn
            pc <= {imm2, imm1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd2) begin  // JP cc,nn
            if (cond_true(ir[5:3], f)) pc <= {imm2, imm1};
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd6) begin  // ALU A,n
            if (ir[5:3] == 3'd7) begin
              f <= alu_f;
            end else begin
              a <= alu_y;
              f <= alu_f;
            end
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir >= 8'h80 && ir <= 8'hBF) begin  // ALU A,r
            if (ir[5:3] == 3'd7) begin
              f <= alu_f;
            end else begin
              a <= alu_y;
              f <= alu_f;
            end
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir >= 8'h40 && ir <= 8'h7F) begin  // LD r,r'
            case (ir[5:3])
              3'd0: b <= get_r(ir[2:0]);
              3'd1: c <= get_r(ir[2:0]);
              3'd2: d <= get_r(ir[2:0]);
              3'd3: e <= get_r(ir[2:0]);
              3'd4: h <= get_r(ir[2:0]);
              3'd5: l <= get_r(ir[2:0]);
              default: a <= get_r(ir[2:0]);
            endcase
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd4 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // INC r
            case (ir[5:3])
              3'd0: b <= alu_y;
              3'd1: c <= alu_y;
              3'd2: d <= alu_y;
              3'd3: e <= alu_y;
              3'd4: h <= alu_y;
              3'd5: l <= alu_y;
              default: a <= alu_y;
            endcase
            f <= alu_f;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd5 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // DEC r
            case (ir[5:3])
              3'd0: b <= alu_y;
              3'd1: c <= alu_y;
              3'd2: d <= alu_y;
              3'd3: e <= alu_y;
              3'd4: h <= alu_y;
              3'd5: l <= alu_y;
              default: a <= alu_y;
            endcase
            f <= alu_f;
            retire_o <= 1'b1; state <= S_FETCH;
          end else if (ir[2:0] == 3'd6 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // LD r,n
            case (ir[5:3])
              3'd0: b <= imm1;
              3'd1: c <= imm1;
              3'd2: d <= imm1;
              3'd3: e <= imm1;
              3'd4: h <= imm1;
              3'd5: l <= imm1;
              default: a <= imm1;
            endcase
            retire_o <= 1'b1; state <= S_FETCH;
          end else begin
            fault_o <= 1'b1;
            state   <= S_FAULT;
          end
        end

        S_HALTED: retire_o <= 1'b0;
        S_FAULT:  retire_o <= 1'b0;
        default:  state <= S_FETCH;
      endcase
    end
  end

  // ------------------------------------------------------------- observations
  assign pc_o   = pc;
  assign sp_o   = sp;
  assign ix_o   = ix;
  assign iy_o   = iy;
  assign wz_o   = wz;
  assign i_o    = i_reg;
  assign r_o    = r_reg;
  assign halt_o = halted;
  assign iff1_o = iff1;
  assign im_o   = im;
  assign regs_o = {a, f, b, c, d, e, h, l};
  assign alt_o  = {a_alt, f_alt, b_alt, c_alt, d_alt, e_alt, h_alt, l_alt};

endmodule
