`timescale 1ns/1ps
module tb_ttl_74x608;
    logic clk, reset_n, mem_req, ras_n, cas_n, addr_sel, dt_oe_n, busy;
    ttl_74x608 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; mem_req=0;
        reset_n=1; #1; reset_n=0; #1; reset_n=1;
        mem_req=1; tick;
        if (ras_n !== 0) errors++;
        if (!busy) errors++;
        mem_req=0; tick; tick;
        if (cas_n !== 0) errors++;
        tick; tick; tick; tick;
        if (busy) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x608: %0d errors", errors);
        $display("PASS: tb_ttl_74x608");
        $finish;
    end
endmodule
