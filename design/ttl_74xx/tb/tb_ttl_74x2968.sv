`timescale 1ns/1ps
module tb_ttl_74x2968;
    logic ras_in, cas_in;
    logic [8:0] row_addr, col_addr, dram_addr;
    logic ras_n, cas_n;
    ttl_74x2968 dut(.*);
    int errors;
    initial begin
        errors = 0;
        row_addr = 9'h1FF; col_addr = 9'h000;
        ras_in = 1; cas_in = 0; #1;
        if (dram_addr !== 9'h1FF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2968: %0d errors", errors);
        $display("PASS: tb_ttl_74x2968");
        $finish;
    end
endmodule
