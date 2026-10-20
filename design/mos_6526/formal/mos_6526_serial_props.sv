    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert(cnt_oe == (output_mode_i && !cnt_o));
        assert(sp_oe == (output_mode_i && !sp_o));
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(data_o == 0 && cnt_o && sp_o && !active_o && !pending_o);
            end else begin
                if ($past(write_i)) assert(data_o == $past(data_i));
                if ($past(write_i && output_mode_i)) assert(active_o || pending_o);
                if ($past(write_i && output_mode_i && previous_mode_q == output_mode_i &&
                          ((active_q && !shifter_free_q) || (!active_q && pending_q))))
                    assert(pending_o);
                if ($past(write_i && output_mode_i && previous_mode_q == output_mode_i &&
                          active_q && !shifter_free_q && !baud_pulse_i))
                    assert(shift_q == $past(shift_q));
                if ($past(write_i && output_mode_i && previous_mode_q == output_mode_i &&
                          ((!active_q && !pending_q) || (active_q && shifter_free_q)))) begin
                    assert(active_o && !pending_o && !shifter_free_q && cnt_o && bits_q == 0);
                    assert(shift_q == $past(data_i));
                end
                if ($past(previous_mode_q != output_mode_i)) begin
                    assert(tx_irq_q == 0);
                    assert(cnt_o && sp_o && !active_o && bits_q == 0);
                    if (!$past(write_i && output_mode_i)) assert(!pending_o);
                end
                if ($past(!output_mode_i && previous_mode_q == output_mode_i && cnt_rise_i && bits_q == 7 && !write_i))
                    assert(data_o == {$past(shift_q[6:0]),$past(sp_i)});
                if ($past(output_mode_i && previous_mode_q == output_mode_i && active_q && !cnt_q && baud_pulse_i))
                    assert(sp_o == $past(sp_o) && cnt_o);
            end
        end
        cover(f_valid && rst_n && irq_event_o && !output_mode_i);
        cover(f_valid && rst_n && irq_event_o && output_mode_i);
        cover(f_valid && rst_n && active_o && pending_o);
        cover(f_valid && rst_n && irq_event_o && output_mode_i && pending_o);
        cover(f_valid && rst_n && irq_event_o && !output_mode_i && write_i);
        cover(f_valid && rst_n && irq_event_o && output_mode_i && !cnt_o && !baud_pulse_i);
        cover(f_valid && rst_n && output_mode_i && active_o && pending_o && cnt_o && bits_q == 0 && !baud_pulse_i);
        cover(f_valid && rst_n && output_mode_i && active_o && shifter_free_q && !cnt_o && write_i);
    end
