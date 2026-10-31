`timescale 1ns/1ps
module tb_ttl_74x577;
    logic clk, oe_n, clr_n, hiz;
    logic [7:0] d, q_n;
    ttl_74x577 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; clr_n=1; d=8'h0F; tick;
        if (q_n !== 8'hF0) errors++;
        clr_n=0; tick;
        if (q_n !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x577: %0d errors", errors);
        $display("PASS: tb_ttl_74x577");
        $finish;
    end
endmodule
