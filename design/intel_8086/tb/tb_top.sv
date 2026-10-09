`timescale 1ns / 1ps
module tb_top;
  import uvm_pkg::*;
  import intel_8086_uvm_pkg::*;
  intel_8086_if vif ();
  intel_8086 dut (
      .clk(vif.clk),
      .rst_n(vif.rst_n),
      .bus_ready_i(vif.ready),
      .bus_rdata_i(vif.rdata),
      .bus_req_o(vif.req),
      .bus_write_o(vif.write_en),
      .bus_fetch_o(vif.fetch),
      .bus_addr_o(vif.addr),
      .bus_be_o(vif.be),
      .bus_wdata_o(vif.wdata),
      .halted_o(vif.halted),
      .fault_o(vif.fault),
      .retire_o(vif.retire),
      .regs_o(vif.regs),
      .segs_o(vif.segs),
      .ip_o(vif.ip),
      .flags_o(vif.flags)
  );
  initial begin
    uvm_config_db#(virtual intel_8086_if)::set(null, "uvm_test_top.driver", "vif", vif);
    run_test("intel_8086_control_test");
  end
  initial begin
    forever #5 vif.clk = ~vif.clk;
  end
  initial begin
    #1000000;
    $fatal(1, "8086 UVM watchdog");
  end
endmodule
