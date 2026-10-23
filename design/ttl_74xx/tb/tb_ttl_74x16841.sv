`timescale 1ns/1ps
module tb_ttl_74x16841;
    logic le, oe_n;
    logic [19:0] d, q;
    logic q_oe_n;
    ttl_74x16841 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 20'hABCDE; #1;
        if (q !== 20'hABCDE) errors++;
        le = 0; d = 0; #1;
        if (q !== 20'hABCDE) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16841: %0d errors", errors);
        $display("PASS: tb_ttl_74x16841");
        $finish;
    end
endmodule
