// Included inside the DUT so properties can inspect state without bind support.
    logic f_past_valid = 0;
    (* anyconst *) logic [6:0] f_address;
    logic [7:0] f_memory;
    logic f_memory_valid = 0;
    always_ff @(negedge clk) begin
        f_past_valid <= 1;
        if (!f_past_valid) assume(!rst_n);
        if (rst_n && writing && !rs && addr == f_address) begin
            f_memory <= data_i;
            f_memory_valid <= 1;
        end
        if (f_memory_valid) assert(ram[f_address] == f_memory);
        assert(data_oe == (clk && rst_n && cs1 && !cs2_n && rw));
        assert(irq_n == !(rst_n && ((timer_flag && timer_enable) ||
                                  (edge_flag && edge_enable))));
        if (rs && addr[2] && addr[0])
            assert(data_o == {timer_flag, edge_flag, 6'b0});
        if (f_past_valid) begin
            if (!$past(rst_n)) begin
                assert(ora == 0 && orb == 0 && ddra == 0 && ddrb == 0);
                assert(!timer_running && !timer_flag && !edge_flag);
                assert(!timer_enable && !edge_enable && !edge_positive);
            end else begin
                if ($past(writing && rs && !addr[2] && addr[1:0] == 0))
                    assert(ora == $past(data_i));
                else assert(ora == $past(ora));
                if ($past(writing && rs && !addr[2] && addr[1:0] == 1))
                    assert(ddra == $past(data_i));
                else assert(ddra == $past(ddra));
                if ($past(writing && rs && !addr[2] && addr[1:0] == 2))
                    assert(orb == $past(data_i));
                else assert(orb == $past(orb));
                if ($past(writing && rs && !addr[2] && addr[1:0] == 3))
                    assert(ddrb == $past(data_i));
                else assert(ddrb == $past(ddrb));
                if ($past(timer_write)) begin
                    assert(timer_count == $past(data_i));
                    assert(timer_running && !timer_fast && !timer_flag);
                    assert(divider == 0);
                    case ($past(addr[1:0]))
                        0: assert(reload_divider == 0);
                        1: assert(reload_divider == 7);
                        2: assert(reload_divider == 63);
                        3: assert(reload_divider == 1023);
                    endcase
                end else begin
                    assert(reload_divider == $past(reload_divider));
                    if ($past(timer_expire)) assert(timer_flag && timer_fast);
                    else if ($past(timer_read)) assert(!timer_flag);
                    else assert(timer_flag == $past(timer_flag));
                    if ($past(timer_read && timer_fast && !timer_expire)) begin
                        assert(timer_count == $past(timer_count));
                        assert(!timer_fast && divider == 0);
                    end else if ($past(timer_tick))
                        assert(timer_count == $past(timer_count) - 8'd1);
                    else assert(timer_count == $past(timer_count));
                    if (!$past(timer_read && timer_fast && !timer_expire)) begin
                        if ($past(timer_tick)) assert(divider == $past(reload_divider));
                        else if ($past(timer_running)) assert(divider == $past(divider) - 10'd1);
                        else assert(divider == $past(divider));
                    end
                end
                if ($past(timer_write || timer_read)) assert(timer_enable == $past(addr[3]));
                else assert(timer_enable == $past(timer_enable));
                if ($past(edge_write)) begin
                    assert(edge_enable == $past(addr[1]));
                    assert(edge_positive == $past(addr[0]));
                end else begin
                    assert(edge_enable == $past(edge_enable));
                    assert(edge_positive == $past(edge_positive));
                end
                if ($past(edge_event)) assert(edge_flag);
                else if ($past(flag_read)) assert(!edge_flag);
                else assert(edge_flag == $past(edge_flag));
            end
        end
        cover(f_memory_valid && rst_n && selected && rw && !rs && addr == f_address);
        cover(f_past_valid && rst_n && timer_flag && timer_enable && !irq_n);
        cover(f_past_valid && rst_n && timer_flag && !timer_enable);
        cover(f_past_valid && rst_n && edge_flag && edge_enable && !irq_n);
        cover(f_past_valid && rst_n && edge_flag && timer_flag);
    end
