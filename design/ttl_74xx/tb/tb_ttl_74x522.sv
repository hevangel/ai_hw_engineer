`timescale 1ns/1ps
module tb_ttl_74x522;
    logic [7:0] p, q;
    logic g_n, p_eq_q_n;
    ttl_74x522 dut(.*);
    int errors;
    initial begin
        errors=0; g_n=0;
        p=8'h12; q=8'h12; #1; if (p_eq_q_n !== 0) errors++;
        p=8'h12; q=8'h13; #1; if (p_eq_q_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x522: %0d errors", errors);
        $display("PASS: tb_ttl_74x522");
        $finish;
    end
endmodule
