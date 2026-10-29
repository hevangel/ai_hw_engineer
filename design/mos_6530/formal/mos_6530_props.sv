    logic f_valid = 0;
    (* anyconst *) logic [5:0] f_address;
    logic [7:0] f_memory;
    logic f_memory_valid = 0;
    always_ff @(negedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert($onehot0({rom_cs, ram_cs, io_cs}));
        if (rom_cs) assert(data_o == ROM_CONTENTS[{addr, 3'b0} +: 8]);
        assert(data_oe == (clk && rst_n && rw && (rom_cs || ram_cs || io_cs)));
        assert((pb_oe & SELECT_PINS) == 0);
        if (rst_n && ram_cs && !rw && addr[5:0] == f_address) begin
            f_memory <= data_i;
            f_memory_valid <= 1;
        end
        if (f_memory_valid) assert(ram[f_address] == f_memory);
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(ora == 0 && orb == 0 && ddra == 0 && ddrb == 0);
                assert(!timer_running && !timer_flag && !timer_enable);
            end else begin
                if ($past(io_cs && !rw && !addr[2] && addr[1:0] == 0))
                    assert(ora == $past(data_i));
                else assert(ora == $past(ora));
                if ($past(io_cs && !rw && !addr[2] && addr[1:0] == 1))
                    assert(ddra == $past(data_i));
                else assert(ddra == $past(ddra));
                if ($past(io_cs && !rw && !addr[2] && addr[1:0] == 2))
                    assert(orb == $past(data_i));
                else assert(orb == $past(orb));
                if ($past(io_cs && !rw && !addr[2] && addr[1:0] == 3))
                    assert(ddrb == $past(data_i));
                else assert(ddrb == $past(ddrb));
                if ($past(timer_write)) begin
                    assert(timer_count == $past(data_i));
                    assert(timer_running && !timer_fast && !timer_flag && divider == 0);
                    assert(timer_enable == $past(addr[3]));
                end else begin
                    if ($past(timer_expire)) assert(timer_flag && timer_fast);
                    else if ($past(timer_read)) assert(!timer_flag);
                    else assert(timer_flag == $past(timer_flag));
                    if ($past(timer_read && timer_fast && !timer_expire)) begin
                        assert(timer_count == $past(timer_count));
                        assert(!timer_fast && divider == 0 && !timer_enable);
                    end else if ($past(timer_tick))
                        assert(timer_count == $past(timer_count) - 8'd1);
                    else assert(timer_count == $past(timer_count));
                    if ($past(timer_read)) assert(timer_enable == $past(!timer_fast && addr[3]));
                    else assert(timer_enable == $past(timer_enable));
                end
            end
        end
        cover(f_valid && rst_n && rom_cs && rw);
        cover(f_memory_valid && rst_n && ram_cs && rw && addr[5:0] == f_address);
        cover(f_valid && rst_n && timer_flag && timer_enable && !ddrb[7] && !irq_n);
        cover(f_valid && rst_n && timer_flag && !timer_enable);
        cover(f_valid && rst_n && timer_flag && timer_enable && ddrb[7] && orb[7] && irq_n);
        cover(f_valid && rst_n && timer_fast && timer_read && addr[3]);
    end
