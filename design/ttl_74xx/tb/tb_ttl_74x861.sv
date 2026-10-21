`timescale 1ns/1ps
module tb_ttl_74x861;
    logic oeab_n, oeba_n;
    logic [9:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x861 dut(.*);
    int errors;
    initial begin
        errors = 0;
        // Isolation.
        oeab_n = 1; oeba_n = 1; a_in = 10'h2A5; b_in = 10'h155; #1;
        if (a_out !== 0 || b_out !== 0 || a_oe_n !== 1 || b_oe_n !== 1) errors++;

        // A→B.
        oeab_n = 0; oeba_n = 1; #1;
        if (b_out !== 10'h2A5 || b_oe_n !== 0) errors++;
        if (a_oe_n !== 1) errors++;

        // B→A.
        oeab_n = 1; oeba_n = 0; #1;
        if (a_out !== 10'h155 || a_oe_n !== 0) errors++;

        // Both drive (latch mode).
        oeab_n = 0; oeba_n = 0; #1;
        if (a_out !== 10'h155 || b_out !== 10'h2A5) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x861: %0d errors", errors);
        $display("PASS: tb_ttl_74x861");
        $finish;
    end
endmodule
