`timescale 1ns/1ps
module tb_ttl_74x601;
    logic clk, reset_n, refresh_req, burst, ras_n, refresh_done;
    logic [7:0] row_addr;
    ttl_74x601 #(.ROW_BITS(8)) dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; refresh_req=0; burst=0;
        reset_n=1; #1; reset_n=0; #1; reset_n=1;
        refresh_req=1; tick;
        if (ras_n !== 0) errors++;
        refresh_req=0; tick;
        if (!refresh_done) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x601: %0d errors", errors);
        $display("PASS: tb_ttl_74x601");
        $finish;
    end
endmodule
