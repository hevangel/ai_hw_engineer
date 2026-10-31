    always_ff @(posedge clk) begin
        assert(bus_addr_oe == aec_i && bus_rw_oe == aec_i);
        assert(bus_data_oe == (aec_i && bus_we && bus_addr > 1));
        if (internal_port) assert(core_data_i == port_data);
        else assert(core_data_i == bus_data_i);
        cover(rst_n && !aec_i && !rdy_i && fetch_o);
        cover(rst_n && bus_we && bus_addr == 1 && !bus_data_oe);
        cover(rst_n && bus_we && bus_addr > 1 && bus_data_oe);
    end
