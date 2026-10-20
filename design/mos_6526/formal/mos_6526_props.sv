    logic f_chip_valid = 0;
    always_ff @(negedge clk) begin
        f_chip_valid <= 1;
        if (!f_chip_valid) assume(!rst_n);
        assert(data_oe == (rst_n && clk && selected && rw));
        assert(cra_value[4] == 0 && crb_value[4] == 0);
        if (previous_ta_event_q) assert(!serial_baud);
        assert(pa_o == pra_q);
        assert(pa_oe == (rst_n ? ddra_q : 8'b0));
        assert(pb_oe == (rst_n ? ddrb_q | {crb_low_q[0],cra_low_q[0],6'b0} : 8'b0));
        if (addr==0) assert(data_o == pa_sample_q);
        if (addr==1) begin
            assert(data_o[5:0] == pb_sample_q[5:0]);
            if (!cra_low_q[0]) assert(data_o[6] == pb_sample_q[6]);
            if (!crb_low_q[0]) assert(data_o[7] == pb_sample_q[7]);
        end
        if (f_chip_valid) begin
            if (!$past(rst_n)) begin
                assert(pra_q==0 && prb_q==0 && ddra_q==0 && ddrb_q==0);
                assert(cra_high_q==0 && cra_low_q==0 && crb_high_q==0 && crb_low_q==0);
                assert(pc_q);
            end else begin
                assert(pc_q == !$past(selected && addr==1));
                assert(pra_q == ($past(wr && addr==0) ? $past(data_i) : $past(pra_q)));
                assert(prb_q == ($past(wr && addr==1) ? $past(data_i) : $past(prb_q)));
                assert(ddra_q == ($past(wr && addr==2) ? $past(data_i) : $past(ddra_q)));
                assert(ddrb_q == ($past(wr && addr==3) ? $past(data_i) : $past(ddrb_q)));
                assert(cra_high_q == ($past(wr && addr==14) ? $past(data_i[7:5]) : $past(cra_high_q)));
                assert(crb_high_q == ($past(wr && addr==15) ? $past(data_i[7:5]) : $past(crb_high_q)));
                assert(previous_cnt_q == $past(cnt_sample_q));
                assert(previous_flag_q == $past(flag_sample_q));
                assert(previous_tod_q == $past(tod_sample_q));
                assert(previous_ta_event_q == $past(ta_event));
            end
        end
        cover(f_chip_valid && rst_n && pa_oe==8'hff && data_o!=pa_o && addr==0);
        cover(f_chip_valid && rst_n && !pc_n);
        cover(f_chip_valid && rst_n && ta_underflow && pb_oe[6]);
        cover(f_chip_valid && rst_n && tb_underflow && crb_high_q[1]);
        cover(f_chip_valid && rst_n && !irq_n);
        cover(f_chip_valid && rst_n && serial_event);
        cover(f_chip_valid && rst_n && tod_event);
    end
