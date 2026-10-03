    logic f_past_valid = 0;
    (* anyconst *) logic f_bank;
    (* anyconst *) logic [COL_BITS-1:0] f_address;
    logic f_written = 0;
    logic [7:0] f_data;
    always_ff @(posedge clk) begin
        f_past_valid <= 1;
        if (!f_past_valid) assume(!rst_n);
        assume(f_address < MAX_COLS);
        if (!rst_n) f_written <= 0;
        else begin
            if (f_written) assert(row_buffer[f_bank][f_address] == f_data);
            if (ack && !command && !stop_pending && !replacement &&
                fill_count < columns && fill_bank == f_bank &&
                fill_count == f_address) begin
                f_written <= 1; f_data <= db_in;
            end
        end
        if (f_past_valid && rst_n && $past(rst_n)) begin
            assert(columns >= 1 && columns <= MAX_COLS);
            assert(fill_count <= MAX_COLS);
            assert(fifo_count <= 16);
            assert(param_left <= 4 && param_index <= 4);
            assert(preset_delay <= 2);
            assert(!drq || (filling && !preset));
            if (ack && !stop_pending && !replacement) assert(fill_count < columns);
            assert(!irq || ir);
            assert(db_out[7] == 0 || !a0);
            assert(!hrtc || vsp);
            assert(!vrtc || vsp);
            assert(ve || (vsp && !lten));
            if ($past(preset && preset_delay == 0 && !command)) begin
                assert(x == 0 && row == 0 && line == 0);
            end
            if ($past(!dack_n)) assert(!ack);
            if ($past(!cs_n && !wr_n) && !cs_n && !wr_n) assert(!bus_write);
            if ($past(!cs_n && !rd_n) && !cs_n && !rd_n) assert(!bus_read);
        end
`ifdef FORMAL_COVER
        cover(rst_n && drq);
        cover(rst_n && display_valid && !vsp);
        cover(rst_n && graphic_code && display_valid && la != 0);
        cover(rst_n && cursor_on && display_valid && !vsp);
        cover(rst_n && replacement);
        cover(rst_n && lp);
        cover(rst_n && irq);
        cover(rst_n && du && blank_frame);
        cover(rst_n && f_written);
        cover(rst_n && frame_phase == 2 && display_valid && !vsp);
`endif
    end
