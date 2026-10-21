`timescale 1ns/1ps
module tb_ttl_74x503;
    logic clk, start_n, cmp, cs_n, done, cco_n;
    logic [7:0] q;
    ttl_74x503 dut(.clk(clk), .start_n(start_n), .cmp(cmp), .cs_n(cs_n), .q(q), .done(done), .cco_n(cco_n));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; cs_n=0; clk=0; start_n=0; cmp=0; tick;
        if (q !== 8'h80) errors++;
        start_n=1; cmp=1;
        repeat (8) tick;
        if (!done) errors++;
        if (cco_n !== 1'b0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x503: %0d errors", errors);
        $display("PASS: tb_ttl_74x503");
        $finish;
    end
endmodule
