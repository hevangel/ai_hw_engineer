// Display sequencer invariants with free register contents and data. The
// raster inputs are constrained only to legal positions/transition flags.
localparam logic [6:0] CYCLES = PAL ? 7'd71 : 7'd65;
logic past_valid = 1'b0;
logic color_write, chargen_fetch;
assign color_write = reg_write_i && reg_addr_i[3:1] == 3'b111;
assign chargen_fetch = fetch_o && !fetch_matrix_o;

always_comb begin
    assume (scan_h_i < CYCLES);
    assume (line_end_i == (rst_n && ce_i && scan_h_i == CYCLES - 7'd1));
    assume (!frame_end_i || line_end_i);
end

always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid) begin
        assert (fetch_q <= FETCH_DONE);
        assert (pend_q != 2'd3);
        assert (shift_pos_q <= 4'd8);
        assert (start_delay_q <= 3'd4);
        if (fetch_q == FETCH_START) assert (start_delay_q != 0);
        assert (text_cols_q <= MAX_COLUMNS && pending_cols_q <= MAX_COLUMNS);
        assert (buf_offset_q <= MAX_COLUMNS);
        assert (vmc_left_q <= {MAX_COLUMNS, 1'b0});
        // Exactly one fetch per enabled matrix/character state, never at a
        // line end (which returns the sequencer to idle) or while held.
        assert (fetch_o == (rst_n && ce_i && !line_end_i &&
                            (fetch_q == FETCH_MATRIX || fetch_q == FETCH_CHARGEN)));
        assert (fetch_matrix_o == (fetch_o && fetch_q == FETCH_MATRIX));
        if (fetch_matrix_o)
            assert (fetch_addr_o == {r5[7:4], r2[7], 9'd0} + {3'd0, vmc_q[11:1]});
        if (!fetch_o) assert (fetch_addr_o == 0);
        // A character fetch enters the load pipeline; matrix data is latched.
        if ($past(rst_n && chargen_fetch)) begin
            assert (load_q[1]);
            assert (gload_q[1] == $past(fetch_data_i[7:0]));
            assert (cload_q[1] == $past(cbuf_q));
        end
        if ($past(rst_n && fetch_matrix_o))
            assert (vbuf_q == $past(fetch_data_i[7:0]) && cbuf_q == $past(fetch_data_i[11:8]));
        // Pending color writes are consumed by the next enabled cycle.
        if ($past(rst_n && ce_i && !color_write)) assert (pend_q == PEND_NONE);
        if ($past(rst_n && color_write)) begin
            assert (pend_q == ($past(reg_addr_i[0]) ? PEND_COLOR : PEND_AUX));
            assert (pend_data_q == $past(reg_data_i));
        end
        // Holds freeze the display sequencer and shifter.
        if ($past(rst_n && !ce_i)) begin
            assert (area_q == $past(area_q) && fetch_q == $past(fetch_q));
            assert (vmc_q == $past(vmc_q) && ycounter_q == $past(ycounter_q));
            assert (shift_pos_q == $past(shift_pos_q) && gdata_q == $past(gdata_q));
        end
        if (!$past(rst_n)) begin
            assert (area_q == AREA_IDLE && fetch_q == FETCH_IDLE);
            assert (shift_pos_q == 4'd8 && load_q == 0 && pend_q == PEND_NONE);
        end
        // An exhausted shifter without a load or color change shows border.
        if (rst_n && ce_i && shift_pos_q == 4'd8 && !load_q[0] && pend_q == PEND_NONE)
            assert (pixel_o == {4{1'b0, out_border_q}});
        cover (fetch_matrix_o);
        cover (chargen_fetch);
        cover (area_q == AREA_DISPLAY);
        cover (rst_n && ce_i && load_q[0]);
        cover (rst_n && ce_i && pend_q == PEND_COLOR);
        cover (rst_n && ce_i && cdata_q[3] && shift_pos_q < 4'd8);
    end
end
