`timescale 1ns/1ps
module tb_ttl_74x461;
    logic clk, clr_n, load_n, ce_n;
    logic [7:0] d, q;
    ttl_74x461 dut(.clk(clk), .clr_n(clr_n), .load_n(load_n), .ce_n(ce_n), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; load_n=1; ce_n=1; d=0; #1;
        if (q !== 0) errors++;
        clr_n=1; ce_n=0;
        for (int i = 0; i < 4; i++) begin
            if (q !== i[7:0]) errors++;
            tick;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x461: %0d errors", errors);
        $display("PASS: tb_ttl_74x461");
        $finish;
    end
endmodule
