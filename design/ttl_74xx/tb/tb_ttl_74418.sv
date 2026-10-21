`timescale 1ns/1ps
module tb_ttl_74418;
    logic clk, clr_n, load_n;
    logic [3:0] d, q;
    ttl_74418 dut(.clk(clk), .clr_n(clr_n), .load_n(load_n), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; load_n=1; d=0; #1;
        clr_n=1;
        for (int i = 0; i < 16; i++) begin
            if (q !== i[3:0]) errors++;
            tick;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74418: %0d errors", errors);
        $display("PASS: tb_ttl_74418");
        $finish;
    end
endmodule
