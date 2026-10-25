`timescale 1ns/1ps
module tb_ttl_74x162245;
    logic oe_n, dir;
    logic [15:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x162245 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 16'hA5C3; b_in = 0; #1;
        if (b_out !== 16'hA5C3 || b_oe_n !== 0) errors++;
        oe_n = 0; dir = 0; b_in = 16'h3CA5; #1;
        if (a_out !== 16'h3CA5 || a_oe_n !== 0) errors++;
        oe_n = 1; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162245: %0d errors", errors);
        $display("PASS: tb_ttl_74x162245");
        $finish;
    end
endmodule
