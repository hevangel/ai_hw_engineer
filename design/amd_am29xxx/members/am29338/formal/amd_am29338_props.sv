// Formal properties for the Am29338. Included inside amd_am29338 under
// `ifdef FORMAL. The DUT has two independent clocks (QCLK/DQCLK), so the
// property layer checks per-timestep contracts and register invariants
// without $past cross-clock sampling; the sequential discipline is
// exercised by the 12,122-drive lockstep simulation.
logic past_valid = 0;

// Independently recomputed byte-count and status.
wire [8:0] ref_count = q_cnt - d_cnt;
wire [7:0] ref_cnt_sat = ref_count[8] ? 8'd0 :
                         (ref_count > 9'd128 ? 8'd128 : ref_count[7:0]);

always @* begin
  assert(cnt_o == ref_cnt_sat[6:0]);
  assert(full_o == (ref_cnt_sat == 8'd128));
  assert(a_full_o == (ref_cnt_sat > 8'd124));
  assert(empty_o == (ref_cnt_sat == 8'd0));
  assert(a_empty_o == (ref_cnt_sat < 8'd4));
  assert(y_oe_o == !oe_n_i);
  assert(pderr_o == pderr_c);
  assert(pyerr_o == (y_oe_o && pyerr_c));
  // Output window: the four bytes following the dequeue pointer.
  for (int k = 0; k < 4; k++) begin
    assert(y_o[8 * k +: 8] == mem[7'((d_ptr + 7'(k)) & 7'd127)][7:0]);
    assert(py_o[k] == mem[7'((d_ptr + 7'(k)) & 7'd127)][8]);
  end
end

// Invariants: counts saturate, and the reset state is held while RESET
// is asserted (async level hold).
always_ff @(posedge fml_clk_i) begin
  if (!past_valid) begin
    assume(reset_n_i == 1'b0);            // start from a known reset state
    past_valid <= 1'b1;
  end else begin
    assert(q_cnt <= 8'd128);
    assert(d_cnt <= 8'd128);
    if (!reset_n_i) begin
      assert(q_ptr == 7'd0);
      assert(d_ptr == 7'(32 * pos_i));
      assert(q_cnt == 8'd0);
      assert(d_cnt == 8'd0);
    end
  end
end

// Reachable covers: byte counts, BSW encodings, statuses, control
// events, parity errors.
always @* begin
  cover(past_valid && bq_i == 2'b00);
  cover(past_valid && bq_i == 2'b01);
  cover(past_valid && bq_i == 2'b10);
  cover(past_valid && bq_i == 2'b11);
  cover(past_valid && bsw_i == 2'b01);
  cover(past_valid && bsw_i == 2'b10);
  cover(past_valid && bsw_i == 2'b11);
  cover(past_valid && bdq_i == 4'b0000);            // dequeue 16
  cover(past_valid && full_o);
  cover(past_valid && empty_o);
  cover(past_valid && a_full_o && !full_o);
  cover(past_valid && a_empty_o && !empty_o);
  cover(past_valid && pderr_o);
  cover(past_valid && pyerr_o);
  cover(past_valid && !reset_n_i);
  cover(past_valid && !rxmit_n_i);
  cover(past_valid && !qen_n_i && !dqen_n_i);       // simultaneous clocks
  cover(past_valid && pos_i != 2'b00);              // cascade quadrant
end
