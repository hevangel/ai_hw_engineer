`timescale 1ns/1ps
module tb_ttl_74x1762;
    logic ras_in, cas_in;
    logic [9:0] row_addr, col_addr, dram_addr;
    logic ras_n, cas_n;
    ttl_74x1762 dut(.*);
    int errors;
    initial begin
        errors = 0;
        row_addr = 10'h3FF; col_addr = 10'h000;
        ras_in = 1; cas_in = 0; #1;
        if (dram_addr !== 10'h3FF) errors++;
        cas_in = 1; #1;
        if (dram_addr !== 10'h000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1762: %0d errors", errors);
        $display("PASS: tb_ttl_74x1762");
        $finish;
    end
endmodule
