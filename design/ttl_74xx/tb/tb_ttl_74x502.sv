`timescale 1ns/1ps
module tb_ttl_74x502;
    logic clk, start, cmp, done;
    logic [7:0] q;
    ttl_74x502 dut(.clk(clk), .start(start), .cmp(cmp), .q(q), .done(done));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; start=1; cmp=0; tick;
        if (q !== 8'h80) errors++;
        start=0; cmp=1;
        for (int i = 0; i < 8; i++) tick;
        if (!done) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x502: %0d errors", errors);
        $display("PASS: tb_ttl_74x502");
        $finish;
    end
endmodule
