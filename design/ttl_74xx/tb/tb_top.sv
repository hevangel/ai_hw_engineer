`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import alu_74181_uvm_pkg::*;

    logic clk;
    alu_74181_if vif (clk);

    alu_74181 dut (
        .a      (vif.a),
        .b      (vif.b),
        .s      (vif.s),
        .m      (vif.m),
        .cn     (vif.cn),
        .f      (vif.f),
        .cn4    (vif.cn4),
        .a_eq_b (vif.a_eq_b),
        .p_bar  (vif.p_bar),
        .g_bar  (vif.g_bar)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        uvm_config_db#(virtual alu_74181_if)::set(null, "*", "vif", vif);
        run_test();
    end

endmodule
