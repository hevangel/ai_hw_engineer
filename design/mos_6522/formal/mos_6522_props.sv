    logic f_valid = 0;
    always_ff @(negedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert(data_oe == (clk && rst_n && cs1 && !cs2_n && rw));
        assert(irq_n == !(rst_n && |(ifr & ier)));
        assert(pa_oe == ddra && pa_o == ora);
        assert(pb_oe == (ddrb | {acr[7], 7'b0}));
        if (addr == 4'hd) assert(data_o == {|(ifr & ier), ifr});
        if (addr == 4'he) assert(data_o == {1'b1, ier});
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(ora == 0 && orb == 0 && ddra == 0 && ddrb == 0);
                assert(ifr == 0 && ier == 0 && acr == 0 && pcr == 0);
                assert(!t1_running && !t2_running && !sr_running);
            end else begin
                assert(ifr == (($past(ifr) & ~$past(irq_clear)) | $past(irq_set)));
                if ($past(wr && addr == 4'he)) begin
                    if ($past(data_i[7])) assert(ier == ($past(ier) | $past(data_i[6:0])));
                    else assert(ier == ($past(ier) & ~$past(data_i[6:0])));
                end else assert(ier == $past(ier));
                if ($past(wr && (addr == 1 || addr == 15))) assert(ora == $past(data_i));
                else assert(ora == $past(ora));
                if ($past(wr && addr == 0)) assert(orb == $past(data_i));
                else assert(orb == $past(orb));
                if ($past(wr && addr == 2)) assert(ddrb == $past(data_i));
                else assert(ddrb == $past(ddrb));
                if ($past(wr && addr == 3)) assert(ddra == $past(data_i));
                else assert(ddra == $past(ddra));
                if ($past(wr && addr == 11)) assert(acr == $past(data_i));
                else assert(acr == $past(acr));
                if ($past(wr && addr == 12)) assert(pcr == $past(data_i));
                else assert(pcr == $past(pcr));
                if ($past(wr && addr == 5)) begin
                    assert(t1_count == {$past(data_i), $past(t1_latch[7:0])});
                    assert(t1_armed && t1_wait && t1_running && !t1_reload);
                end else if ($past(t1_running && !t1_wait)) begin
                    if ($past(t1_reload)) assert(t1_count == $past(t1_latch));
                    else assert(t1_count == $past(t1_count) - 16'd1);
                end else assert(t1_count == $past(t1_count));
                if ($past(wr && addr == 9)) begin
                    assert(t2_count == {$past(data_i), $past(t2_latch)});
                    assert(t2_armed && t2_running && !t2_reload);
                end else if ($past(t2_step && !t2_wait)) begin
                    if ($past(sr_t2 && t2_reload))
                        assert(t2_count == {$past(t2_count[15:8]), $past(t2_latch)});
                    else assert(t2_count == $past(t2_count) - 16'd1);
                end else assert(t2_count == $past(t2_count));
                if ($past(wr && addr == 10)) assert(sr == $past(data_i));
                else if ($past(sr_input || sr_output))
                    assert(sr == {$past(sr[6:0]), $past(sr_mode[2] ? sr[7] : cb2_i)});
                else assert(sr == $past(sr));
            end
        end
        for (integer bitno = 0; bitno < 7; bitno = bitno + 1)
            cover(f_valid && rst_n && ifr[bitno] && ier[bitno] && !irq_n);
        cover(f_valid && rst_n && ca2_oe && !ca2_o && ca2_mode == 4);
        cover(f_valid && rst_n && cb2_oe && !cb2_o && sr_mode == 0 && cb2_mode == 5);
        cover(f_valid && rst_n && ifr[2] && sr_mode == 6 && !sr_running);
    end
