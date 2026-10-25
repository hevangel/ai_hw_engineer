`timescale 1ns/1ps
module tb_ttl_74x362;
    logic clk, clr_n;
    logic [3:0] phi;
    ttl_74x362 dut(.clk(clk), .clr_n(clr_n), .phi(phi));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; #1;
        if (phi !== 4'b0001) errors++;
        clr_n=1;
        tick; if (phi !== 4'b0010) errors++;
        tick; if (phi !== 4'b0100) errors++;
        tick; if (phi !== 4'b1000) errors++;
        tick; if (phi !== 4'b0001) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x362: %0d errors", errors);
        $display("PASS: tb_ttl_74x362");
        $finish;
    end
endmodule
