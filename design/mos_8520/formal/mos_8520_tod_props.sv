// 8520 TOD invariants with free pin, register and select inputs.
logic past_valid = 1'b0;
always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid && rst_n) begin
        // The comparator state tracks equality of time and alarm.
        assert (match_q == (time_q == alarm_q));
        // An alarm event only follows a register write or a divider tick
        // (a ripple tick may match a value the counter never settles on).
        if (alarm_pending_q) assert ($past(write_i) || $past(div_q) == 2'd3);
        // Register B reads high; the latch view only changes on a low read.
        if (addr == 2'd3) assert (data_o == 8'hff);
        if ($past(rst_n) && $past(latched_q) && latched_q) assert (latch_q == $past(latch_q));
        // A stopped counter only changes through register writes.
        if ($past(rst_n) && $past(stopped_q) && !$past(write_i)) assert (time_q == $past(time_q));
        // The /4 divider advances every cycle.
        if ($past(rst_n)) assert (div_q == $past(div_q) + 2'd1);
        cover (!stopped_q && time_q == 24'd2);
        cover (alarm_pending_q);
        cover (latched_q && time_q != latch_q);
        cover (time_q[12] && $past(time_q[11:0]) == 12'hfff);
    end
    if (past_valid && !$past(rst_n)) begin
        assert (time_q == 0 && alarm_q == 0 && stopped_q && !latched_q && match_q);
    end
end
