`timescale 1ns/1ps
module tb_ttl_74x2961;
    logic oe_sm_n, oe_ms_n;
    logic [3:0] sys_in, mem_in, sys_out, mem_out;
    ttl_74x2961 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_sm_n = 0; oe_ms_n = 1; sys_in = 4'hA; mem_in = 4'h0; #1;
        if (mem_out !== 4'h5) errors++;
        oe_sm_n = 1; oe_ms_n = 0; mem_in = 4'hC; #1;
        if (sys_out !== 4'h3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2961: %0d errors", errors);
        $display("PASS: tb_ttl_74x2961");
        $finish;
    end
endmodule
