`timescale 1ns/1ps
module tb_ttl_74x682;
    logic [7:0] p, q;
    logic p_eq_q_n, p_gt_q_n;
    ttl_74x682 dut(.*);
    int errors;
    initial begin
        errors = 0;
        // Exhaustive over a 4-bit sub-range of p/q for coverage; spot-check rest.
        for (int pi = 0; pi < 16; pi++) begin
            for (int qi = 0; qi < 16; qi++) begin
                p = pi[7:0]; q = qi[7:0]; #1;
                if (p_eq_q_n !== (pi == qi ? 1'b0 : 1'b1)) errors++;
                if (p_gt_q_n !== (pi >  qi ? 1'b0 : 1'b1)) errors++;
            end
        end
        // A few full-range cases.
        p = 8'hFF; q = 8'hFF; #1;
        if (p_eq_q_n !== 0 || p_gt_q_n !== 1) errors++;
        p = 8'hFF; q = 8'h00; #1;
        if (p_eq_q_n !== 1 || p_gt_q_n !== 0) errors++;
        p = 8'h00; q = 8'hFF; #1;
        if (p_eq_q_n !== 1 || p_gt_q_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x682: %0d errors", errors);
        $display("PASS: tb_ttl_74x682");
        $finish;
    end
endmodule
