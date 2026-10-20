    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(count_o == 16'hffff && latch_o == 16'hffff);
                assert(!started_o && !underflow_o);
            end else begin
                assert(underflow_o == $past(underflow_event_o));
                if (underflow_o || $past(load_delay_q)) assert(count_o == latch_o);
                if ($past(write_low_i)) assert(latch_o[7:0] == $past(data_i));
                else assert(latch_o[7:0] == $past(latch_o[7:0]));
                if ($past(write_high_i)) assert(latch_o[15:8] == $past(data_i));
                else assert(latch_o[15:8] == $past(latch_o[15:8]));
                if ($past(write_control_i)) assert(started_o == $past(data_i[0]));
                if (underflow_o && $past(oneshot_q || oneshot_early_q) && !$past(write_control_i))
                    assert(!started_o);
                if ($past(!enable_late_q && !load_next && !write_high_i))
                    assert(count_o == $past(count_o));
                if ($past(enable_late_q && count_q != 0 && !load_next && !write_high_i))
                    assert(count_o == $past(count_o)-16'd1);
            end
        end
        cover(f_valid && rst_n && underflow_o && started_o);
        cover(f_valid && rst_n && underflow_o && !started_o);
        cover(f_valid && rst_n && underflow_o && $past(underflow_o));
        cover(f_valid && rst_n && load_delay_q && started_o);
        cover(f_valid && rst_n && underflow_o && $past(write_low_i));
        cover(f_valid && rst_n && enable_late_q && !phi2_mode_i);
    end
