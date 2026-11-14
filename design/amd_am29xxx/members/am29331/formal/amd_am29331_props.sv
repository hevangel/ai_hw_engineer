// Formal properties for the Am29331 digital model. Included inside
// amd_am29331 under `ifdef FORMAL. The reference behavior is recomputed
// here from the manufacturer CSV transcription (table_oracle.svh, generated
// by scripts/generate_oracle.py from references/instructions.csv) and from
// the datasheet control equations, independently of the RTL decode cases.
`include "table_oracle.svh"

(* anyconst *) logic [5:0] watched_slot;
logic past_valid = 0;
// Shadow of the watched stack word, driven only by the reference write
// model; the RTL memory is compared against it without any $past of a
// memory read.
logic [15:0] watched_q = 16'h0000;
logic [15:0] watched_exp;
always_comb begin
  // Expected word after the edge: the reference write model's value when
  // it writes, otherwise the RTL word itself (so only unpredicted RTL
  // writes can diverge). Reset and hold suppress every write, including
  // the deferred interrupt push (the RTL latches it until hold releases).
  watched_exp = stack_q[watched_slot];
  if (!rst_ref && !hold_i) begin
    if (int_push_q) begin
      // Automatic interrupt push wins; the concurrent instruction's stack
      // field is suppressed (documented model of the undefined overlap).
      watched_exp = (watched_slot == mod33(sp_q)) ? irar_q : stack_q[watched_slot];
    end else begin
      case (ref_actions[8:6])
        3'd1: watched_exp = (watched_slot == mod33(sp_q)) ? ref_inc : stack_q[watched_slot];
        3'd2: watched_exp = (watched_slot == mod33(sp_q)) ? d_i : stack_q[watched_slot];
        3'd3: watched_exp = (watched_slot == mod33(sp_q)) ? c_q : stack_q[watched_slot];
        3'd5: watched_exp = (watched_slot == ref_tos_idx) ? ref_inc : stack_q[watched_slot];
        3'd6: watched_exp = (watched_slot == ref_tos_idx) ? c_q : stack_q[watched_slot];
        default: ;
      endcase
    end
  end
end
always_ff @(posedge cp_i) begin
  watched_q <= watched_exp;
end

// Independent recomputation of the instruction qualification.
wire rst_ref      = !rst_n_i;
wire [5:0] op_ref = rst_ref ? 6'h30 : (fc_i ? 6'h30 : instr_i);
logic cond_ref;
always_comb begin
  case (select_i)
    4'd0:  cond_ref = test_i[0];
    4'd1:  cond_ref = test_i[1];
    4'd2:  cond_ref = test_i[2];
    4'd3:  cond_ref = test_i[3];
    4'd4:  cond_ref = test_i[4];
    4'd5:  cond_ref = test_i[5];
    4'd6:  cond_ref = test_i[6];
    4'd7:  cond_ref = test_i[7];
    4'd8:  cond_ref = test_i[8];
    4'd9:  cond_ref = test_i[9];
    4'd10: cond_ref = test_i[10];
    4'd11: cond_ref = test_i[11];
    4'd12: cond_ref = test_i[8]  | test_i[11];
    4'd13: cond_ref = ~test_i[8] | test_i[11];
    4'd14: cond_ref = test_i[9]  ^ test_i[10];
    4'd15: cond_ref = (test_i[9] ^ test_i[10]) | test_i[11];
    default: cond_ref = 1'b0;
  endcase
end
wire pass_ref = (op_ref[5:4] == 2'b11) ? 1'b1 : ((cond_ref | op_ref[5]) ^ op_ref[4]);
wire [11:0] ref_actions = manufacturer_table(op_ref, (c_q == 16'd1), pass_ref);

wire [15:0] ref_inc = cin_n_i ? ar_q : (ar_q + 16'd1);
wire [3:0] ref_mw_set = (d_i[1:0] == 2'd0) ? m0_i :
                        (d_i[1:0] == 2'd1) ? m1_i :
                        (d_i[1:0] == 2'd2) ? m2_i : m3_i;
wire [15:0] ref_mw  = {d_i[15:4], ref_mw_set};
wire [5:0]  ref_tos_idx = mod33(sp_q - 6'd1);
wire [15:0] ref_tos = stack_q[ref_tos_idx];
wire [5:0]  ref_push_idx = mod33(sp_q);
logic [15:0] ref_y;
always_comb begin
  case (ref_actions[11:9])
    4'd0: ref_y = ref_inc;
    4'd1: ref_y = d_i;
    4'd2: ref_y = a_i;
    4'd3: ref_y = ref_mw;
    4'd4: ref_y = ref_tos;
    default: ref_y = 16'd0;
  endcase
end
wire intr_ref = intr_i && inten_i && !rst_ref && !hold_i;
wire [15:0] ref_intmux = rst_ref ? 16'd0 : (intr_ref ? y_i : ref_y);

// Expected next stack pointer from the instruction's own stack field
// (Table 1/2 stack column); the deferred interrupt push adds one on the
// following cycle.
logic [5:0] ref_sp_instr;
always_comb begin
  case (ref_actions[8:6])
    3'd1, 3'd2, 3'd3: ref_sp_instr = sp_q + 6'd1;   // pushes
    3'd4:             ref_sp_instr = sp_q - 6'd1;   // pop
    3'd5, 3'd6:       ref_sp_instr = sp_q;          // CALL S / swap
    3'd7:             ref_sp_instr = 6'd0;          // reset SP
    default:          ref_sp_instr = sp_q;
  endcase
end

always_ff @(posedge cp_i) begin
  if (!past_valid) begin
    assume(watched_slot < 6'd33);
    assume(stack_q[watched_slot] == watched_q);   // seed shadow to RTL word
  end
  past_valid <= 1'b1;

  // Combinational contract, checked every cycle.
  assert(stack_act == ref_actions[8:6]);
  assert(counter_act == ref_actions[5:3]);
  assert(comp_act == ref_actions[2:1]);
  assert(dmux_tos == ref_actions[0]);
  assert(y_oe_o == (!hold_i && !slave_i && !intr_ref));
  assert(y_o == (rst_ref ? 16'd0 : ref_y));
  assert(d_oe_o == (oed_i && !rst_ref && !hold_i && !slave_i));
  assert(d_o == (ref_actions[0] ? ref_tos : {10'd0, sp_q}));
  assert(inta_oe_o == (!hold_i && !slave_i));
  assert(inta_o == !intr_ref);
  assert(a_full_oe_o == (!hold_i && !slave_i));
  assert(a_full_o == (sp_q >= 6'd28));
  assert(equal_oe_o == (!hold_i && !slave_i));
  assert(equal_o == (cmp_en_q && !rst_ref && (ref_intmux == r_q)));
  assert(error_o == ((!hold_i && !intr_ref && ((rst_ref ? 16'd0 : ref_y) != y_i)) ||
                     (oed_i && !rst_ref && !hold_i && ((ref_actions[0] ? ref_tos : {10'd0, sp_q}) != d_i)) ||
                     (!hold_i && ((!intr_ref) != inta_i)) ||
                     (!hold_i && ((sp_q >= 6'd28) != a_full_i)) ||
                     (!hold_i && ((cmp_en_q && !rst_ref && (ref_intmux == r_q)) != equal_i))));

  if (past_valid) begin
    // Watched stack word: RTL memory against the reference expectation.
    // The shadow defaults to the RTL word itself, so only an unpredicted
    // RTL write can diverge, and no $past of a memory read is needed.
    assert(stack_q[watched_slot] == watched_q);
    if ($past(rst_ref)) begin
      assert(ar_q == 16'd0);
      assert(irar_q == 16'd0);
      assert(sp_q == 6'd0);
      assert(cmp_en_q == 1'b0);
      assert(int_push_q == 1'b0);
      assert(c_q == $past(c_q));
      assert(r_q == $past(r_q));
    end else if ($past(hold_i)) begin
      assert(ar_q == $past(ar_q));
      assert(irar_q == $past(irar_q));
      assert(sp_q == $past(sp_q));
      assert(c_q == $past(c_q));
      assert(r_q == $past(r_q));
      assert(cmp_en_q == $past(cmp_en_q));
      assert(int_push_q == $past(int_push_q));
    end else begin
      assert(ar_q == $past(ref_intmux));
      assert(irar_q == $past(ref_y));
      assert(int_push_q == $past(intr_ref));
      case ($past(ref_actions[5:3]))
        3'd1: assert(c_q == $past(d_i));
        3'd2: assert(c_q == $past(a_i));
        3'd3: assert(c_q == ($past(c_q) - 16'd1));
        3'd4, 3'd5: assert(c_q == $past(ref_tos));
        default: assert(c_q == $past(c_q));
      endcase
      case ($past(ref_actions[2:1]))
        2'd1: begin assert(r_q == $past(d_i)); assert(cmp_en_q == 1'b1); end
        2'd2: begin assert(r_q == $past(r_q)); assert(cmp_en_q == 1'b0); end
        default: begin
          assert(r_q == $past(r_q));
          assert(cmp_en_q == $past(cmp_en_q));
        end
      endcase
      // Pointer: the automatic interrupt push adds one on the cycle after
      // acceptance; otherwise the instruction's own stack effect applies.
      if ($past(int_push_q))
        assert(sp_q == ($past(sp_q) + 6'd1));
      else
        assert(sp_q == $past(ref_sp_instr));
    end
  end

  // Reachable covers: every opcode, boundary states, interrupt/trap flows.
  for (int op = 0; op < 64; op++)
    cover(past_valid && instr_i == 6'(op));
  cover(past_valid && intr_ref);
  cover(past_valid && int_push_q);
  cover(past_valid && fc_i && cin_n_i && intr_ref);        // documented trap
  cover(past_valid && fc_i && !intr_ref);
  cover(past_valid && hold_i);
  cover(past_valid && slave_i);
  cover(past_valid && sp_q == 6'd27);
  cover(past_valid && sp_q == 6'd28);
  cover(past_valid && sp_q == 6'd33);
  cover(past_valid && sp_q == 6'd63);
  cover(past_valid && sp_q == 6'd0 && ref_actions[8:6] == 3'd4);   // underflow pop
  cover(past_valid && ref_actions[8:6] == 3'd5 && sp_q != 6'd0);   // CALL TOS exchange
  cover(past_valid && ref_actions[0] && sp_q != 6'd0);             // POP D TOS output
  cover(past_valid && equal_o);
  cover(past_valid && ref_actions[2:1] == 2'd1 && ref_intmux == d_i); // SET then match
  cover(past_valid && ref_actions[8:6] == 3'd7);                   // RESET SP
  for (int s = 0; s < 4; s++)
    cover(past_valid && (op_ref[3:0] == 4'h8 || op_ref[3:0] == 4'h9 ||
                         op_ref[3:0] == 4'hA || op_ref[3:0] == 4'hB) &&
          d_i[1:0] == s[1:0]);
  cover(past_valid && instr_i == 6'h2F && c_q == 16'd1);           // DJMP_S loop exit
  cover(past_valid && cin_n_i && instr_i == 6'h30 && !fc_i);       // forced stall
end
