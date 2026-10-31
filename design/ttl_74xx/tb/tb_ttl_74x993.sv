`timescale 1ns/1ps
module tb_ttl_74x993;
    logic le, oerb_n;
    logic [8:0] d_in, d_out, q;
    logic d_oe_n;
    ttl_74x993 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oerb_n = 1; le = 1; d_in = 9'h0A5; #1;
        if (q !== ~9'h0A5) errors++;
        oerb_n = 0; #1;
        if (d_out !== 9'h0A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x993: %0d errors", errors);
        $display("PASS: tb_ttl_74x993");
        $finish;
    end
endmodule
