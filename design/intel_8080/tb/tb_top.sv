`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import intel_8080_uvm_pkg::*;
  intel_8080_if vif();
  intel_8080 dut (.clk(vif.clk), .rst_n(vif.rst_n), .bus_ready_i(vif.ready), .bus_rdata_i(vif.rdata),
      .int_i(vif.int_req), .hold_i(vif.hold_req), .bus_req_o(vif.req), .bus_write_o(vif.write_en),
      .bus_io_o(vif.io), .bus_intack_o(vif.intack), .bus_addr_o(vif.addr), .bus_wdata_o(vif.wdata),
      .bus_status_o(vif.status), .inte_o(vif.inte), .hlda_o(vif.hlda), .halted_o(vif.halted),
      .retire_o(vif.retire), .fault_o(vif.fault), .pc_o(vif.pc), .sp_o(vif.sp), .regs_o(vif.regs), .flags_o(vif.flags));
  initial begin
    uvm_config_db#(virtual intel_8080_if)::set(null,"uvm_test_top.driver","vif",vif);
    run_test("intel_8080_control_test");
  end
  initial begin forever #5 vif.clk=~vif.clk; end
  initial begin #1000000; $fatal(1,"UVM control watchdog expired"); end
endmodule
