`timescale 1ns/1ps
module tb_ttl_74x612;
    logic clk, wr_n, oe_n, hiz;
    logic [3:0] virt;
    logic [11:0] d, phys;
    ttl_74x612 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; oe_n=0;
        virt=4'd2; d=12'h456; wr_n=0; tick;
        wr_n=1; #1; if (phys !== 12'h456) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x612: %0d errors", errors);
        $display("PASS: tb_ttl_74x612");
        $finish;
    end
endmodule
