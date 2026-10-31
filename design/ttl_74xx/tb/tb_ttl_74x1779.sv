`timescale 1ns/1ps
module tb_ttl_74x1779;
    logic clk, clr_n, load_n, cnt_en_n, up_dn;
    logic [7:0] d, q;
    logic rco_n;
    ttl_74x1779 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; load_n = 1; cnt_en_n = 1; up_dn = 1; d = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 8'h00) errors++;
        // parallel load
        d = 8'hFE; load_n = 0; tick; load_n = 1;
        if (q !== 8'hFE) errors++;
        // count up
        cnt_en_n = 0; up_dn = 1; tick;
        if (q !== 8'hFF) errors++;
        if (rco_n !== 0) errors++;  // carry-out asserted at max with cnt_en
        tick;
        if (q !== 8'h00) errors++;
        // count down
        up_dn = 0; tick;
        if (q !== 8'hFF) errors++;
        cnt_en_n = 1;
        if (errors != 0) $fatal(1, "tb_ttl_74x1779: %0d errors", errors);
        $display("PASS: tb_ttl_74x1779");
        $finish;
    end
endmodule
