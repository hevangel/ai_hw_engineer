`timescale 1ns/1ps
module tb_ttl_74x8161;
    logic clk, clr_n, load_n, en_p, en_t;
    logic [7:0] d, q;
    logic rco;
    ttl_74x8161 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 1; load_n = 1; en_p = 1; en_t = 1; d = 0;
        clr_n = 0; tick; clr_n = 1;
        if (q !== 8'd0) errors++;
        load_n = 0; d = 8'hFE; tick; load_n = 1;
        if (q !== 8'hFE) errors++;
        tick;
        if (q !== 8'hFF || rco !== 1) errors++;
        tick;
        if (q !== 8'h00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8161: %0d errors", errors);
        $display("PASS: tb_ttl_74x8161");
        $finish;
    end
endmodule
