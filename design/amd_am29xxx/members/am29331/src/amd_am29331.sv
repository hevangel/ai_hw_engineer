// AMD Am29331 16-bit microprogram sequencer, edge-accurate digital model.
//
// Sources:
//   AMD 1988 Am29C300/29300 Data Book, "Am29331 16-Bit Microprogram
//   Sequencer", Issue 05729E/0 (December 1987), PDF 128-163: pin contract,
//   architecture, Tables 1/2, AC parameters. Primary production contract.
//   AMD 1985 Am29300 Family Handbook, PDF 100-112: advanced-information
//   datasheet used as cross-check (RST polarity follows the 1988 pin list:
//   RST is active LOW).
//
// Bidirectional pins are modeled as separate input/output pairs; each *_oe_o
// is the three-state driver enable for the matching output. The ERROR
// contention comparison assumes the *_i pair observes the driven line
// (looped back in normal use, master-driven in slave mode).
//
// All state updates on cp_i rising edges. rst_n_i is synchronous and active
// low. hold_i freezes every clocked update and three-states all outputs.
// Electrical propagation (Tables A/B/C nanosecond limits) is not modeled.

module amd_am29331 (
  input  logic        cp_i,
  input  logic        rst_n_i,       // reset, active low, synchronous
  input  logic [5:0]  instr_i,       // I5-I0
  input  logic [11:0] test_i,        // T11-T0
  input  logic [3:0]  select_i,      // S3-S0
  input  logic [15:0] a_i,           // alternate data bus (input only)
  input  logic [15:0] d_i,           // D-bus input value
  output logic [15:0] d_o,           // D-bus driven value (SP, or TOS on POP D)
  output logic        d_oe_o,
  input  logic [15:0] y_i,           // Y-bus input value (interrupt address)
  output logic [15:0] y_o,           // Y-bus driven value (next address)
  output logic        y_oe_o,
  input  logic [3:0]  m0_i, m1_i, m2_i, m3_i,
  input  logic        fc_i,          // force continue, active high
  input  logic        cin_n_i,       // incrementer carry-in, active low
  input  logic        oed_i,         // D-bus output enable, active high
  input  logic        hold_i,        // hold mode, active high
  input  logic        intr_i,        // interrupt request, active high
  input  logic        inten_i,       // interrupt enable, active high
  input  logic        inta_i,
  output logic        inta_o,        // interrupt acknowledge, active low
  output logic        inta_oe_o,
  input  logic        a_full_i,
  output logic        a_full_o,      // SP >= 28 (also underflow SP=63)
  output logic        a_full_oe_o,
  input  logic        equal_i,
  output logic        equal_o,       // comparator enabled and matched
  output logic        equal_oe_o,
  output logic        error_o,       // master/slave fault, active high
  input  logic        slave_i
);

  localparam int AW = 16;             // address/data width
  localparam int SW = 33;             // stack words
  localparam logic [5:0] OP_CONT = 6'h30;

  // State: address register, 33-word stack, modulo-64 stack pointer, loop
  // counter, comparison register and enable, interrupt return address, and
  // the one-cycle-latched interrupt acceptance that drives the automatic
  // return-address push (1988 datasheet pages 3-9/3-11, Figures 4-7).
  logic [AW-1:0]  ar_q, irar_q, c_q, r_q;
  logic [AW-1:0]  stack_q [0:SW-1];   // unpacked memory: variable indices
  logic [5:0]     sp_q;               // lower to read/write ports, not shifts
  logic           cmp_en_q, int_push_q;

  // ------------------------------------------------------------------
  // Effective instruction: reset overrides both instruction and FC
  // (1988 page 3-9); FC overrides I5-I0 with CONTINUE (page 3-9).
  wire rst_active = !rst_n_i;
  wire [5:0] eff  = rst_active ? OP_CONT : (fc_i ? OP_CONT : instr_i);
  wire [1:0] cls  = eff[5:4];
  wire [3:0] row  = eff[3:0];

  // Test multiplexer: S3-S0 selects sixteen tests; 12-15 combine the ALU
  // status inputs T8-T11 (1988 page 3-9 table; 1985 page 104).
  logic cond_test;
  always_comb begin
    case (select_i)
      4'd0:  cond_test = test_i[0];
      4'd1:  cond_test = test_i[1];
      4'd2:  cond_test = test_i[2];
      4'd3:  cond_test = test_i[3];
      4'd4:  cond_test = test_i[4];
      4'd5:  cond_test = test_i[5];
      4'd6:  cond_test = test_i[6];
      4'd7:  cond_test = test_i[7];
      4'd8:  cond_test = test_i[8];              // C
      4'd9:  cond_test = test_i[9];              // N
      4'd10: cond_test = test_i[10];             // V
      4'd11: cond_test = test_i[11];             // Z
      4'd12: cond_test = test_i[8]  | test_i[11];          // C+Z
      4'd13: cond_test = ~test_i[8] | test_i[11];          // /C+Z
      4'd14: cond_test = test_i[9]  ^ test_i[10];          // N xor V
      4'd15: cond_test = (test_i[9] ^ test_i[10]) | test_i[11];
      default: cond_test = 1'b0;
    endcase
  end

  // Cond. = (Test[S] OR I5) XOR I4 (Table 1 note). Class 11 ignores the
  // condition; class 10 forces it true through I5.
  wire row_pass = (cls == 2'b11) ? 1'b1 : ((cond_test | eff[5]) ^ eff[4]);

  // ------------------------------------------------------------------
  // Address multiplexer sources (1988 page 3-7).
  wire [AW-1:0] inc = cin_n_i ? ar_q : (ar_q + 16'd1);
  wire [3:0] mw_set = (d_i[1:0] == 2'd0) ? m0_i :
                      (d_i[1:0] == 2'd1) ? m1_i :
                      (d_i[1:0] == 2'd2) ? m2_i : m3_i;
  wire [AW-1:0] mw  = {d_i[15:4], mw_set};

  // Stack addressing: push writes slot SP mod 33, top of stack is slot
  // (SP-1) mod 33 on the modulo-64 pointer (see spec assumption ledger).
  function automatic logic [5:0] mod33(input logic [5:0] v);
    mod33 = (v >= 6'd33) ? (v - 6'd33) : v;
  endfunction
  wire [5:0] push_idx = mod33(sp_q);
  wire [5:0] tos_idx  = mod33(sp_q - 6'd1);
  wire [AW-1:0] tos   = stack_q[tos_idx];

  // Branch qualification: END FOR rows (I3-I0 = 3/7/B/F in classes 0-2)
  // also require counter != 1 and always decrement.
  wire endfor = (cls != 2'b11) &&
                ((row == 4'd3) || (row == 4'd7) || (row == 4'hB) || (row == 4'hF));
  wire c_is_1 = (c_q == 16'd1);
  wire branch = (cls == 2'b11) ? 1'b1 :
                (row_pass && (!endfor || !c_is_1));

  wire sel_d = (row <= 4'd3);
  wire sel_a = (row >= 4'd4) && (row <= 4'd7);
  wire sel_m = (row >= 4'd8) && (row <= 4'hB);
  wire [AW-1:0] pass_src = sel_d ? d_i : sel_a ? a_i : sel_m ? mw : tos;
  wire [AW-1:0] y_mux = rst_active ? 16'h0 :
                         (cls == 2'b11) ? inc :
                         (branch ? pass_src : inc);

  // ------------------------------------------------------------------
  // Instruction decode: stack action, counter action, comparator action,
  // D-bus output mux (Tables 1 and 2).
  localparam logic [2:0] ST_HOLD = 3'd0, ST_PUSH_INC = 3'd1, ST_PUSH_D  = 3'd2,
                         ST_PUSH_C = 3'd3, ST_POP = 3'd4, ST_CALL_S = 3'd5,
                         ST_SWAP = 3'd6, ST_SP_RST = 3'd7;
  localparam logic [2:0] CT_HOLD = 3'd0, CT_LD_D = 3'd1, CT_LD_A = 3'd2,
                         CT_DEC = 3'd3, CT_LD_TOS = 3'd4, CT_SWAP = 3'd5;

  logic [2:0] stack_act, counter_act;
  logic [1:0] comp_act;               // 0 hold, 1 SET, 2 CLEAR
  logic       dmux_tos;
  always_comb begin
    stack_act   = ST_HOLD;
    counter_act = CT_HOLD;
    comp_act    = 2'd0;
    dmux_tos    = 1'b0;
    case (cls)
      2'b00, 2'b01, 2'b10: begin
        case (row)
          4'h1:  if (row_pass) stack_act = ST_PUSH_INC;   // CALL
          4'h2:  if (row_pass) stack_act = ST_POP;        // EXIT
          4'h3:  counter_act = CT_DEC;                    // END FOR D
          4'h5:  if (row_pass) stack_act = ST_PUSH_INC;
          4'h6:  if (row_pass) stack_act = ST_POP;
          4'h7:  counter_act = CT_DEC;
          4'h9:  if (row_pass) stack_act = ST_PUSH_INC;
          4'hA:  if (row_pass) stack_act = ST_POP;
          4'hB:  counter_act = CT_DEC;
          4'hC:  if (!row_pass) stack_act = ST_POP;       // GOTO TOS else pop
          4'hD:  if (row_pass) stack_act = ST_CALL_S;     // CALL TOS
          4'hE:  if (row_pass) stack_act = ST_POP;        // RETURN
          4'hF: begin                                     // END FOR S
            counter_act = CT_DEC;
            if (!row_pass || c_is_1) stack_act = ST_POP;
          end
          default: ;
        endcase
      end
      default: begin                                      // class 11
        case (row)
          4'h1: begin stack_act = ST_PUSH_INC; counter_act = CT_LD_D;   end
          4'h2: counter_act = CT_DEC;
          4'h3: stack_act = ST_PUSH_INC;
          4'h4: begin stack_act = ST_POP; dmux_tos = 1'b1;              end
          4'h5: stack_act = ST_PUSH_D;
          4'h6: stack_act = ST_SP_RST;
          4'h7: begin stack_act = ST_PUSH_INC; counter_act = CT_LD_A;   end
          4'h8: begin stack_act = ST_POP;      counter_act = CT_LD_TOS; end
          4'h9: stack_act = ST_PUSH_C;
          4'hA: begin stack_act = ST_SWAP;     counter_act = CT_SWAP;   end
          4'hB: begin stack_act = ST_PUSH_C;   counter_act = CT_LD_D;   end
          4'hC: counter_act = CT_LD_D;
          4'hD: counter_act = CT_LD_A;
          4'hE: comp_act = 2'd1;                              // SET
          4'hF: comp_act = 2'd2;                              // CLEAR
          default: ;
        endcase
      end
    endcase
  end

  // ------------------------------------------------------------------
  // Interrupt path: acceptance requires INTEN high with no reset or hold
  // (1988 page 3-11). The interrupt multiplexer feeds the Y-bus value into
  // the address register and comparator; the sequencer releases Y and
  // asserts INTA. One cycle later the interrupt return address register is
  // pushed automatically (Figures 4 and 5).
  wire intr_accept = intr_i && inten_i && !rst_active && !hold_i;
  wire [AW-1:0] int_mux = rst_active ? 16'h0 :
                          (intr_accept ? y_i : y_mux);

  // ------------------------------------------------------------------
  // Outputs.
  assign y_oe_o      = !hold_i && !slave_i && !intr_accept;
  assign y_o         = y_mux;
  assign d_oe_o      = oed_i && !rst_active && !hold_i && !slave_i;
  assign d_o         = dmux_tos ? tos : {10'd0, sp_q};
  assign inta_oe_o   = !hold_i && !slave_i;
  assign inta_o      = !intr_accept;
  assign a_full_oe_o = !hold_i && !slave_i;
  assign a_full_o    = (sp_q >= 6'd28);
  assign equal_oe_o  = !hold_i && !slave_i;
  assign equal_o     = cmp_en_q && !rst_active && (int_mux == r_q);

  // Master/slave error: any enabled bidirectional output whose driven value
  // disagrees with the observed pin. The same expressions serve the slave,
  // which computes what it would drive and compares the master's pins.
  wire err_y    = !hold_i && !intr_accept && (y_o  != y_i);
  wire err_d    = oed_i && !rst_active && !hold_i && (d_o  != d_i);
  wire err_inta = !hold_i && (inta_o    != inta_i);
  wire err_af   = !hold_i && (a_full_o  != a_full_i);
  wire err_eq   = !hold_i && (equal_o   != equal_i);
  assign error_o = err_y | err_d | err_inta | err_af | err_eq;

  // ------------------------------------------------------------------
  // Next-state values.
  logic [AW-1:0] push_val, c_next;
  always_comb begin
    case (stack_act)
      ST_PUSH_INC, ST_CALL_S: push_val = inc;
      ST_PUSH_D:              push_val = d_i;
      ST_PUSH_C:              push_val = c_q;
      default:                push_val = inc;
    endcase
    case (counter_act)
      CT_LD_D:    c_next = d_i;
      CT_LD_A:    c_next = a_i;
      CT_DEC:     c_next = c_q - 16'd1;
      CT_LD_TOS:  c_next = tos;
      CT_SWAP:    c_next = tos;
      default:    c_next = c_q;
    endcase
  end

  // Instruction stack effect first; the deferred interrupt push applies on
  // top of the resulting pointer.
  logic [5:0] sp_instr;
  always_comb begin
    case (stack_act)
      ST_PUSH_INC, ST_PUSH_D, ST_PUSH_C: sp_instr = sp_q + 6'd1;
      ST_POP:                            sp_instr = sp_q - 6'd1;
      ST_CALL_S, ST_SWAP:                sp_instr = sp_q;
      ST_SP_RST:                         sp_instr = 6'd0;
      default:                           sp_instr = sp_q;
    endcase
  end

  // CALL TOS pops and pushes INC: one write at the current top slot, with
  // the pointer unchanged. When the deferred interrupt push fires, it wins:
  // the concurrent instruction's stack field is ignored entirely (the
  // datasheet leaves the overlapping case undefined; this model resolves
  // it deterministically - see spec assumption ledger).
  wire instr_write = (stack_act == ST_PUSH_INC) || (stack_act == ST_PUSH_D) ||
                     (stack_act == ST_PUSH_C)  || (stack_act == ST_CALL_S) ||
                     (stack_act == ST_SWAP);
  wire do_write   = int_push_q || instr_write;
  logic [5:0]    wr_idx;
  logic [AW-1:0] wr_val;
  always_comb begin
    wr_idx = push_idx;
    wr_val = push_val;
    if (int_push_q) begin           // automatic interrupt push (Figure 5)
      wr_idx = mod33(sp_q);
      wr_val = irar_q;
    end else if (stack_act == ST_CALL_S || stack_act == ST_SWAP) begin
      wr_idx = tos_idx;
      wr_val = (stack_act == ST_SWAP) ? c_q : inc;
    end
  end
  wire [5:0] sp_next = int_push_q ? (sp_q + 6'd1) : sp_instr;

  logic [AW-1:0] r_next;
  always_comb begin
    case (comp_act)
      2'd1: r_next = d_i;
      default: r_next = r_q;
    endcase
  end
  logic cmp_en_next;
  always_comb begin
    case (comp_act)
      2'd1:  cmp_en_next = 1'b1;
      2'd2:  cmp_en_next = 1'b0;
      default: cmp_en_next = cmp_en_q;
    endcase
  end

  // ------------------------------------------------------------------
  // Sequential behavior. Reset synchronously selects address 0, forces
  // EQUAL low, disables comparison and clears the stack pointer; the
  // counter and comparison register contents are not documented as cleared
  // and are retained (spec assumption ledger). Hold freezes all state.
  always_ff @(posedge cp_i) begin
    if (rst_active) begin
      ar_q      <= 16'd0;
      irar_q    <= 16'd0;
      sp_q      <= 6'd0;
      cmp_en_q  <= 1'b0;
      int_push_q <= 1'b0;
    end else if (!hold_i) begin
      ar_q      <= int_mux;
      irar_q    <= y_mux;
      sp_q      <= sp_next;
      c_q       <= c_next;
      r_q       <= r_next;
      cmp_en_q  <= cmp_en_next;
      int_push_q <= intr_accept;
      if (do_write) stack_q[wr_idx] <= wr_val;
    end
  end

`ifdef FORMAL
  `include "amd_am29331_props.sv"
`endif
endmodule
