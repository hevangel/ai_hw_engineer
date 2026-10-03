module tb_uvm;
    import uvm_pkg::*;
    import intel_8275_uvm_pkg::*;
    logic clk=0;
    initial forever #5 clk=~clk;
    intel_8275_if bus(clk);
    intel_8275 dut(.clk(clk),.rst_n(bus.rst_n),.cclk_en(bus.cclk_en),
        .cs_n(bus.cs_n),.rd_n(bus.rd_n),.wr_n(bus.wr_n),.a0(bus.a0),
        .db_in(bus.db_in),.db_out(bus.db_out),.db_oe(bus.db_oe),
        .dack_n(bus.dack_n),.lpen(bus.lpen),.drq(bus.drq),.irq(bus.irq),
        .cc(bus.cc),.lc(bus.lc),.la(bus.la),.gpa(bus.gpa),
        .hrtc(bus.hrtc),.vrtc(bus.vrtc),.vsp(bus.vsp),.lten(bus.lten),
        .rvv(bus.rvv),.hlgt(bus.hlgt));
    initial begin
        uvm_config_db#(virtual intel_8275_if)::set(null,"*","vif",bus);
        run_test();
    end
    initial begin #1000000; $fatal(1,"8275 UVM watchdog"); end
endmodule
