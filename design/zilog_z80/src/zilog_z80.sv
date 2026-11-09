`include "zilog_z80_defs.svh"

// Zilog Z80 functional core.
//
// Transaction-bus engine: one implementation step per rising edge, one bus
// transfer per step, architectural state advances only on an acknowledged
// transfer.
//
// Implemented: NOP; LD r,r'; LD r,n; LD rr,nn; LD r,(HL); LD (HL),r;
// LD (HL),n; LD A,(BC)/(DE); LD (BC)/(DE),A; LD A,(nn); LD (nn),A;
// LD HL,(nn); LD (nn),HL; LD SP,HL; the ALU group on registers, immediates and
// (HL); INC/DEC (8-bit, 16-bit and (HL)); ADD HL,rr; DAA; CPL; SCF; CCF;
// RLCA/RRCA/RLA/RRA; JR/JR cc/DJNZ; JP nn/JP cc,nn/JP (HL);
// PUSH/POP/PUSH AF/POP AF; CALL/CALL cc/RET/RET cc/RST; EX AF,AF'/EX DE,HL/
// EXX/EX (SP),HL; DI; EI; HALT; and the CB page on registers and on (HL)
// including rotate/shift/RES/SET.
//
// Not implemented yet (each raises sticky fault_o and never retires, so a
// harness can tell "unimplemented" from "wrong"): BIT n,(HL) (its undocumented
// F3/F5 source is the WZ register, a later milestone), the ED page, the DD/FD
// index pages, block instructions, I/O, and interrupt entry.
//
// ASSUMPTION: general registers and F are undefined after reset on the real
// part; the model zeroes them so tests are reproducible.
// ASSUMPTION: interrupt entry, the EI one-instruction delay and the Q-latch
// effect on SCF/CCF are not implemented in this milestone.
module zilog_z80
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
    output logic [63:0] regs_o,
    output logic [63:0] alt_o
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

  // Memory-path state.
  logic [15:0] mem_addr;
  logic [7:0]  mem_data;
  logic [7:0]  aux_lo, aux_hi;
  logic [15:0] saved16;

  typedef enum logic [5:0] {
    MO_NONE,
    MO_LD_R,        // read -> register (aux_lo holds the index)
    MO_LD_MEM_R,    // write (source already in mem_data)
    MO_ALU,         // read -> ALU -> A/F
    MO_INC_MEM,
    MO_DEC_MEM,
    MO_CB_ROT,
    MO_CB_MOD,
    MO_CB_BIT,      // BIT n,(HL): flags only, no write-back
    MO_LD_A_IND,    // read -> A
    MO_LD_IND_A,    // write A
    MO_LD_HL_LO,
    MO_LD_HL_HI,
    MO_LD_NN_LO,    // write HL low, then high
    MO_LD_NN_HI,
    MO_PUSH_HI,
    MO_PUSH_LO,
    MO_POP_LO,
    MO_POP_HI,
    MO_CALL_HI,
    MO_CALL_LO,
    MO_RET_LO,
    MO_RET_HI,
    MO_RST_HI,
    MO_RST_LO,
    MO_EX_LO,
    MO_EX_HI,
    MO_EX_WLO,
    MO_EX_WHI,
    MO_ED_LD_LO,    // read low byte of (nn) for LD rr,(nn)
    MO_ED_LD_HI,
    MO_IN_R,        // I/O read -> register or flags only
    MO_IN_A,        // IN A,(n)
    MO_RRD,
    MO_RLD,
    MO_BLK_LD_R,    // LDI/LDD: read source
    MO_BLK_LD_W,    // LDI/LDD: write destination and update pointers
    MO_BLK_CP_R,    // CPI/CPD: read and compare
    MO_BLK_INI,     // INI/IND: port read
    MO_BLK_INI_W,   // INI/IND: store to (HL)
    MO_BLK_OUT_R,   // OUTI/OUTD: read (HL)
    MO_BLK_OUT_W,   // OUTI/OUTD: port write done
    MO_IPUSH_HI,    // interrupt: push PC high
    MO_IPUSH_LO,    // interrupt: push PC low, then vector
    MO_IACK,        // interrupt acknowledge byte
    MO_IVEC_LO,     // IM 2: handler address low
    MO_IVEC_HI,     // IM 2: handler address high
    MO_WR_RET       // plain write that retires
  } mem_op_t;

  mem_op_t mem_op;

  logic        is_ed;
  logic [7:0]  ed_op;

  // Interrupt bookkeeping.
  logic [1:0]  ei_block;    // blocks INT acceptance for one instruction after EI
  logic        nmi_prev;    // NMI edge detection
  logic        int_nmi;     // current sequence is an NMI
  logic        nmi_pending; // latched NMI edge
  logic [7:0]  iack_byte;
  logic [15:0] int_vec;

  // Index-prefix state: 0 = HL, 1 = IX (DD), 2 = IY (FD).
  logic [1:0]  pfx;
  logic [7:0]  disp;

  typedef enum logic [4:0] {
    S_FETCH, S_PFX, S_IMM1, S_IMM2, S_EXEC, S_MRD, S_MWR, S_ED, S_IORD, S_IOWR,
    S_EXEC_ED, S_IDX, S_IDX_D, S_DCB_D, S_DCB_OP, S_IACK, S_IPUSH_HI,
    S_IPUSH_LO, S_IVEC_LO, S_IVEC_HI, S_HALTED, S_FAULT
  } state_t;
  state_t state;

  // ------------------------------------------------------------- register IO
  function automatic logic [7:0] get_r(input logic [2:0] idx);
    case (idx)
      3'd0: get_r = b;
      3'd1: get_r = c;
      3'd2: get_r = d;
      3'd3: get_r = e;
      3'd4: get_r = h;
      3'd5: get_r = l;
      3'd7: get_r = a;
      default: get_r = 8'h00;
    endcase
  endfunction

  function automatic logic [15:0] get_rp(input logic [1:0] idx);
    case (idx)
      2'd0: get_rp = {b, c};
      2'd1: get_rp = {d, e};
      2'd2: get_rp = xhl;
      default: get_rp = sp;
    endcase
  endfunction

  function automatic logic [7:0] get_rp_hi(input logic [1:0] idx);
    case (idx)
      2'd0: get_rp_hi = b;
      2'd1: get_rp_hi = d;
      2'd2: get_rp_hi = xh;
      default: get_rp_hi = 8'h00;  // AF is handled separately
    endcase
  endfunction

  function automatic logic [7:0] get_rp_lo(input logic [1:0] idx);
    case (idx)
      2'd0: get_rp_lo = c;
      2'd1: get_rp_lo = e;
      2'd2: get_rp_lo = xl;
      default: get_rp_lo = 8'h00;
    endcase
  endfunction

  function automatic logic cond_true(input logic [2:0] cc, input logic [7:0] ff);
    case (cc)
      CC_NZ:   cond_true = ~ff[FLAG_Z];
      CC_Z:    cond_true = ff[FLAG_Z];
      CC_NC:   cond_true = ~ff[FLAG_C];
      CC_C:    cond_true = ff[FLAG_C];
      CC_PO:   cond_true = ~ff[FLAG_PV];
      CC_PE:   cond_true = ff[FLAG_PV];
      CC_P:    cond_true = ~ff[FLAG_S];
      default: cond_true = ff[FLAG_S];
    endcase
  endfunction

  // --------------------------------------------------------------- support set
  // DD/ED/FD are prefix bytes; their pages are not implemented yet, so they
  // must fault rather than be mistaken for a like-numbered instruction.
  function automatic logic supported(input logic [7:0] op);
    supported = 1'b0;
    if (op == 8'hDD || op == 8'hED || op == 8'hFD) supported = 1'b0;
    else if (op == 8'h00 || op == 8'h76) supported = 1'b1;                // NOP / HALT
    else if (op == 8'h08 || op == 8'hEB || op == 8'hD9) supported = 1'b1; // EX/EXX
    else if (op == 8'h07 || op == 8'h0F || op == 8'h17 || op == 8'h1F) supported = 1'b1;
    else if (op == 8'h27 || op == 8'h2F || op == 8'h37 || op == 8'h3F) supported = 1'b1;
    else if (op == 8'hF3 || op == 8'hFB || op == 8'hE9 || op == 8'hF9) supported = 1'b1;
    else if (op == 8'h10 || op == 8'h18) supported = 1'b1;                // DJNZ / JR
    else if (op[7:5] == 3'b001 && op[2:0] == 3'd0) supported = 1'b1;      // JR cc
    else if (op == 8'h0A || op == 8'h1A || op == 8'h02 || op == 8'h12) supported = 1'b1;
    else if (op == 8'h22 || op == 8'h2A || op == 8'h32 || op == 8'h3A) supported = 1'b1;
    else if (op == 8'h36) supported = 1'b1;                               // LD (HL),n
    else if (op == 8'h34 || op == 8'h35) supported = 1'b1;                // INC/DEC (HL)
    else if (op == 8'hD3 || op == 8'hDB) supported = 1'b1;               // OUT (n),A / IN A,(n)
    else if (op == 8'hC9 || op == 8'hCD || op == 8'hE3) supported = 1'b1;
    else if (op == 8'hC3) supported = 1'b1;
    else if (op[7:6] == 2'b00 && op[2:0] == 3'd1 && op[3] == 1'b0) supported = 1'b1;  // LD rr,nn
    else if (op[2:0] == 3'd3 && op[7:6] == 2'b00) supported = 1'b1;       // INC/DEC rr
    else if (op[7:6] == 2'b00 && op[2:0] == 3'd1 && op[3] == 1'b1) supported = 1'b1;  // ADD HL,rr
    else if (op >= 8'h40 && op <= 8'h7F) supported = 1'b1;                // LD r,r' / (HL)
    else if (op >= 8'h80 && op <= 8'hBF) supported = 1'b1;                // ALU A,r / (HL)
    else if (op[7:6] == 2'b00 && op[2:0] == 3'd6 && op[5:3] != 3'd6) supported = 1'b1;
    else if (op[7:6] == 2'b00 && (op[2:0] == 3'd4 || op[2:0] == 3'd5) &&
             op[5:3] != 3'd6) supported = 1'b1;
    else if (op[7:6] == 2'b11 && (op[2:0] == 3'd6 || op[2:0] == 3'd2 ||
             op[2:0] == 3'd0 || op[2:0] == 3'd1 || op[2:0] == 3'd5 ||
             op[2:0] == 3'd4 || op[2:0] == 3'd7)) supported = 1'b1;
  endfunction

  // Opcodes whose (HL) operand becomes (IX+d)/(IY+d) and therefore consume a
  // displacement byte under a DD/FD prefix.
  function automatic logic needs_disp(input logic [7:0] op);
    needs_disp = (op == 8'h34) || (op == 8'h35) || (op == 8'h36) ||
                 (op >= 8'h70 && op <= 8'h77 && op != 8'h76) ||
                 ((op[2:0] == 3'd6) && (op != 8'h76) &&
                  ((op[7:6] == 2'b01) || (op[7:6] == 2'b10)));
  endfunction

  function automatic logic [1:0] imm_count(input logic [7:0] op);
    imm_count = 2'd0;
    if (op == 8'h22 || op == 8'h2A || op == 8'h32 || op == 8'h3A) imm_count = 2'd2;
    else if (op == 8'hCD) imm_count = 2'd2;
    else if (op[7:6] == 2'b11 && op[2:0] == 3'd4) imm_count = 2'd2;       // CALL cc,nn
    else if (op[7:6] == 2'b00 && op[2:0] == 3'd1 && op[3] == 1'b0) imm_count = 2'd2;
    else if (op[7:6] == 2'b00 && op[2:0] == 3'd6) imm_count = 2'd1;
    else if (op == 8'h10 || op == 8'h18) imm_count = 2'd1;
    else if (op == 8'hD3 || op == 8'hDB) imm_count = 2'd1;
    else if (op[7:5] == 3'b001 && op[2:0] == 3'd0) imm_count = 2'd1;
    else if (op[7:6] == 2'b11 && op[2:0] == 3'd6) imm_count = 2'd1;       // ALU A,n
    else if (op[7:6] == 2'b11 && op[2:0] == 3'd2) imm_count = 2'd2;       // JP cc,nn
    else if (op == 8'hC3) imm_count = 2'd2;
  endfunction

  /* verilator lint_off MULTIDRIVEN */
  // Write the effective HL pair: IX under DD, IY under FD, HL otherwise.
  // Declared before the sequencer; used with non-blocking assignments.
  task automatic wr_hl(input logic [15:0] v);
    if (pfx == 2'd1)
      ix <= v;
    else if (pfx == 2'd2)
      iy <= v;
    else
      {h, l} <= v;
  endtask

  // Write an 8-bit register; H/L become IXH/IXL when alias is set and a DD/FD
  // prefix is active (the undocumented aliases).
  task automatic wr_r(input logic [2:0] idx, input logic [7:0] v, input logic en_alias);
    case (idx)
      3'd0: b <= v;
      3'd1: c <= v;
      3'd2: d <= v;
      3'd3: e <= v;
      3'd4: if (en_alias && (pfx != 2'd0)) begin
              if (pfx == 2'd1) ix[15:8] <= v;
              else iy[15:8] <= v;
            end else h <= v;
      3'd5: if (en_alias && (pfx != 2'd0)) begin
              if (pfx == 2'd1) ix[7:0] <= v;
              else iy[7:0] <= v;
            end else l <= v;
      3'd7: a <= v;
      default: ;
    endcase
  endtask

  /* verilator lint_on MULTIDRIVEN */

  // ----------------------------------------------------------------- ALU wiring
  logic [7:0]  alu_a, alu_b, alu_y, alu_f;
  alu_op_t     alu_op;
  logic        alu_cin;
  logic [2:0]  alu_bitnum;

  always_comb begin
    alu_a      = a;
    alu_b      = 8'h00;
    alu_op     = ALU_ADD;
    alu_bitnum = 3'd0;

    if (state == S_MRD) begin
      // Memory-read forms: the operand is the byte arriving on the bus.
      if (ir == 8'hCB) begin
        alu_a      = bus_rdata_i;
        alu_b      = bus_rdata_i;
        alu_bitnum = cb_op[5:3];
        if (cb_op[7:6] == 2'b01) begin
          // BIT n,(HL)/(IX+d): F3/F5 come from the WZ high byte.
          alu_op = ALU_BIT;
          alu_b  = wz[15:8];
        end else begin
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
        end
      end else if (ir == 8'h34) begin
        alu_a  = bus_rdata_i;
        alu_b  = 8'h01;
        alu_op = ALU_INC;
      end else if (ir == 8'h35) begin
        alu_a  = bus_rdata_i;
        alu_b  = 8'h01;
        alu_op = ALU_DEC;
      end else begin
        alu_b = bus_rdata_i;
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
      end
    end else if (ir == 8'hCB) begin
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
      alu_b = r8(ir[2:0]);
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
    end else if (ir == 8'hED && (ed_op[2:0] == 3'd4) && (ed_op[7:6] == 2'b01)) begin
      // ED 44/4C/54/... NEG
      alu_a  = a;
      alu_op = ALU_NEG;
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
      alu_a  = r8(ir[5:3]);
      alu_b  = 8'h01;
      alu_op = ALU_INC;
    end else if (ir[2:0] == 3'd5 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
      alu_a  = r8(ir[5:3]);
      alu_b  = 8'h01;
      alu_op = ALU_DEC;
    end

    // Only ADC/SBC/RL/RR consume the carry flag as a data input.
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

  // -------------------------------------------------------------- bus outputs
  always_comb begin
    bus_req_o    = 1'b1;
    bus_write_o  = (state == S_MWR);
    bus_addr_o   = mem_addr;
    bus_wdata_o  = mem_data;
    bus_io_o     = 1'b0;
    bus_intack_o = 1'b0;

    case (state)
      S_FETCH, S_PFX, S_IMM1, S_IMM2, S_ED, S_IDX, S_IDX_D, S_DCB_D, S_DCB_OP: begin
        bus_write_o = 1'b0;
        bus_addr_o  = pc;
      end
      S_MRD: begin
        bus_write_o = 1'b0;
        bus_addr_o  = mem_addr;
      end
      S_MWR, S_IPUSH_HI, S_IPUSH_LO: begin
        bus_write_o = 1'b1;
        bus_addr_o  = mem_addr;
      end
      S_IVEC_LO, S_IVEC_HI: begin
        bus_write_o = 1'b0;
        bus_addr_o  = mem_addr;
      end
      S_IACK: begin
        bus_write_o  = 1'b0;
        bus_addr_o   = 16'h0000;   // the device supplies the byte on the data bus
        bus_io_o     = 1'b1;
        bus_intack_o = 1'b1;
      end
      S_IORD: begin
        bus_write_o = 1'b0;
        bus_addr_o  = mem_addr;
        bus_io_o    = 1'b1;
      end
      S_IOWR: begin
        bus_write_o = 1'b1;
        bus_addr_o  = mem_addr;
        bus_io_o    = 1'b1;
      end
      default: bus_req_o = 1'b0;
    endcase
  end

  // ---------------------------------------------------------------- sequencing
  logic [12:0] half_sum;
  logic [16:0] full_sum;
  logic [15:0] hl_val;
  logic [15:0] rp_val;

  always_comb begin
    hl_val   = xhl;
    rp_val   = get_rp(ir[5:4]);
    half_sum = {1'b0, hl_val[11:0]} + {1'b0, rp_val[11:0]};
    full_sum = {1'b0, hl_val} + {1'b0, rp_val};
  end

  // ---------------------------------------------------- index-register view
  logic [15:0] xhl;
  logic [7:0]  xh, xl;
  logic [15:0] mem_base;

  always_comb begin
    case (pfx)
      2'd1: begin xhl = ix; xh = ix[15:8]; xl = ix[7:0]; end
      2'd2: begin xhl = iy; xh = iy[15:8]; xl = iy[7:0]; end
      default: begin xhl = {h, l}; xh = h; xl = l; end
    endcase
    // (HL) becomes (IX+d)/(IY+d) under a prefix.
    mem_base = (pfx == 2'd0) ? xhl : (xhl + {{8{disp[7]}}, disp});
  end

  // Register read with the undocumented IXH/IXL aliases active under a prefix.
  function automatic logic [7:0] r8(input logic [2:0] idx);
    case (idx)
      3'd0: r8 = b;
      3'd1: r8 = c;
      3'd2: r8 = d;
      3'd3: r8 = e;
      3'd4: r8 = xh;
      3'd5: r8 = xl;
      3'd7: r8 = a;
      default: r8 = 8'h00;
    endcase
  endfunction

  // Register read without the aliases: the (HL)/(IX+d) forms keep H/L as H/L.
  function automatic logic [7:0] r8p(input logic [2:0] idx);    case (idx)
      3'd0: r8p = b;
      3'd1: r8p = c;
      3'd2: r8p = d;
      3'd3: r8p = e;
      3'd4: r8p = h;
      3'd5: r8p = l;
      3'd7: r8p = a;
      default: r8p = 8'h00;
    endcase
  endfunction

  // 16-bit ADC/SBC HL,rr used by the ED page.
  logic [15:0] ed_rp;
  logic [16:0] ed_add;
  logic [13:0] ed_add_h;
  logic [16:0] ed_sub;
  logic [13:0] ed_sub_h;

  always_comb begin
    ed_rp    = get_rp(ed_op[5:4]);
    ed_add   = {1'b0, hl_val} + {1'b0, ed_rp} + {16'h0000, f[FLAG_C]};
    ed_add_h = {1'b0, hl_val[11:0]} + {1'b0, ed_rp[11:0]} + {13'h0000, f[FLAG_C]};
    ed_sub   = {1'b0, hl_val} - {1'b0, ed_rp} - {16'h0000, f[FLAG_C]};
    ed_sub_h = {1'b0, hl_val[11:0]} - {1'b0, ed_rp[11:0]} - {13'h0000, f[FLAG_C]};
  end

  // Nibble rotate-through-memory and block-compare temporaries.
  logic [7:0] nib_mem;
  logic [7:0] nib_a;
  logic [7:0] rld_a;
  logic [7:0] cmp_res;
  logic [7:0] cmp_res_h;
  logic [4:0] cmp_nib;
  logic       cmp_h;
  logic [7:0] blk_sum;

  always_comb begin
    // RRD: mem <- {A[3:0], mem[7:4]}, A <- {A[7:4], mem[3:0]}
    nib_mem   = {a[3:0], bus_rdata_i[7:4]};
    nib_a     = {a[7:4], bus_rdata_i[3:0]};
    rld_a     = {a[7:4], bus_rdata_i[7:4]};
    cmp_nib   = {1'b0, a[3:0]} - {1'b0, bus_rdata_i[3:0]};
    cmp_h     = cmp_nib[4];
    cmp_res   = a - bus_rdata_i;
    cmp_res_h = cmp_res - {7'h00, cmp_h};
    blk_sum   = a + bus_rdata_i;
  end

  // The sequencer is the only caller of wr_hl/wr_r, so their writes belong to
  // this process even though Verilator reports them separately.
  /* verilator lint_off MULTIDRIVEN */
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
      ei_block <= 2'd0;
      nmi_prev <= 1'b0;
      nmi_pending <= 1'b0;
      int_nmi  <= 1'b0;
      ir       <= 8'h00;
      cb_op    <= 8'h00;
      imm1     <= 8'h00;
      imm2     <= 8'h00;
      mem_addr <= 16'h0000;
      mem_data <= 8'h00;
      aux_lo   <= 8'h00;
      aux_hi   <= 8'h00;
      saved16  <= 16'h0000;
      mem_op   <= MO_NONE;
      a <= 8'h00; f <= 8'h00; b <= 8'h00; c <= 8'h00;
      d <= 8'h00; e <= 8'h00; h <= 8'h00; l <= 8'h00;
      a_alt <= 8'h00; f_alt <= 8'h00; b_alt <= 8'h00; c_alt <= 8'h00;
      d_alt <= 8'h00; e_alt <= 8'h00; h_alt <= 8'h00; l_alt <= 8'h00;
    end else begin
      retire_o <= 1'b0;
      if (nmi_i && !nmi_prev) nmi_pending <= 1'b1;   // edge-triggered and latched
      nmi_prev <= nmi_i;

      case (state)
        // ------------------------------------------------------------ fetch
        S_FETCH: begin
          // EI defers recognition by exactly one instruction.
          if (ei_block != 2'd0) ei_block <= ei_block - 2'd1;
          // Interrupt acceptance happens at an instruction boundary, before the
          // next opcode fetch. NMI wins over INT.
          if (nmi_pending && bus_ready_i) begin
            nmi_pending <= 1'b0;
            int_nmi  <= 1'b1;
            saved16  <= 16'h0066;
            mem_addr <= sp - 16'd1;
            mem_data <= pc[15:8];
            aux_lo   <= pc[7:0];
            sp       <= sp - 16'd1;
            iff2     <= iff1;
            iff1     <= 1'b0;
            halted   <= 1'b0;
            mem_op   <= MO_IPUSH_HI;
            state    <= S_IPUSH_HI;
          end else if (int_i && iff1 && (ei_block == 2'd0) && bus_ready_i) begin
            iff1 <= 1'b0;
            iff2 <= 1'b0;
            halted <= 1'b0;
            int_nmi <= 1'b0;
            if (im == 2'd1) begin
              saved16  <= 16'h0038;
              mem_addr <= sp - 16'd1;
              mem_data <= pc[15:8];
              aux_lo   <= pc[7:0];
              sp       <= sp - 16'd1;
              mem_op   <= MO_IPUSH_HI;
              state    <= S_IPUSH_HI;
            end else begin
              // IM 0 and IM 2 both read a byte from the interrupting device.
              mem_op <= MO_IACK;
              state  <= S_IACK;
            end
          end else if (bus_ready_i) begin
            ir    <= bus_rdata_i;
            pc    <= pc + 16'd1;
            r_reg <= {r_reg[7], r_reg[6:0] + 7'd1};
            imm1  <= 8'h00;
            imm2  <= 8'h00;
            is_ed <= (bus_rdata_i == 8'hED);
            pfx   <= 2'd0;
            if (bus_rdata_i == 8'hCB) begin
              state <= S_PFX;
            end else if (bus_rdata_i == 8'hED) begin
              state <= S_ED;
            end else if (bus_rdata_i == 8'hDD) begin
              pfx   <= 2'd1;
              state <= S_IDX;
            end else if (bus_rdata_i == 8'hFD) begin
              pfx   <= 2'd2;
              state <= S_IDX;
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
            state <= S_EXEC;
          end
        end

        S_IMM1: begin
          if (bus_ready_i) begin
            imm1  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            // The ED page only uses this path for its two-byte (nn) forms; a
            // primary-page instruction's count comes from its own opcode.
            if (is_ed ? 1'b1 : (imm_count(ir) == 2'd2))
              state <= S_IMM2;
            else
              state <= S_EXEC;
          end
        end

        S_IMM2: begin
          if (bus_ready_i) begin
            imm2  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            state <= is_ed ? S_EXEC_ED : S_EXEC;
          end
        end

        // ------------------------------------------------------ DD/FD prefix
        S_IDX: begin
          if (bus_ready_i) begin
            ir    <= bus_rdata_i;
            pc    <= pc + 16'd1;
            r_reg <= {r_reg[7], r_reg[6:0] + 7'd1};
            imm1  <= 8'h00;
            imm2  <= 8'h00;
            if (bus_rdata_i == 8'hDD) begin
              pfx <= 2'd1;                 // last prefix wins
            end else if (bus_rdata_i == 8'hFD) begin
              pfx <= 2'd2;
            end else if (bus_rdata_i == 8'hED) begin
              pfx   <= 2'd0;               // DD ED: the DD is ignored
              is_ed <= 1'b1;
              state <= S_ED;
            end else if (bus_rdata_i == 8'hCB) begin
              state <= S_DCB_D;
            end else if (!supported(bus_rdata_i)) begin
              fault_o <= 1'b1;
              state   <= S_FAULT;
            end else if (needs_disp(bus_rdata_i)) begin
              state <= S_IDX_D;
            end else if (imm_count(bus_rdata_i) == 2'd0) begin
              state <= S_EXEC;
            end else begin
              state <= S_IMM1;
            end
          end
        end

        S_IDX_D: begin
          if (bus_ready_i) begin
            disp  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            // LD (IX+d),n still needs its immediate byte after the displacement.
            state <= (ir == 8'h36) ? S_IMM1 : S_EXEC;
          end
        end

        S_DCB_D: begin
          if (bus_ready_i) begin
            disp  <= bus_rdata_i;
            pc    <= pc + 16'd1;
            state <= S_DCB_OP;
          end
        end

        S_DCB_OP: begin
          if (bus_ready_i) begin
            cb_op <= bus_rdata_i;
            pc    <= pc + 16'd1;
            // The opcode byte of DD CB d op is not an M1 fetch: R is unchanged.
            state <= S_EXEC;
          end
        end

        // ------------------------------------------------------- ED prefix
        S_ED: begin
          if (bus_ready_i) begin
            ed_op <= bus_rdata_i;
            pc    <= pc + 16'd1;
            r_reg <= {r_reg[7], r_reg[6:0] + 7'd1};
            // Only the 16-bit (nn) loads/stores take immediate bytes.
            if ((bus_rdata_i[7:6] == 2'b01) && (bus_rdata_i[2:0] == 3'd3))
              state <= S_IMM1;
            else
              state <= S_EXEC_ED;
          end
        end

        // --------------------------------------------------------- execute
        S_EXEC: begin
          if (ir == 8'hCB) begin
            if (cb_op[2:0] != 3'd6 && (pfx == 2'd0)) begin
              // Register forms (verified earlier).
              case (cb_op[7:6])
                2'b00: begin
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
                2'b01: f <= alu_f;
                2'b10: begin
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
                default: begin
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
            end else begin
              // (HL) forms: read first; BIT has no write-back.
              mem_addr <= mem_base;
              if (pfx != 2'd0)
                wz <= mem_base;   // DD-CB: WZ is the effective address
              if (cb_op[7:6] == 2'b00) begin
                mem_op <= MO_CB_ROT;
              end else if (cb_op[7:6] == 2'b01) begin
                mem_op <= MO_CB_BIT;
              end else begin
                mem_op <= MO_CB_MOD;
              end
              state <= S_MRD;
            end
          end else if (ir == 8'h00) begin
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h76) begin
            halted <= 1'b1;
            retire_o <= 1'b1;
            state <= S_HALTED;
          end else if (ir == 8'h08) begin
            a <= a_alt; f <= f_alt;
            a_alt <= a; f_alt <= f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hEB) begin
            {d, e} <= {h, l};
            {h, l} <= {d, e};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hD9) begin
            {b, c, d, e, h, l} <= {b_alt, c_alt, d_alt, e_alt, h_alt, l_alt};
            {b_alt, c_alt, d_alt, e_alt, h_alt, l_alt} <= {b, c, d, e, h, l};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hF3) begin
            iff1 <= 1'b0; iff2 <= 1'b0;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hFB) begin
            iff1 <= 1'b1; iff2 <= 1'b1; ei_block <= 2'd1;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hE9) begin
            pc <= xhl;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hF9) begin
            sp <= xhl;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h10) begin
            b <= b - 8'h01;
            if ((b - 8'h01) != 8'h00) pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h18) begin
            pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[7:5] == 3'b001 && ir[2:0] == 3'd0) begin
            if (cond_true({1'b0, ir[4:3]}, f)) pc <= pc + {{8{imm1[7]}}, imm1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h27 || ir == 8'h2F) begin
            a <= alu_y;
            f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h37) begin
            f <= {f[FLAG_S], f[FLAG_Z], a[5], 1'b0, a[3], f[FLAG_PV], 1'b0, 1'b1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h3F) begin
            f <= {f[FLAG_S], f[FLAG_Z], a[5], f[FLAG_C], a[3], f[FLAG_PV],
                  1'b0, ~f[FLAG_C]};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'h07 || ir == 8'h0F || ir == 8'h17 || ir == 8'h1F) begin
            a <= alu_y;
            f <= {f[FLAG_S], f[FLAG_Z], alu_f[FLAG_F5], 1'b0, alu_f[FLAG_F3],
                  f[FLAG_PV], 1'b0, alu_f[FLAG_C]};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd3 && ir[7:6] == 2'b00 && ir[3] == 1'b0) begin
            case (ir[5:4])
              2'd0: {b, c} <= {b, c} + 16'd1;
              2'd1: {d, e} <= {d, e} + 16'd1;
              2'd2: wr_hl(xhl + 16'd1);
              default: sp <= sp + 16'd1;
            endcase
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd3 && ir[7:6] == 2'b00 && ir[3] == 1'b1) begin
            case (ir[5:4])
              2'd0: {b, c} <= {b, c} - 16'd1;
              2'd1: {d, e} <= {d, e} - 16'd1;
              2'd2: wr_hl(xhl - 16'd1);
              default: sp <= sp - 16'd1;
            endcase
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd1 && ir[3] == 1'b1 && ir[7:6] == 2'b00) begin
            wr_hl(full_sum[15:0]);
            f <= {f[FLAG_S], f[FLAG_Z], full_sum[13], half_sum[12], full_sum[11],
                  f[FLAG_PV], 1'b0, full_sum[16]};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd1 && ir[3] == 1'b0 && ir[7:6] == 2'b00) begin
            case (ir[5:4])
              2'd0: {b, c} <= {imm2, imm1};
              2'd1: {d, e} <= {imm2, imm1};
              2'd2: wr_hl({imm2, imm1});
              default: sp <= {imm2, imm1};
            endcase
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir == 8'hC3) begin
            pc <= {imm2, imm1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd2) begin
            if (cond_true(ir[5:3], f)) pc <= {imm2, imm1};
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd6) begin
            if (ir[5:3] == 3'd7) begin
              f <= alu_f;
            end else begin
              a <= alu_y;
              f <= alu_f;
            end
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir >= 8'h80 && ir <= 8'hBF) begin
            if (ir[2:0] == 3'd6) begin
              // ALU A,(HL)
              mem_addr <= mem_base;
              mem_op   <= MO_ALU;
              state    <= S_MRD;
            end else if (ir[5:3] == 3'd7) begin
              f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
            end else begin
              a <= alu_y;
              f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
            end
          end else if (ir >= 8'h40 && ir <= 8'h7F) begin
            if (ir[2:0] == 3'd6) begin
              // LD r,(HL)
              mem_addr <= mem_base;
              aux_lo   <= {5'b00000, ir[5:3]};
              mem_op   <= MO_LD_R;
              state    <= S_MRD;
            end else if (ir[5:3] == 3'd6) begin
              // LD (HL),r
              mem_addr <= mem_base;
              mem_data <= r8p(ir[2:0]);
              mem_op   <= MO_WR_RET;
              state    <= S_MWR;
            end else begin
              wr_r(ir[5:3], r8(ir[2:0]), 1'b1);
            retire_o <= 1'b1;
            state    <= S_FETCH;
            end
          end else if (ir == 8'h36) begin
            mem_addr <= mem_base;
            mem_data <= imm1;
            mem_op   <= MO_WR_RET;
            state    <= S_MWR;
          end else if (ir == 8'h34 || ir == 8'h35) begin
            mem_addr <= mem_base;
            mem_op   <= (ir == 8'h34) ? MO_INC_MEM : MO_DEC_MEM;
            state    <= S_MRD;
          end else if (ir == 8'h0A || ir == 8'h1A) begin
            mem_addr <= (ir == 8'h0A) ? {b, c} : {d, e};
            mem_op   <= MO_LD_A_IND;
            state    <= S_MRD;
          end else if (ir == 8'h02 || ir == 8'h12) begin
            mem_addr <= (ir == 8'h02) ? {b, c} : {d, e};
            mem_data <= a;
            mem_op   <= MO_LD_IND_A;
            state    <= S_MWR;
          end else if (ir == 8'h3A) begin
            mem_addr <= {imm2, imm1};
            mem_op   <= MO_LD_A_IND;
            state    <= S_MRD;
          end else if (ir == 8'h32) begin
            mem_addr <= {imm2, imm1};
            mem_data <= a;
            mem_op   <= MO_LD_IND_A;
            state    <= S_MWR;
          end else if (ir == 8'h2A) begin
            mem_addr <= {imm2, imm1};
            mem_op   <= MO_LD_HL_LO;
            state    <= S_MRD;
          end else if (ir == 8'h22) begin
            mem_addr <= {imm2, imm1};
            mem_data <= xl;
            aux_hi   <= xh;
            mem_op   <= MO_LD_NN_LO;
            state    <= S_MWR;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd5 && ir[3] == 1'b0) begin
            // PUSH rr / PUSH AF (0xCD is CALL nn and is handled below)
            mem_addr <= sp - 16'd1;
            if (ir[5:4] == 2'd3) begin
              mem_data <= a;
              aux_lo   <= f;
            end else begin
              mem_data <= get_rp_hi(ir[5:4]);
              aux_lo   <= get_rp_lo(ir[5:4]);
            end
            sp       <= sp - 16'd1;
            mem_op   <= MO_PUSH_HI;
            state    <= S_MWR;
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd1 && ir[3] == 1'b0) begin
            // POP rr / POP AF
            mem_addr <= sp;
            mem_op   <= MO_POP_LO;
            state    <= S_MRD;
          end else if (ir == 8'hCD || (ir[7:6] == 2'b11 && ir[2:0] == 3'd4)) begin
            // CALL nn / CALL cc,nn
            if (ir == 8'hCD || cond_true(ir[5:3], f)) begin
              saved16  <= {imm2, imm1};
              mem_addr <= sp - 16'd1;
              mem_data <= pc[15:8];
              aux_lo   <= pc[7:0];
              sp       <= sp - 16'd1;
              mem_op   <= MO_CALL_HI;
              state    <= S_MWR;
            end else begin
            retire_o <= 1'b1;
            state    <= S_FETCH;
            end
          end else if (ir == 8'hC9 || (ir[7:6] == 2'b11 && ir[2:0] == 3'd0)) begin
            // RET / RET cc
            if (ir == 8'hC9 || cond_true(ir[5:3], f)) begin
              mem_addr <= sp;
              mem_op   <= MO_RET_LO;
              state    <= S_MRD;
            end else begin
            retire_o <= 1'b1;
            state    <= S_FETCH;
            end
          end else if (ir[7:6] == 2'b11 && ir[2:0] == 3'd7) begin
            // RST
            saved16  <= {8'h00, ir & 8'h38};
            mem_addr <= sp - 16'd1;
            mem_data <= pc[15:8];
            aux_lo   <= pc[7:0];
            sp       <= sp - 16'd1;
            mem_op   <= MO_RST_HI;
            state    <= S_MWR;
          end else if (ir == 8'hD3) begin
            // OUT (n),A : port number on A0-A7, A on A8-A15
            mem_addr <= {a, imm1};
            mem_data <= a;
            mem_op   <= MO_WR_RET;
            state    <= S_IOWR;
          end else if (ir == 8'hDB) begin
            // IN A,(n)
            mem_addr <= {a, imm1};
            mem_op   <= MO_IN_A;
            state    <= S_IORD;
          end else if (ir == 8'hE3) begin
            // EX (SP),HL
            saved16  <= xhl;
            mem_addr <= sp;
            mem_op   <= MO_EX_LO;
            state    <= S_MRD;
          end else if (ir[2:0] == 3'd4 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // INC r
            wr_r(ir[5:3], alu_y, 1'b1);
            f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd5 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // DEC r
            wr_r(ir[5:3], alu_y, 1'b1);
            f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else if (ir[2:0] == 3'd6 && ir[7:6] == 2'b00 && ir[5:3] != 3'd6) begin
            // LD r,n
            wr_r(ir[5:3], imm1, 1'b1);
            retire_o <= 1'b1;
            state    <= S_FETCH;
          end else begin
            fault_o <= 1'b1;
            state   <= S_FAULT;
          end
        end

        // ------------------------------------------------------- read result
        S_MRD: begin
          if (bus_ready_i) begin
            case (mem_op)
              MO_LD_R: begin
                // LD r,(HL)/(IX+d): the register side keeps H/L as H/L.
                wr_r(aux_lo[2:0], bus_rdata_i, 1'b0);
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              MO_ALU: begin
                a <= alu_y;
                f <= alu_f;
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_INC_MEM, MO_DEC_MEM, MO_CB_ROT: begin
                f        <= alu_f;
                mem_data <= alu_y;
                // DD-CB/FD-CB also copy the result into the register named by the
                // low three bits (undocumented autocopy).
                if ((ir == 8'hCB) && (pfx != 2'd0) && (cb_op[2:0] != 3'd6))
                  wr_r(cb_op[2:0], alu_y, 1'b0);
                mem_op   <= MO_WR_RET;
                state    <= S_MWR;
              end
              MO_CB_BIT: begin
                f <= alu_f;              // C preserved, F3/F5 from the WZ byte
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              MO_CB_MOD: begin
                mem_data <= (cb_op[7:6] == 2'b10)
                                ? (bus_rdata_i & ~(8'h01 << cb_op[5:3]))
                                : (bus_rdata_i | (8'h01 << cb_op[5:3]));
                if ((pfx != 2'd0) && (cb_op[2:0] != 3'd6))
                  wr_r(cb_op[2:0], (cb_op[7:6] == 2'b10)
                                        ? (bus_rdata_i & ~(8'h01 << cb_op[5:3]))
                                        : (bus_rdata_i | (8'h01 << cb_op[5:3])), 1'b0);
                mem_op   <= MO_WR_RET;
                state    <= S_MWR;
              end
              MO_LD_A_IND: begin
                a <= bus_rdata_i;
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_LD_HL_LO: begin
                aux_lo   <= bus_rdata_i;
                mem_addr <= mem_addr + 16'd1;
                mem_op   <= MO_LD_HL_HI;
              end
              MO_LD_HL_HI: begin
                wr_hl({bus_rdata_i, aux_lo});
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_POP_LO: begin
                aux_lo   <= bus_rdata_i;
                mem_addr <= mem_addr + 16'd1;
                sp       <= sp + 16'd1;
                mem_op   <= MO_POP_HI;
              end
              MO_POP_HI: begin
                sp <= sp + 16'd1;
                case (ir[5:4])
                  2'd0: {b, c} <= {bus_rdata_i, aux_lo};
                  2'd1: {d, e} <= {bus_rdata_i, aux_lo};
                  2'd2: wr_hl({bus_rdata_i, aux_lo});
                  default: begin
                    a <= bus_rdata_i;
                    f <= aux_lo;
                  end
                endcase
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_RET_LO: begin
                aux_lo   <= bus_rdata_i;
                mem_addr <= mem_addr + 16'd1;
                sp       <= sp + 16'd1;
                mem_op   <= MO_RET_HI;
              end
              MO_RET_HI: begin
                sp <= sp + 16'd1;
                pc <= {bus_rdata_i, aux_lo};
                if (ir == 8'hED) iff1 <= iff2;   // RETN/RETI restore IFF1
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_EX_LO: begin
                aux_lo   <= bus_rdata_i;
                mem_addr <= mem_addr + 16'd1;
                mem_op   <= MO_EX_HI;
              end
              MO_EX_HI: begin
                aux_hi   <= bus_rdata_i;
                mem_addr <= sp;
                mem_data <= saved16[7:0];
                mem_op   <= MO_EX_WLO;
                state    <= S_MWR;
              end
              MO_ED_LD_LO: begin
                aux_lo   <= bus_rdata_i;
                mem_addr <= mem_addr + 16'd1;
                mem_op   <= MO_ED_LD_HI;
              end
              MO_ED_LD_HI: begin
                case (ed_op[5:4])
                  2'd0: {b, c} <= {bus_rdata_i, aux_lo};
                  2'd1: {d, e} <= {bus_rdata_i, aux_lo};
                  2'd2: wr_hl({bus_rdata_i, aux_lo});
                  default: sp <= {bus_rdata_i, aux_lo};
                endcase
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              MO_RRD: begin
                mem_data <= nib_mem;
                a        <= nib_a;
                f        <= {nib_a[7], (nib_a == 8'h00), nib_a[5], 1'b0, nib_a[3],
                             ~(^nib_a), 1'b0, f[FLAG_C]};
                mem_op   <= MO_WR_RET;
                state    <= S_MWR;
              end
              MO_RLD: begin
                // RLD: mem <- {mem[3:0], A[3:0]}, A <- {A[7:4], mem[7:4]}
                mem_data <= {bus_rdata_i[3:0], a[3:0]};
                a        <= rld_a;
                f        <= {rld_a[7], (rld_a == 8'h00), rld_a[5], 1'b0, rld_a[3],
                             ~(^rld_a), 1'b0, f[FLAG_C]};
                mem_op   <= MO_WR_RET;
                state    <= S_MWR;
              end
              MO_BLK_LD_R: begin
                aux_lo   <= bus_rdata_i;
                mem_data <= bus_rdata_i;
                mem_addr <= {d, e};
                mem_op   <= MO_BLK_LD_W;
                state    <= S_MWR;
              end
              MO_BLK_OUT_R: begin
                mem_data <= bus_rdata_i;
                mem_addr <= {b, c};
                mem_op   <= MO_BLK_OUT_W;
                state    <= S_IOWR;
              end
              MO_BLK_CP_R: begin
                // CPI/CPD: A - (HL), then pointer and flag updates, repeat.
                if (ed_op[3]) begin
                  {h, l} <= {h, l} - 16'd1;
                end else begin
                  {h, l} <= {h, l} + 16'd1;
                end
                {b, c} <= {b, c} - 16'd1;
                f <= {cmp_res[7], (cmp_res == 8'h00), cmp_res_h[1], cmp_h,
                      cmp_res_h[3], (({b, c} - 16'd1) != 16'h0000), 1'b1,
                      f[FLAG_C]};
                if (ed_op[4] && (({b, c} - 16'd1) != 16'h0000) &&
                    (cmp_res != 8'h00)) begin
                  pc <= pc - 16'd2;    // repeat: re-execute this instruction
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end else begin
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end
              end
              default: begin
                fault_o <= 1'b1;
                state   <= S_FAULT;
              end
            endcase
          end
        end

        // ------------------------------------------------------ write result
        S_MWR: begin
          if (bus_ready_i) begin
            case (mem_op)
              MO_WR_RET, MO_LD_IND_A: begin
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              MO_LD_NN_LO: begin
                mem_addr <= mem_addr + 16'd1;
                mem_data <= aux_hi;          // high byte of the stored pair
                mem_op   <= MO_WR_RET;
              end
              MO_PUSH_HI: begin
                mem_addr <= sp - 16'd1;      // sp already decremented
                mem_data <= aux_lo;
                sp       <= sp - 16'd1;
                mem_op   <= MO_PUSH_LO;
              end
              MO_PUSH_LO: begin
                retire_o <= 1'b1;  // sp was decremented twice already
                state    <= S_FETCH;
              end
              MO_CALL_HI, MO_RST_HI: begin
                mem_addr <= sp - 16'd1;
                mem_data <= aux_lo;
                sp       <= sp - 16'd1;
                mem_op   <= (mem_op == MO_CALL_HI) ? MO_CALL_LO : MO_RST_LO;
              end
              MO_CALL_LO, MO_RST_LO: begin
                pc <= saved16;               // sp already at its final value
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              MO_BLK_LD_W: begin
                // LDI/LDD destination write done: pointers, flags, repeat.
                if (ed_op[3]) begin
                  {h, l} <= {h, l} - 16'd1;
                  {d, e} <= {d, e} - 16'd1;
                end else begin
                  {h, l} <= {h, l} + 16'd1;
                  {d, e} <= {d, e} + 16'd1;
                end
                {b, c} <= {b, c} - 16'd1;
                f <= {f[FLAG_S], f[FLAG_Z], blk_sum[1], 1'b0, blk_sum[3],
                      (({b, c} - 16'd1) != 16'h0000), 1'b0, f[FLAG_C]};
                if (ed_op[4] && (({b, c} - 16'd1) != 16'h0000)) begin
                  pc <= pc - 16'd2;          // LDIR/LDDR: next iteration
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end else begin
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end
              end
              MO_BLK_INI_W: begin
                // INI/IND store done: HL +/- 1, B - 1, Z from B, N = 1.
                if (ed_op[3]) begin
                  {h, l} <= {h, l} - 16'd1;
                end else begin
                  {h, l} <= {h, l} + 16'd1;
                end
                b <= b - 8'h01;
                f <= {f[FLAG_S], ((b - 8'h01) == 8'h00), f[FLAG_F5], f[FLAG_H],
                      f[FLAG_F3], f[FLAG_PV], 1'b1, f[FLAG_C]};
                if (ed_op[4] && ((b - 8'h01) != 8'h00)) begin
                  pc <= pc - 16'd2;
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end else begin
                  retire_o <= 1'b1;
                  state    <= S_FETCH;
                end
              end
              MO_EX_WLO: begin
                mem_addr <= sp + 16'd1;
                mem_data <= saved16[15:8];
                mem_op   <= MO_EX_WHI;
              end
              MO_EX_WHI: begin
                wr_hl({aux_hi, aux_lo});
            retire_o <= 1'b1;
            state    <= S_FETCH;
              end
              default: begin
                fault_o <= 1'b1;
                state   <= S_FAULT;
              end
            endcase
          end
        end

        // ------------------------------------------------------- ED page
        S_IORD: begin
          if (bus_ready_i) begin
            case (mem_op)
              MO_IN_R: begin
                if (ed_op == 8'h70) begin
                  // IN F,(C): S/Z/PV from the byte, H=N=0, F3/F5 and C kept.
                  f <= {bus_rdata_i[7], (bus_rdata_i == 8'h00), f[FLAG_F5], 1'b0,
                        f[FLAG_F3], ~(^bus_rdata_i), 1'b0, f[FLAG_C]};
                end else begin
                  case (ed_op[5:3])
                    3'd0: b <= bus_rdata_i;
                    3'd1: c <= bus_rdata_i;
                    3'd2: d <= bus_rdata_i;
                    3'd3: e <= bus_rdata_i;
                    3'd4: h <= bus_rdata_i;
                    3'd5: l <= bus_rdata_i;
                    default: a <= bus_rdata_i;
                  endcase
                  f <= {(bus_rdata_i[7]), (bus_rdata_i == 8'h00), f[FLAG_F5], 1'b0,
                        f[FLAG_F3], ~(^bus_rdata_i), 1'b0, f[FLAG_C]};
                end
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              MO_BLK_INI: begin
                mem_data <= bus_rdata_i;
                mem_addr <= mem_base;
                mem_op   <= MO_BLK_INI_W;
                state    <= S_MWR;
              end
              MO_IN_A: begin
                // IN A,(n): the pinned oracle (and hardware) leaves F unchanged.
                a <= bus_rdata_i;
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
              default: begin
                fault_o <= 1'b1;
                state   <= S_FAULT;
              end
            endcase
          end
        end

        S_IOWR: begin
          if (bus_ready_i) begin
            if (mem_op == MO_BLK_OUT_W) begin
              // OUTI/OUTD done: HL +/- 1, B - 1, Z from B, N = 1.
              if (ed_op[3]) begin
                {h, l} <= {h, l} - 16'd1;
              end else begin
                {h, l} <= {h, l} + 16'd1;
              end
              b <= b - 8'h01;
              f <= {f[FLAG_S], ((b - 8'h01) == 8'h00), f[FLAG_F5], f[FLAG_H],
                    f[FLAG_F3], f[FLAG_PV], 1'b1, f[FLAG_C]};
              if (ed_op[4] && ((b - 8'h01) != 8'h00)) begin
                pc <= pc - 16'd2;
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end else begin
                retire_o <= 1'b1;
                state    <= S_FETCH;
              end
            end else begin
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
          end
        end

        S_EXEC_ED: begin
          case (ed_op)
            // IN r,(C) / IN F,(C)
            8'h40, 8'h48, 8'h50, 8'h58, 8'h60, 8'h68, 8'h70, 8'h78: begin
              mem_addr <= {b, c};
              mem_op   <= MO_IN_R;
              state    <= S_IORD;
            end
            // OUT (C),r / OUT (C),0
            8'h41, 8'h49, 8'h51, 8'h59, 8'h61, 8'h69, 8'h71, 8'h79: begin
              mem_addr <= {b, c};
              mem_data <= (ed_op == 8'h71) ? 8'h00 : get_r(ed_op[5:3]);
              mem_op   <= MO_WR_RET;
              state    <= S_IOWR;
            end
            // SBC HL,rr (C from flags)
            8'h42, 8'h52, 8'h62, 8'h72: begin
              wr_hl(ed_sub[15:0]);
              f <= {ed_sub[15], (ed_sub[15:0] == 16'h0000), ed_sub[13],
                    ed_sub_h[12], ed_sub[11],
                    ((hl_val[15] ^ ed_rp[15]) & (ed_sub[15] ^ hl_val[15])), 1'b1,
                    ed_sub[16]};
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // ADC HL,rr
            8'h4A, 8'h5A, 8'h6A, 8'h7A: begin
              wr_hl(ed_add[15:0]);
              f <= {ed_add[15], (ed_add[15:0] == 16'h0000), ed_add[13],
                    ed_add_h[12], ed_add[11],
                    (~(hl_val[15] ^ ed_rp[15]) & (ed_add[15] ^ hl_val[15])), 1'b0,
                    ed_add[16]};
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // LD (nn),rr
            8'h43, 8'h53, 8'h63, 8'h73: begin
              aux_hi   <= (ed_op[5:4] == 2'd3) ? sp[15:8] : get_rp_hi(ed_op[5:4]);
              mem_addr <= {imm2, imm1};
              mem_data <= (ed_op[5:4] == 2'd3) ? sp[7:0] : get_rp_lo(ed_op[5:4]);
              mem_op   <= MO_LD_NN_LO;
              state    <= S_MWR;
            end
            // LD rr,(nn)
            8'h4B, 8'h5B, 8'h6B, 8'h7B: begin
              mem_addr <= {imm2, imm1};
              mem_op   <= MO_ED_LD_LO;
              state    <= S_MRD;
            end
            // NEG (all duplicate encodings) - via the ALU
            8'h44, 8'h4C, 8'h54, 8'h5C, 8'h64, 8'h6C, 8'h74, 8'h7C: begin
              a <= alu_y;
              f <= alu_f;
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // RETN / RETI
            8'h45, 8'h4D, 8'h55, 8'h5D, 8'h65, 8'h6D, 8'h75, 8'h7D: begin
              mem_addr <= sp;
              mem_op   <= MO_RET_LO;
              state    <= S_MRD;
            end
            // IM 0 / 1 / 2 (duplicate encodings)
            8'h46, 8'h4E, 8'h56, 8'h5E, 8'h66, 8'h6E, 8'h76, 8'h7E: begin
              case (ed_op[5:3])
                3'd0, 3'd1, 3'd4, 3'd5: im <= 2'd0;
                3'd2, 3'd6:            im <= 2'd1;
                default:               im <= 2'd2;
              endcase
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // LD I,A / LD R,A
            8'h47: begin
              i_reg <= a;
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            8'h4F: begin
              r_reg <= a;
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // LD A,I / LD A,R : S,Z,F5,F3 from the value, P/V = IFF2, N = H = 0
            8'h57: begin
              a <= i_reg;
              f <= {i_reg[7], (i_reg == 8'h00), f[FLAG_F5], 1'b0, f[FLAG_F3], iff2,
                    1'b0, f[FLAG_C]};
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            8'h5F: begin
              a <= r_reg;
              f <= {r_reg[7], (r_reg == 8'h00), f[FLAG_F5], 1'b0, f[FLAG_F3], iff2,
                    1'b0, f[FLAG_C]};
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
            // RRD / RLD
            8'h67, 8'h6F: begin
              mem_addr <= mem_base;
              mem_op   <= (ed_op == 8'h67) ? MO_RRD : MO_RLD;
              state    <= S_MRD;
            end
            // Block I/O: INI/IND/INIR/INDR
            8'hA2, 8'hAA, 8'hB2, 8'hBA: begin
              mem_addr <= {b, c};
              mem_op   <= MO_BLK_INI;
              state    <= S_IORD;
            end
            // Block I/O: OUTI/OUTD/OTIR/OTDR
            8'hA3, 8'hAB, 8'hB3, 8'hBB: begin
              mem_addr <= mem_base;
              mem_op   <= MO_BLK_OUT_R;
              state    <= S_MRD;
            end
            // Block transfer / search
            8'hA0, 8'hA8, 8'hB0, 8'hB8: begin   // LDI / LDD / LDIR / LDDR
              mem_addr <= mem_base;
              mem_op   <= MO_BLK_LD_R;
              state    <= S_MRD;
            end
            8'hA1, 8'hA9, 8'hB1, 8'hB9: begin   // CPI / CPD / CPIR / CPDR
              mem_addr <= mem_base;
              mem_op   <= MO_BLK_CP_R;
              state    <= S_MRD;
            end
            default: begin
              // Undefined ED encodings execute as a two-byte NOP.
              retire_o <= 1'b1;
              state    <= S_FETCH;
            end
          endcase
        end

        // ------------------------------------------------------ interrupt entry
        S_IACK: begin
          if (bus_ready_i) begin
            iack_byte <= bus_rdata_i;
            if (im == 2'd0) begin
              // IM 0 executes the supplied byte; RST forms are modelled, other
              // opcodes are treated as a no-op (documented limitation).
              saved16  <= ((bus_rdata_i & 8'hC7) == 8'hC7)
                              ? {8'h00, (bus_rdata_i & 8'h38)} : pc;
              mem_addr <= sp - 16'd1;
              mem_data <= pc[15:8];
              aux_lo   <= pc[7:0];
              sp       <= sp - 16'd1;
              mem_op   <= MO_IPUSH_HI;
              state    <= S_IPUSH_HI;
            end else begin
              int_vec  <= {i_reg, bus_rdata_i};
              mem_addr <= {i_reg, bus_rdata_i};
              mem_op   <= MO_IVEC_LO;
              state    <= S_IVEC_LO;
            end
          end
        end

        S_IVEC_LO: begin
          if (bus_ready_i) begin
            aux_lo   <= bus_rdata_i;
            mem_addr <= int_vec + 16'd1;
            mem_op   <= MO_IVEC_HI;
            state    <= S_IVEC_HI;
          end
        end

        S_IVEC_HI: begin
          if (bus_ready_i) begin
            saved16  <= {bus_rdata_i, aux_lo};
            mem_addr <= sp - 16'd1;
            mem_data <= pc[15:8];
            aux_lo   <= pc[7:0];
            sp       <= sp - 16'd1;
            mem_op   <= MO_IPUSH_HI;
            state    <= S_IPUSH_HI;
          end
        end

        S_IPUSH_HI: begin
          if (bus_ready_i) begin
            mem_addr <= sp - 16'd1;
            mem_data <= aux_lo;
            sp       <= sp - 16'd1;
            mem_op   <= MO_IPUSH_LO;
            state    <= S_IPUSH_LO;
          end
        end

        S_IPUSH_LO: begin
          if (bus_ready_i) begin
            pc    <= saved16;
            state <= S_FETCH;
          end
        end

        S_HALTED: begin
          retire_o <= 1'b0;
          // HALT is left by any accepted interrupt.
          if (nmi_i || (int_i && iff1)) begin
            halted <= 1'b0;
            state  <= S_FETCH;
          end
        end
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

`ifdef FORMAL
  // ------------------------------------------------------------- formal checks
  // Proven with `sby -f formal/zilog_z80.sby <task>`; see plans/formal_plan.md.
  logic       f_past_valid = 1'b0;
  logic [3:0] f_reset_cnt  = 4'd0;

  always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!rst_n && f_reset_cnt != 4'hF) f_reset_cnt <= f_reset_cnt + 4'd1;
    // The environment must present a real reset: without it, registers such as
    // `halted` are unconstrained at time zero and no property is meaningful.
    if (f_reset_cnt != 4'hF) assume (!rst_n);
  end

  always_ff @(posedge clk) begin
    if (rst_n && f_past_valid) begin
      // Structural invariants that make the history-dependent properties
      // inductive: HALT and fault are only entered through their own state.
      if (halted) assert (state == S_HALTED);
      if (fault_o) assert (state == S_FAULT);

      // A retiring instruction is never a faulted one.
      if (retire_o) assert (!fault_o);

      // The fault flag is sticky until reset (so ignore a reset edge).
      if ($past(fault_o) && $past(rst_n)) assert (fault_o);

      // HALT freezes the program counter until an interrupt is requested.
      if ($past(halted) && $past(rst_n) && !$past(int_i) && !$past(nmi_i))
        assert (pc == $past(pc));

      // A stalled transfer keeps address, direction, data and space stable.
      if ($past(bus_req_o) && !$past(bus_ready_i) && $past(rst_n))
        assert (bus_addr_o == $past(bus_addr_o) &&
                bus_write_o == $past(bus_write_o) &&
                bus_wdata_o == $past(bus_wdata_o) &&
                bus_io_o == $past(bus_io_o));
    end

    if (rst_n) begin
      cover (retire_o);                        // instructions complete
      cover (bus_req_o && bus_write_o);        // a store happens
      cover (bus_req_o && !bus_write_o);       // a fetch or read happens
      cover (halted);                          // HALT is reached
      cover (sp != 16'h0000);                  // stack traffic changes SP
    end
  end
`endif

  /* verilator lint_on MULTIDRIVEN */

endmodule
