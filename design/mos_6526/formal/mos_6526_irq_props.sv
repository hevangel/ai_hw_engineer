    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert(data_o[6:5] == 0 && cycle_data_o[6:5] == 0);
        if (read_i || !rst_n) assert(irq_n && cycle_irq_n);
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(pending_q == 0 && mask_q == 0 && !scheduled_q && !d7_q && !asserted_q);
            end else begin
                if (!$past(read_i)) assert(data_o == $past(cycle_data_o));
                if (!$past(read_i) && rst_n && !read_i) assert(irq_n == $past(cycle_irq_n));
                assert((pending_q & $past(source_i)) == $past(source_i));
                if ($past(read_i)) begin
                    assert(pending_q == $past(source_i));
                    assert(!asserted_q);
                end
                if (!$past(write_i)) assert(mask_q == $past(mask_q));
                if ($past(write_i && data_i[7])) assert(mask_q == ($past(mask_q) | $past(data_i[4:0])));
                if ($past(write_i && !data_i[7])) assert(mask_q == ($past(mask_q) & ~$past(data_i[4:0])));
                if ($past(scheduled_q)) assert(d7_q);
                if ($past(acknowledge_q && !scheduled_q)) assert(!d7_q);
                if ($past(asserted_q && !read_i)) assert(asserted_q);
            end
        end
        cover(f_valid && rst_n && |pending_q && mask_q == 0 && irq_n);
        cover(f_valid && rst_n && !irq_n);
        cover(f_valid && rst_n && read_i && d7_q);
        cover(f_valid && rst_n && acknowledge_q && scheduled_q);
        cover(f_valid && rst_n && asserted_q && mask_q == 0);
    end
