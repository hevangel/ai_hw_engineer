`timescale 1ns/1ps
module tb_ttl_74x686;
    logic g1_n, g2_n;
    logic [7:0] p, q;
    logic p_eq_q_n, p_gt_q_n;
    ttl_74x686 dut(.*);
    int errors;
    initial begin
        errors = 0;
        // Both enabled.
        g1_n = 0; g2_n = 0;
        for (int pi = 0; pi < 16; pi++) begin
            for (int qi = 0; qi < 16; qi++) begin
                p = pi[7:0]; q = qi[7:0]; #1;
                if (p_eq_q_n !== (pi == qi ? 1'b0 : 1'b1)) errors++;
                if (p_gt_q_n !== (pi >  qi ? 1'b0 : 1'b1)) errors++;
            end
        end
        // g1 disabled (eq forced high), g2 still active.
        g1_n = 1; g2_n = 0; p = 8'h05; q = 8'h05; #1;
        if (p_eq_q_n !== 1) errors++;
        p = 8'h06; q = 8'h05; #1;
        if (p_gt_q_n !== 0 || p_eq_q_n !== 1) errors++;

        // g2 disabled (gt forced high), g1 still active.
        g1_n = 0; g2_n = 1; p = 8'h07; q = 8'h05; #1;
        if (p_gt_q_n !== 1) errors++;
        if (p_eq_q_n !== 1) errors++;  // not equal

        // Both disabled.
        g1_n = 1; g2_n = 1; p = 8'h01; q = 8'h01; #1;
        if (p_eq_q_n !== 1 || p_gt_q_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x686: %0d errors", errors);
        $display("PASS: tb_ttl_74x686");
        $finish;
    end
endmodule
