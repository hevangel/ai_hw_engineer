`timescale 1ns/1ps
module tb_ttl_74x841;
    logic le, oe_n;
    logic [9:0] d, q;
    logic q_oe_n;
    ttl_74x841 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 10'h2A5; #1;
        if (q !== 10'h2A5) errors++;
        d = 10'h155; #1;
        if (q !== 10'h155) errors++;  // transparent

        le = 0; #1; d = 10'h3FF; #1;
        if (q !== 10'h155) errors++;  // held

        oe_n = 1; #1;
        if (q !== 10'h000 || q_oe_n !== 1) errors++;

        // While Hi-Z, change LE high then low to capture new data — storage works.
        le = 1; d = 10'h0CC; #1; le = 0; #1;
        oe_n = 0; #1;
        if (q !== 10'h0CC) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x841: %0d errors", errors);
        $display("PASS: tb_ttl_74x841");
        $finish;
    end
endmodule
