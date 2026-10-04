intel_8273 dut (
    .clk(clk),.rst_n(v.rst_n),.cs_n(v.cs_n),.rd_n(v.rd_n),.wr_n(v.wr_n),
    .addr(v.addr),.data_i(v.data_i),.data_o(v.data_o),.data_oe(v.data_oe),
    .tx_dack_n(v.tx_dack_n),.rx_dack_n(v.rx_dack_n),.tx_drq(v.tx_drq),
    .rx_drq(v.rx_drq),.tx_int(v.tx_int),.rx_int(v.rx_int),.tx_tick(v.tx_tick),
    .rx_tick(v.rx_tick),.tx_sample_tick(v.tx_sample_tick),.clk32_tick(v.clk32_tick),
    .rxd(v.rxd),.txd(v.txd),.dpll_tick(v.dpll_tick),.cts_n(v.cts_n),.cd_n(v.cd_n),
    .port_a(v.port_a),.port_b(v.port_b),.rts_n(v.rts_n),.flag_det_n(v.flag_det_n)
);
