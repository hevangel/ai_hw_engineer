`timescale 1ns/1ps
module tb_ttl_74x862;
    logic oeab_n, oeba_n;
    logic [9:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x862 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oeab_n = 0; oeba_n = 1; a_in = 10'h2A5; #1;
        if (b_out !== ~10'h2A5) errors++;
        oeab_n = 1; oeba_n = 0; b_in = 10'h155; #1;
        if (a_out !== ~10'h155) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x862: %0d errors", errors);
        $display("PASS: tb_ttl_74x862");
        $finish;
    end
endmodule
