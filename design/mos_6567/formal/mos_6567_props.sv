// Structural invariants of the VIC-II dot/cycle sequencer with free CPU,
// pen and memory inputs. Display behavior is qualified by the oracle
// comparison; these properties guard counters, the write pipeline and
// bus-control relations under any input sequence.
logic past_valid = 1'b0;
always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid && rst_n) begin
        assert (pos_q <= 4'd8);
        assert (cycle_q >= 7'd1 && int'(cycle_q) <= CPL);
        assert (int'(rasterline_q) < LINES && int'(beam_q) < LINES);
        assert (bus_slot_q < 5'd24 || bus_slot_q == 5'h1f);
        assert (int'(pix_index_q) < OUTPUT_LAG && int'(pix_count_q) <= OUTPUT_LAG);
        assert (hold_mm_q <= 4'd12 && hold_md_q <= 4'd12);
        assert (cycle_edge_o == (pos_q >= 4'd7));
        assert (irq_n_o == ((irq_flags_q & irq_enable_q) == 0));
        // AEC can only be low while BA is low (three-cycle delayed release).
        if (!aec_q) assert (!ba_q);
        // The write pipeline lives within one cycle; late fields only at dot 0.
        if (late_valid_q) assert (pos_q == 4'd0 && late_mask_q != 0);
        if (wr_valid_q) assert (pos_q >= 4'd1 && pos_q <= 4'd7);
        for (int b = 0; b < 8; b++) assert (wr_seen_q[4*b +: 4] <= 4'd8);
        // Exactly one phase-one address per cycle edge; phase two only then.
        if (phi2_fetch_o) assert (cycle_edge_o);
        if (color_fetch_o) assert (cycle_edge_o);
        if (pixel_valid_o) assert (pos_q < 4'd8);
        if ($past(rst_n) && $past(pos_q) < 4'd7) assert (pos_q == $past(pos_q) + 4'd1);
        if ($past(rst_n) && $past(pos_q) >= 4'd7) begin
            assert (pos_q == 4'd0);
            assert (cycle_q == (int'($past(cycle_q)) == CPL ? 7'd1 : $past(cycle_q) + 7'd1));
        end
        cover (pixel_valid_o);
        cover (!irq_n_o);
        cover (late_valid_q);
        cover (reg_q[R_LPX] != 0);
        cover (pos_q == 4'd4 && $past(cs_i && rw_i && addr_i == R_MM));
    end
    if (past_valid && !$past(rst_n)) begin
        assert (pos_q == 4'd8 && cycle_q == 7'd14 && irq_n_o && ba_q && aec_q);
    end
end
