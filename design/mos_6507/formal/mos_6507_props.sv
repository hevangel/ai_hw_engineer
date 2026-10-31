    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        assert(bus_addr == debug_bus_addr_o[12:0]);
        cover(f_valid && rst_n && debug_bus_addr_o == 16'hfffc && bus_addr == 13'h1ffc);
        cover(f_valid && rst_n && fetch_o && pc_o[15:13] != 0);
        cover(f_valid && rst_n && bus_we && debug_bus_addr_o[15:13] != 0);
        cover(f_valid && rst_n && debug_bus_addr_o == 16'hfffe && bus_addr == 13'h1ffe);
    end
