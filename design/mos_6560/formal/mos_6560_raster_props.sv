logic past_valid = 1'b0;
always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid) begin
        assert (h_q < CYCLES);
        assert (line_q < frame_lines_q);
        assert (raster_pos_o < CYCLES);
        // The light-pen lookahead must be exactly the readback after the edge.
        assert (raster_o == $past(raster_next_o));
        assert (raster_pos_o == $past(raster_pos_next_o));
        assert (frame_lines_q == $past(frame_lines_next_o));
        assert (frame_lines_q == LINES ||
                (!PAL && (frame_lines_q == LINES + 1 || frame_lines_q == LINES + 2)));
        assert (interlace_q || (!field_q && frame_lines_q == LINES));
        if (interlace_q) assert (frame_lines_q == (field_q ? LINES + 1 : LINES + 2));
        if (PAL) begin
            assert (!interlace_q && !field_q);
            assert (raster_o == line_q && raster_pos_o == h_q);
        end else begin
            assert (raster_o <= LINES + 2);
            if (line_q == 0 && h_q == 27) begin
                assert (raster_o == 0);
                assert (raster_pos_o == (field_q ? 64 : 31));
            end
            if (line_q == 0 && h_q == 28)
                assert (raster_o == 1 && raster_pos_o == 0);
        end
        if (!$past(rst_n)) begin
            assert (h_q == 0 && line_q == 0 && frame_lines_q == LINES);
            assert (!field_q && !interlace_q);
            assert (raster_o == 0 && raster_pos_o == (PAL ? 0 : 4));
        end else if (!$past(ce_i)) begin
            assert (h_q == $past(h_q) && line_q == $past(line_q));
            assert (frame_lines_q == $past(frame_lines_q));
            assert (field_q == $past(field_q) && interlace_q == $past(interlace_q));
        end else begin
            if ($past(h_q) == CYCLES - 1) begin
                assert (h_q == 0);
                if ($past(line_q) == $past(frame_lines_q) - 1) begin
                    assert (line_q == 0);
                    if (!PAL && $past(interlace_i)) begin
                        assert (interlace_q);
                        assert (field_q == ($past(interlace_q) ? !$past(field_q) : 1'b0));
                    end else begin
                        assert (!field_q && !interlace_q && frame_lines_q == LINES);
                    end
                end else begin
                    assert (line_q == $past(line_q) + 1);
                end
            end else begin
                assert (h_q == $past(h_q) + 1);
                assert (line_q == $past(line_q));
            end
            if (!$past(frame_end_o)) begin
                assert (frame_lines_q == $past(frame_lines_q));
                assert (field_q == $past(field_q) && interlace_q == $past(interlace_q));
            end
        end
        cover (rst_n && line_end_o);
        cover (rst_n && scan_line_o == 1 && scan_h_o == 1);
        cover (rst_n && !ce_i && scan_h_o == 7);
        cover (!rst_n && scan_line_o == 1);
    end
end
