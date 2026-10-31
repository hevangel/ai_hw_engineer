`timescale 1ns/1ps
module tb_ttl_74x322;
    logic clk, clr_n, s_e_n, s_l_n, din, q_h;
    logic [7:0] p, q;
    ttl_74x322 dut(.clk(clk), .clr_n(clr_n), .s_e_n(s_e_n), .s_l_n(s_l_n), .din(din), .p(p), .q(q), .q_h(q_h));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; s_e_n=1; s_l_n=1; din=0; p=0; #1;
        clr_n=1;
        // Load 0x80 (signed -128)
        s_l_n=0; p=8'h80; tick; s_l_n=1;
        if (q !== 8'h80) errors++;
        // Sign extend
        s_e_n=0; tick;
        if (q !== 8'hC0) errors++;
        tick;
        if (q !== 8'hE0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x322: %0d errors", errors);
        $display("PASS: tb_ttl_74x322");
        $finish;
    end
endmodule
