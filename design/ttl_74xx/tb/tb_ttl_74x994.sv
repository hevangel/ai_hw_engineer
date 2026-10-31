`timescale 1ns/1ps
module tb_ttl_74x994;
    logic le, oerb_n;
    logic [9:0] d_in, d_out, q;
    logic d_oe_n;
    ttl_74x994 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oerb_n = 1; le = 1; d_in = 10'h2A5; #1;
        if (q !== 10'h2A5) errors++;
        oerb_n = 0; #1;
        if (d_out !== 10'h2A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x994: %0d errors", errors);
        $display("PASS: tb_ttl_74x994");
        $finish;
    end
endmodule
