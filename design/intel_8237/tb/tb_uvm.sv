`timescale 1ns/1ps
module tb_uvm;
    import uvm_pkg::*;
    import intel_8237_uvm_pkg::*;
    logic clk = 0;
    always #5 clk = ~clk;
    intel_8237_if bus(clk);
    intel_8237 dut (
        .clk(clk), .rst_n(bus.rst_n), .cs_n(bus.cs_n), .ior_n(bus.ior_n),
        .iow_n(bus.iow_n), .reg_addr(bus.reg_addr), .data_i(bus.data_i),
        .data_o(bus.data_o), .data_oe(bus.data_oe), .dreq(bus.dreq), .dack(bus.dack),
        .hrq(bus.hrq), .hlda(bus.hlda), .ready(bus.ready), .eop_n(bus.eop_n),
        .eop_out_n(bus.eop_out_n), .dma_addr(bus.dma_addr), .addr_oe(bus.addr_oe),
        .adstb(bus.adstb), .aen(bus.aen), .memr_n(bus.memr_n), .memw_n(bus.memw_n),
        .dma_ior_n(bus.dma_ior_n), .dma_iow_n(bus.dma_iow_n),
        .transfer_valid(bus.transfer_valid), .transfer_channel(bus.transfer_channel)
    );
    // Stateless external memory/peripheral model; no access to DUT internals.
    always_comb begin
        bus.data_i = bus.cpu_data;
        if (bus.aen && !bus.memr_n)
            bus.data_i = 8'(bus.dma_addr ^ (bus.dma_addr >> 8) ^ 16'ha5);
        else if (bus.aen && !bus.dma_ior_n) bus.data_i = 8'(32+int'(bus.transfer_channel));
    end
    always @(negedge clk) bus.hlda = bus.rst_n && bus.hrq;
    initial begin
        uvm_config_db#(virtual intel_8237_if)::set(null, "*", "vif", bus);
        run_test();
    end
    initial begin #200000; $fatal(1, "8237A UVM timeout"); end
endmodule
