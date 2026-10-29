    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        if (f_valid) begin
            assert((time_q & 32'h608080f0) == 0);
            assert((alarm_q & 32'h608080f0) == 0);
            if (!$past(rst_n)) begin
                assert(time_q == {RESET_HOUR & 8'h9f,24'b0} && alarm_q == 0);
                assert(stopped_q && !latched_q && divider_q == 0);
            end else begin
                if ($past(stopped_q && (!write_i || alarm_select_i))) assert(time_q == $past(time_q));
                if ($past(write_i && !alarm_select_i && addr == 3)) assert(stopped_q);
                if ($past(write_i && !alarm_select_i && addr == 0)) assert(!stopped_q);
                if ($past(read_i && addr == 0)) assert(!latched_q);
                if ($past(latched_q)) assert(snapshot_q == $past(snapshot_q));
                if ($past(read_i && addr == 3 && !latched_q)) begin
                    assert(latched_q && snapshot_q == $past(time_q));
                end
            end
        end
        cover(f_valid && rst_n && alarm_event_o);
        cover(f_valid && rst_n && latched_q && !stopped_q && time_q != snapshot_q);
        cover(f_valid && rst_n && stopped_q && edge_i);
        cover(f_valid && rst_n && time_q[31:24] == 8'h92 && time_q[23:0] == 0);
        cover(f_valid && rst_n && divider_q == 5 && edge_i && !mode_50hz_i && !stopped_q);
    end
