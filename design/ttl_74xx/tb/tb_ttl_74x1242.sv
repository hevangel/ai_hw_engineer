`timescale 1ns/1ps
module tb_ttl_74x1242;
    logic oe_n_to_b, oe_to_a;
    logic [3:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x1242 dut(.*);
    int errors;
    initial begin
        errors = 0;
        // A->B enabled.
        oe_n_to_b = 0; oe_to_a = 0; a_in = 4'hA; b_in = 4'h5; #1;
        if (b_out !== 4'h5 /* ~A=5 */ || a_out !== 0) errors++;
        // B->A enabled.
        oe_n_to_b = 1; oe_to_a = 1; #1;
        if (a_out !== ~4'h5) errors++;
        // Disabled.
        oe_n_to_b = 1; oe_to_a = 0; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1242: %0d errors", errors);
        $display("PASS: tb_ttl_74x1242");
        $finish;
    end
endmodule
