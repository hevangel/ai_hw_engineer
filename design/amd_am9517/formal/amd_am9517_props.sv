// Included inside the RTL under FORMAL; symbolic inputs remain top-level ports.
`ifdef FORMAL
    logic past_valid = 1'b0;
    (* anyconst *) logic [1:0] watched_channel;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) assume(!rst_n);
        if (past_valid && $past(rst_n && hrq && hlda) && hrq) assume(hlda);
        if (past_valid && rst_n) begin
            assert(state_q <= CASCADE);
            assert($onehot0(ack_active));
            if (transfer_valid) assert(hrq && hlda && aen && addr_oe);
            if (!memr_n || !memw_n || !dma_ior_n || !dma_iow_n)
                assert(hrq && hlda && aen);
            assert(memr_n || memw_n);
            assert(dma_ior_n || dma_iow_n);
            if (state_q == CASCADE) begin
                assert(!aen && !addr_oe && !transfer_valid);
                assert(memr_n && memw_n && dma_ior_n && dma_iow_n);
            end
            if (verify_transfer) assert(memr_n && memw_n && dma_ior_n && dma_iow_n);
            if (memory_q) assert(ack_active == 4'b0000);
            if (!hlda) assert(!aen && !transfer_valid && ack_active == 0);
            if ($past(rst_n) && !$past(master_clear)) begin
                if ($past(bus_active && !transfer_valid)) begin
                    assert(address_q[watched_channel] == $past(address_q[watched_channel]));
                    assert(count_q[watched_channel] == $past(count_q[watched_channel]));
                end
                if ($past(transfer_valid && !memory_q &&
                          bus_channel == watched_channel)) begin
                    if ($past(finish && mode_q[watched_channel][2])) begin
                        assert(address_q[watched_channel] == $past(base_address_q[watched_channel]));
                        assert(count_q[watched_channel] == $past(base_count_q[watched_channel]));
                    end else begin
                        assert(address_q[watched_channel] == $past(next_address));
                        assert(count_q[watched_channel] == $past(count_q[watched_channel]) - 16'd1);
                    end
                    if ($past(finish)) begin
                        assert(status_q[watched_channel]);
                        assert(!software_q[watched_channel]);
                        if (!$past(mode_q[watched_channel][2])) assert(mask_q[watched_channel]);
                    end
                end
                if ($past(state_q == RELEASE && hlda)) assert(state_q == RELEASE);
                if ($past(state_q == SW && !ready && !verify_transfer)) assert(state_q == SW);
                if ($past(transfer_valid && memory_q && !destination_q)) begin
                    assert(temporary_q == $past(data_i));
                    if ($past(finish && mode_q[0][2])) begin
                        assert(address_q[0] == $past(base_address_q[0]));
                        assert(count_q[0] == $past(base_count_q[0]));
                    end else begin
                        assert(count_q[0] == $past(count_q[0]) - 16'd1);
                        if ($past(command_q[1])) assert(address_q[0] == $past(address_q[0]));
                        else assert(address_q[0] == $past(next_address));
                    end
                    assert(state_q == S1 && destination_q);
                end
                if ($past(transfer_valid && memory_q && destination_q)) begin
                    if ($past(finish && mode_q[1][2])) begin
                        assert(address_q[1] == $past(base_address_q[1]));
                        assert(count_q[1] == $past(base_count_q[1]));
                    end else begin
                        assert(address_q[1] == $past(next_address));
                        assert(count_q[1] == $past(count_q[1]) - 16'd1);
                    end
                    if ($past(finish)) begin
                        assert(status_q[1] && !software_q[0] && !software_q[1]);
                        if (!$past(mode_q[1][2])) assert(mask_q[1]);
                    end
                end
                if ($past(transfer_valid)) begin
                    assert(base_address_q[watched_channel] == $past(base_address_q[watched_channel]));
                    assert(base_count_q[watched_channel] == $past(base_count_q[watched_channel]));
                end
                if ($past((cpu_read || cpu_write) && !reg_addr[3]))
                    assert(byte_high_q == !$past(byte_high_q));
            end
            if (cpu_read && reg_addr == 8) assert(data_o[7:4] == hardware_request);
            if (command_q[2]) assert(!hrq);
            if (state_q == GRANT && !hlda) assert(cpu_select == !cs_n);
            if (past_valid && $past(rst_n) && !$past(master_clear)) begin
                if ($past(state_q == GRANT && hlda && found)) begin
                    assert(channel_q == $past(selected));
                    assert(memory_q == $past(command_q[0] && selected == 0));
                end
                if ($past(cpu_write && reg_addr == 14)) assert(mask_q == $past(mask_q));
            end
`ifdef FORMAL_COVER
            cover(transfer_valid && bus_channel == 0 && !memory_q);
            cover(transfer_valid && bus_channel == 1 && !memory_q);
            cover(transfer_valid && bus_channel == 2);
            cover(transfer_valid && bus_channel == 3);
            cover(state_q == SW);
            cover(transfer_valid && verify_transfer && !ready);
            cover(state_q == CASCADE && hlda);
            cover(transfer_valid && !eop_out_n);
            cover(transfer_valid && finish && mode_q[bus_channel][2]);
            cover(transfer_valid && memory_q && !destination_q);
            cover(transfer_valid && memory_q && destination_q);
`endif
        end
    end
`endif
