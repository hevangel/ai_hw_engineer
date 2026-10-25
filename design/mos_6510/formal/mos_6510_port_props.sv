    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert(port_oe == ddr_q[5:0]);
        assert(port_o == data_q[5:0]);
        if (!address_i) assert(data_o == ddr_q);
        if (address_i) assert(data_o[5:0] ==
            ((data_q[5:0] & ddr_q[5:0]) | (port_i & ~ddr_q[5:0])));
        if (f_valid) begin
            if (!$past(rst_n)) begin
                assert(ddr_q == 0 && data_q == 0 && charge_q == 0);
                assert(remaining_q[0] == 0 && remaining_q[1] == 0);
            end else begin
                if ($past(write_i && !address_i)) assert(ddr_q == $past(data_i));
                else assert(ddr_q == $past(ddr_q));
                if ($past(write_i && address_i)) assert(data_q == $past(data_i));
                else assert(data_q == $past(data_q));
            end
            for (int b = 0; b < 2; b++) begin
                assert(remaining_q[b] <= CW'(PORT_FALLOFF_CYCLES));
                if (rst_n && address_i && !ddr_q[b+6] && remaining_q[b] == 0)
                    assert(!data_o[b+6]);
            end
        end
        cover(f_valid && rst_n && ddr_q == 8'h2f && data_q == 8'h37);
        cover(f_valid && rst_n && ddr_q == 0 && charge_q[0] && remaining_q[0] != 0);
        cover(f_valid && rst_n && ddr_q == 0 && data_q[6] && remaining_q[0] == 0);
    end
