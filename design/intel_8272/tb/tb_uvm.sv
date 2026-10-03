`timescale 1ns/1ps
module tb_uvm;
    import uvm_pkg::*;
    import intel_8272_uvm_pkg::*;
    logic clk=0;
    initial forever #5 clk=~clk;
    intel_8272_if bus(clk);
    `include "dut.svh"
    initial begin
        uvm_config_db #(virtual intel_8272_if)::set(null,"*","vif",bus);
        run_test("intel_8272_test");
    end
endmodule
