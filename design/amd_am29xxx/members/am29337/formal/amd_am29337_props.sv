// Formal properties for the Am29337. Included inside amd_am29337 under
// `ifdef FORMAL.
logic past_valid = 0;
(* anyconst *) logic [4:0] watched_reg;   // 0 = lower, 1 = upper limit

// Independently recomputed comparisons (Table 1/2).
wire ref_lt_l = signed_i ? ($signed(d_i) <  $signed(l_q)) : (d_i <  l_q);
wire ref_le_l = signed_i ? ($signed(d_i) <= $signed(l_q)) : (d_i <= l_q);
wire ref_lt_u = signed_i ? ($signed(d_i) <  $signed(u_q)) : (d_i <  u_q);
wire ref_le_u = signed_i ? ($signed(d_i) <= $signed(u_q)) : (d_i <= u_q);
wire ref_col = cil_i ? ref_le_l : ref_lt_l;
wire ref_cou = ciu_i ? ref_le_u : ref_lt_u;

always @* begin
  assert(col_o == ref_col);
  assert(cou_o == ref_cou);
  assert(oob_o == !(ref_col && ref_cou));
end

// Limit register capture discipline.
always_ff @(posedge fml_clk_i) begin
  if (!past_valid) begin
    past_valid <= 1'b1;
  end else begin
    assert(l_q == ($past(enl_n_i) ? $past(l_q) : $past(d_i)));
    assert(u_q == ($past(enu_n_i) ? $past(u_q) : $past(d_i)));
  end
end

// Reachable covers: every Table 2 region for signed and unsigned,
// register loads, boundary equalities.
always @* begin
  cover(ref_col && ref_cou);                       // in bounds
  cover(!ref_col && ref_cou);                      // D <= L
  cover(ref_col && !ref_cou);                      // U <= D
  cover(!ref_col && !ref_cou);                     // impossible combination
  cover(ref_lt_l && ref_le_l);                     // boundary L == D
  cover(ref_lt_u && ref_le_u);                     // boundary U == D
  cover(signed_i);
  cover(past_valid && !enl_n_i && !enu_n_i);       // simultaneous load
  cover(past_valid && cil_i != ciu_i);             // asymmetric carries
end
