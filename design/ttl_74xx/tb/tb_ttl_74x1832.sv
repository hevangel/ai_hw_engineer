`timescale 1ns/1ps
module tb_ttl_74x1832;
    logic [5:0] a, b, y;
    ttl_74x1832 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < 64; v++) begin
            logic [5:0] vv;
            vv = v[5:0];
            a = vv; b = ~vv; #1;
            if (y !== 6'h3F) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1832: %0d errors", errors);
        $display("PASS: tb_ttl_74x1832");
        $finish;
    end
endmodule
