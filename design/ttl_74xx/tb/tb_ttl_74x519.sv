`timescale 1ns/1ps
module tb_ttl_74x519;
    logic [7:0] p, q;
    logic g_n, p_eq_q;
    ttl_74x519 dut(.*);
    int errors;
    initial begin
        errors=0; g_n=0;
        p=8'hA5; q=8'hA5; #1; if (p_eq_q !== 1) errors++;
        p=8'hA5; q=8'h00; #1; if (p_eq_q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x519: %0d errors", errors);
        $display("PASS: tb_ttl_74x519");
        $finish;
    end
endmodule
