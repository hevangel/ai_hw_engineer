`timescale 1ns/1ps
module tb_ttl_74x645;
    logic oe_n, dir;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x645 dut(.*);
    int errors;
    initial begin
        errors = 0;

        // Disabled.
        oe_n = 1; dir = 1; a_in = 8'hAA; b_in = 8'h55; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (a_oe_n !== 1 || b_oe_n !== 1) errors++;

        // A->B (non-inverting).
        oe_n = 0; dir = 1; #1;
        if (b_out !== 8'hAA) errors++;
        if (a_out !== 0) errors++;
        if (b_oe_n !== 0 || a_oe_n !== 1) errors++;

        // B->A (non-inverting).
        oe_n = 0; dir = 0; #1;
        if (a_out !== 8'h55) errors++;
        if (b_out !== 0) errors++;
        if (a_oe_n !== 0 || b_oe_n !== 1) errors++;

        // Sweep both directions.
        oe_n = 0; dir = 1;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; #1;
            if (b_out !== v[7:0]) errors++;
        end
        dir = 0;
        for (int v = 0; v < 256; v++) begin
            b_in = v[7:0]; #1;
            if (a_out !== v[7:0]) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x645: %0d errors", errors);
        $display("PASS: tb_ttl_74x645");
        $finish;
    end
endmodule
