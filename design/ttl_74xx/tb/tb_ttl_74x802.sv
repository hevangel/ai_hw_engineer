`timescale 1ns/1ps
module tb_ttl_74x802;
    logic [3:0] a0, a1, a2;
    logic y0, y1, y2, y0_n, y1_n, y2_n;
    ttl_74x802 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < 16; v++) begin
            a0 = v[3:0]; a1 = v[3:0]; a2 = v[3:0]; #1;
            if (y0   !== (|a0))   errors++;
            if (y0_n !== ~(|a0))  errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x802: %0d errors", errors);
        $display("PASS: tb_ttl_74x802");
        $finish;
    end
endmodule
