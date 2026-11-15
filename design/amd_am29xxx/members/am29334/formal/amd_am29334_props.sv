// Formal properties for the Am29334. Included inside amd_am29334 under
// `ifdef FORMAL. The device is asynchronous, so a formal-only clock
// (fml_clk_i, declared in the module's FORMAL port block) provides the
// property timebase; the RAM and output latches remain level-sensitive.
logic past_valid = 0;

(* anyconst *) logic [5:0] watched_a;
(* anyconst *) logic [5:0] watched_b;

// Shadows of the watched cells in both byte lanes, mirroring the
// documented write behavior with the A side winning a same-cell
// same-byte collision. Level-sensitive exactly like the RAM cells, so
// both sides evaluate the same conditions at every stable input state.
logic [8:0]  sh_l_a, sh_h_a, sh_l_b, sh_h_b;
always_latch begin
  if (a_we_l && awa_i == watched_a)      sh_l_a = da_i[8:0];
  else if (b_we_l && awb_i == watched_a) sh_l_a = db_i[8:0];
  if (a_we_h && awa_i == watched_a)      sh_h_a = da_i[17:9];
  else if (b_we_h && awb_i == watched_a) sh_h_a = db_i[17:9];
  if (a_we_l && awa_i == watched_b)      sh_l_b = da_i[8:0];
  else if (b_we_l && awb_i == watched_b) sh_l_b = db_i[8:0];
  if (a_we_h && awa_i == watched_b)      sh_h_b = da_i[17:9];
  else if (b_we_h && awb_i == watched_b) sh_h_b = db_i[17:9];
end

// Address multiplexer and read addressing, output enables and latch
// transparency/hold (combinational contract, checked every timestep).
always @* begin
  assert(rama == (wea_c_n_i ? ara_i : awa_i));
  assert(ramb == (web_c_n_i ? arb_i : awb_i));
  assert(ya_oe_o == !oea_n_i);
  assert(yb_oe_o == !oeb_n_i);
  if (lea_i) assert(ya_q == ram_qa);
  if (leb_i) assert(yb_q == ram_qb);
end

// State invariant: after the first formal cycle the watched cells equal
// their shadows (seeded on the first cycle, then both follow the same
// write conditions with the same data).
always_ff @(posedge fml_clk_i) begin
  if (!past_valid) begin
    assume(ram_l[watched_a] == sh_l_a);
    assume(ram_h[watched_a] == sh_h_a);
    assume(ram_l[watched_b] == sh_l_b);
    assume(ram_h[watched_b] == sh_h_b);
    past_valid <= 1'b1;
  end else begin
    assert(ram_l[watched_a] == sh_l_a);
    assert(ram_h[watched_a] == sh_h_a);
    assert(ram_l[watched_b] == sh_l_b);
    assert(ram_h[watched_b] == sh_h_b);
  end
end

// Reachable covers: byte writes, full writes, write windows, transparency
// (read of the written location during the write window with the latch
// open), cross-port visibility and the three-state outputs.
always @* begin
  cover(a_we_l && !a_we_h);
  cover(!a_we_l && a_we_h);
  cover(a_we_l && a_we_h);
  cover(!wea_c_n_i && rama == awa_i);
  cover(wea_c_n_i && rama == ara_i);
  cover(lea_i && !wea_c_n_i && rama == awa_i && ya_oe_o);   // transparency
  cover(lea_i && wea_c_n_i && rama == ara_i && ya_oe_o);
  cover(!lea_i && ya_oe_o);
  cover(ya_oe_o && yb_oe_o);
  cover(!ya_oe_o && !yb_oe_o);
  cover(a_we_l && b_we_l && awa_i == awb_i);                // both sides, one cell
  cover(leb_i && !web_c_n_i && ramb == awb_i && yb_oe_o);
end
