`timescale 1ns/1ps
module tb_ttl_74x683;
    logic [7:0] p, q;
    logic p_eq_q_n, p_gt_q_n;
    ttl_74x683 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int pi = 0; pi < 16; pi++) begin
            for (int qi = 0; qi < 16; qi++) begin
                p = pi[7:0]; q = qi[7:0]; #1;
                if (p_eq_q_n !== (pi == qi ? 1'b0 : 1'b1)) errors++;
                if (p_gt_q_n !== (pi >  qi ? 1'b0 : 1'b1)) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x683: %0d errors", errors);
        $display("PASS: tb_ttl_74x683");
        $finish;
    end
endmodule
