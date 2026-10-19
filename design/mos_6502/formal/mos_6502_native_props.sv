    logic f_native_valid = 0;
    always_ff @(posedge clk) begin
        f_native_valid <= 1;
        if (!f_native_valid) assume(!rst_n);
        assert(fetch_o == (state == S_FETCH));
        assert(jammed_o == (state == S_KIL_HALT));
`ifdef MOS6507_FORMAL
        // These are asserted on the actual instantiated core, not assumed
        // by its environment: the 6507 adapter must provide the die ties.
        assert(irq_n && nmi_n && so_n);
        if (f_native_valid && rst_n && $past(rst_n)) begin
            assert(!irq_pending && !irq_sample && !nmi_pending && !nmi_polled);
        end
`endif
        if (bus_we) assert(rst_n && (state == S_MEMORY || state == S_RMW_OLD ||
            state == S_RMW_NEW || state == S_PUSH || state == S_JSR_PH ||
            state == S_JSR_PL || state == S_BRK_PH || state == S_BRK_PL || state == S_BRK_PS));
        if (state == S_KIL_HALT) assert(!fetch_o && !bus_we && bus_addr == 16'hffff);
        if (state == S_RST_0 || state == S_RST_1 || state == S_RST_2 ||
            state == S_RST_3 || state == S_RST_4 || state == S_RST_L || state == S_RST_H)
            assert(!bus_we);
        if (f_native_valid) begin
            if (!$past(rst_n)) begin
                assert(state == S_RST_0 && p[FI] && p[5] && !p[4]);
                assert(a == $past(a) && x == $past(x) && y == $past(y) && s == $past(s));
            end else begin
                if (!$past(rdy_i || bus_we)) begin
                    assert(state == $past(state) && pc == $past(pc));
                    assert(a == $past(a) && x == $past(x) && y == $past(y) && s == $past(s));
                    if (rst_n) begin
                        if ($past(state == S_INDEXED && page_cross)) assert(bus_addr == $past(target_q));
                        else assert(bus_addr == $past(bus_addr));
                    end
                end
                if ($past(state == S_FETCH && rdy_i && !nmi_polled && !irq_pending))
                    assert(pc == $past(pc) + 16'd1);
                if ($past(state == S_MEMORY && is_rmw && rdy_i)) begin
                    assert(state == S_RMW_OLD && data_q == $past(bus_data_i));
                    if (rst_n) assert(bus_we && bus_addr == $past(bus_addr));
                end
                if ($past(state == S_RMW_OLD)) begin
                    assert(state == S_RMW_NEW);
                    if (rst_n) assert(bus_we && bus_addr == $past(bus_addr));
                end
                if ($past(state == S_KIL_HALT)) assert(state == S_KIL_HALT);
                if ($past(so_prev && !so_n)) assert(p[FV]);
                if ($past((state == S_RST_2 || state == S_RST_3 || state == S_RST_4) && rdy_i))
                    assert(s == $past(s) - 8'd1);
                if ($past(state == S_RST_H && rdy_i)) begin
                    assert(pc == {$past(bus_data_i), $past(data_q)});
                    assert(state == S_FETCH);
                end
            end
        end
        cover(f_native_valid && rst_n && state == S_FETCH);
        cover(f_native_valid && rst_n && state == S_RMW_NEW);
        cover(f_native_valid && rst_n && state == S_INDEXED && page_cross);
        cover(f_native_valid && rst_n && state == S_VEC_L && !int_nmi_q);
`ifndef MOS6507_FORMAL
        cover(f_native_valid && rst_n && state == S_VEC_L && int_nmi_q);
`endif
        cover(f_native_valid && rst_n && state == S_FETCH && !rdy_i);
        cover(f_native_valid && rst_n && state == S_KIL_HALT);
        cover(f_native_valid && rst_n && state == S_RST_H && rdy_i);
        cover(f_native_valid && rst_n && execute_alu && p[FD] && (op == O_ADC || op == O_RRA));
    end
