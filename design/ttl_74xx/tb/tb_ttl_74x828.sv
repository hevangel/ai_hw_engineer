`timescale 1ns/1ps
module tb_ttl_74x828;
    logic [9:0] d, q;
    logic oe1_n, oe2_n, q_oe_n;
    ttl_74x828 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0;
        for (int v = 0; v < 1024; v += 17) begin
            d = v[9:0]; #1;
            if (q !== ~v[9:0]) errors++;
        end
        oe1_n = 1; d = 10'h2A5; #1;
        if (q !== 0 || q_oe_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x828: %0d errors", errors);
        $display("PASS: tb_ttl_74x828");
        $finish;
    end
endmodule
