`timescale 1ns/1ps
module tb_uvm;
    import uvm_pkg::*;
    import intel_8273_uvm_pkg::*;
    logic clk=0;
    always #5 clk=~clk;
    intel_8273_if v(clk);
    `include "dut.svh"
    initial begin
        uvm_config_db #(virtual intel_8273_if)::set(null,"*","vif",v);
        run_test("intel_8273_test");
    end
    initial begin #10000000; $fatal(1,"8273 UVM timeout"); end
endmodule
