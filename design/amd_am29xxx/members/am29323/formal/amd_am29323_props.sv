// Formal properties for the Am29323. Included inside amd_am29323 under
// `ifdef FORMAL. Reference behavior is recomputed from the datasheet
// Tables 1-3 and the FA figure, independently sequenced from the RTL.
logic past_valid = 0;

// Independent recomputation of the command word and product.
wire [6:0] ref_cmd = fti_i ? {acc1_i, acc0_i, rnd_i, tsel_i, fa_i,
                              psel1_i, psel0_i} : i_q;
wire signed [63:0] ref_xa = tcx_i ? signed'({{32{xm[31]}}, xm})
                                  : signed'({32'b0, xm});
wire signed [63:0] ref_ya = tcy_i ? signed'({{32{ym[31]}}, ym})
                                  : signed'({32'b0, ym});
wire signed [63:0] ref_prod = ref_xa * ref_ya;
wire [66:0] ref_prod67 = {{3{ref_prod[63]}}, ref_prod};
wire [66:0] ref_shifted = {{32{acc_q[66]}}, acc_q[66:32]};
logic [66:0] ref_acc_n;
always_comb begin
  case (ref_cmd[6:5])
    2'b00: ref_acc_n = ref_prod67;
    2'b01: ref_acc_n = acc_q + ref_prod67;
    2'b10: ref_acc_n = acc_q;                 // INVALID: hold (ledger)
    2'b11: ref_acc_n = ref_shifted + ref_prod67;
    default: ref_acc_n = acc_q;
  endcase
end
wire [66:0] ref_psrc = ftp_i ? ref_prod67 : acc_q;
wire [31:0] ref_lo1 = ref_psrc[31:0];
wire [31:0] ref_lo0 = {ref_psrc[30:0], 1'b0};
wire [31:0] ref_hi1 = ref_cmd[4] ? (ref_psrc[63:32] + ref_psrc[31])
                                 : ref_psrc[63:32];
wire [31:0] ref_hi0 = ref_cmd[4] ? (ref_psrc[62:31] + ref_psrc[30])
                                 : ref_psrc[62:31];
wire [31:0] ref_t_in = ref_cmd[3] ? (ref_cmd[2] ? ref_hi1 : ref_hi0)
                                  : (ref_cmd[2] ? ref_lo1 : ref_lo0);
wire ref_disable = ref_cmd[1] && ref_cmd[0];
logic [31:0] ref_p_mux;
always_comb begin
  case (ref_cmd[1:0])
    2'b00: ref_p_mux = t_q;
    2'b01: ref_p_mux = ref_cmd[2] ? ref_lo1 : ref_lo0;
    2'b10: ref_p_mux = ref_cmd[2] ? ref_hi1 : ref_hi0;
    default: ref_p_mux = '0;
  endcase
end

// Combinational output contract, checked every timestep.
always @* begin
  assert(p_oe_o == (!oe_n_i && !ref_disable && !slave_i));
  assert(pp_oe_o == p_oe_o);
  if (p_oe_o) assert(p_o == ref_p_mux);
  assert(pp_o == {^p_mux[31:24], ^p_mux[23:16], ^p_mux[15:8], ^p_mux[7:0]});
  assert(parerr_oe_o == !slave_i);
  assert(parerr_o == (((px_i ^ {^x_i[31:24], ^x_i[23:16], ^x_i[15:8],
                          ^x_i[7:0]}) != 4'b0) ||
                      ((py_i ^ {^y_i[31:24], ^y_i[23:16], ^y_i[15:8],
                          ^y_i[7:0]}) != 4'b0)));
  assert(harderr_o == ((p_oe_o && (p_o != p_i)) ||
                       (pp_oe_o && (pp_o != pp_i)) ||
                       (parerr_oe_o && (parerr_o != parerr_i))));
end

// Register capture discipline: anyconst selects one watched register;
// its value follows the documented source at each edge, holds otherwise.
(* anyconst *) logic [2:0] watched_reg;
logic [31:0] watched_src;
always @* begin
  case (watched_reg)
    3'd0: watched_src = x_i;                       // XA
    3'd1: watched_src = x_i;                       // XB
    3'd2: watched_src = y_i;                       // YA
    3'd3: watched_src = y_i;                       // YB
    3'd4: watched_src = ref_t_in;                  // T
    default: watched_src = ref_acc_n[31:0];        // accumulator low word
  endcase
end

always_ff @(posedge fml_clk_i) begin
  if (!past_valid) begin
    assume(watched_reg < 3'd5);
    past_valid <= 1'b1;
  end else begin
    case (watched_reg)
      3'd0: assert(xa_q == ($past(enxa_n_i) ? $past(xa_q) : $past(x_i)));
      3'd1: assert(xb_q == ($past(enxb_n_i) ? $past(xb_q) : $past(x_i)));
      3'd2: assert(ya_q == ($past(enya_n_i) ? $past(ya_q) : $past(y_i)));
      3'd3: assert(yb_q == ($past(enyb_n_i) ? $past(yb_q) : $past(y_i)));
      3'd4: assert(t_q == ($past(ent_n_i) ? $past(t_q) : $past(ref_t_in)));
      default: begin
        if ($past(enp_n_i))
          assert(acc_q == $past(acc_q));
        else
          assert(acc_q == $past(ref_acc_n));
      end
    endcase
    // Instruction register capture discipline.
    assert(i_q == ($past(eni_n_i) ? $past(i_q)
                                  : $past({acc1_i, acc0_i, rnd_i, tsel_i,
                                           fa_i, psel1_i, psel0_i})));
  end
end

// Reachable covers: accumulator commands, slice selections, format
// adjust, rounding, feedthrough, parity error, slave mode, disable.
always @* begin
  cover(past_valid && !ref_cmd[6] && !ref_cmd[5]);           // PASS
  cover(past_valid && !ref_cmd[6] && ref_cmd[5]);            // ACCUMULATE
  cover(past_valid && ref_cmd[6] && !ref_cmd[5]);            // INVALID
  cover(past_valid && ref_cmd[6] && ref_cmd[5]);             // SHIFT AND ACC
  cover(past_valid && ref_cmd[1:0] == 2'b00);
  cover(past_valid && ref_cmd[1:0] == 2'b01);
  cover(past_valid && ref_cmd[1:0] == 2'b10);
  cover(past_valid && ref_cmd[1:0] == 2'b11);                // DISABLE
  cover(past_valid && ref_cmd[2]);                           // FA=1
  cover(past_valid && ref_cmd[4]);                           // RND
  cover(past_valid && ftp_i);
  cover(past_valid && slave_i);
  cover(past_valid && parerr_o);
  cover(past_valid && harderr_o);
  cover(past_valid && tcx_i != tcy_i);                       // mixed mode
  cover(past_valid && ftx_i && fty_i);                       // full feedthrough
end
