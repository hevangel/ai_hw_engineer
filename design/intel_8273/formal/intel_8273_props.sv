    logic formal_past_valid=0;
    always_ff @(posedge clk) begin
        formal_past_valid<=1;
        if (core_rst_n) begin
            assert(needed_q<=4);
            assert(index_q<=3);
            assert(tx_count_q<=2);
            assert(rx_count_q<=5);
            assert(rx_count_q==0 || rx_head_q<=4);
            assert(mode_q[7:6]==0 && serial_q[7:3]==0 && port_q[7:6]==0);
            assert(!data_oe || (read_bus && ((!rx_dack_n && tx_dack_n) ||
                (!cs_n && tx_dack_n && rx_dack_n))));
            assert(!tx_drq || (tx_need && !non_dma_q && tx_dack_n));
            assert(!rx_drq || (rx_full_q && !non_dma_q && rx_dack_n));
            if (formal_past_valid && $past(core_rst_n)) begin
                if ($past(rx_full_q && !rx_get && !rx_valid &&
                    !(cpu_write && addr==1 && index_q+1'b1==needed_q &&
                      (command_q==8'hc0 || command_q==8'hc1 || command_q==8'hc2))))
                    assert(rx_full_q && rx_buffer_q==$past(rx_buffer_q));
                if ($past(immediate_full_q && !(cpu_read && addr==1)))
                    assert(immediate_full_q);
            end
        end
    end
`ifdef FORMAL_COVER
    always_ff @(posedge clk) begin
`ifdef COVER_TX
        cover(core_rst_n && formal_past_valid && tx_count_q!=0 && tx_results_q[tx_head_q]==8'h0d);
`elsif COVER_RX
        cover(core_rst_n && formal_past_valid && rx_count_q!=0 && rx_results_q[0]==8'he0);
`else
        cover(core_rst_n && formal_past_valid && rx_count_q!=0 && rx_results_q[0]==8'hea);
`endif
    end
`endif
