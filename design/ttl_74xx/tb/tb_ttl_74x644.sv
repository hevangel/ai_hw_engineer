`timescale 1ns/1ps
module tb_ttl_74x644;
    logic gab, gba_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x644 dut(.*);
    int errors;
    initial begin
        errors = 0;

        gab = 1; gba_n = 1; a_in = 8'h5A; b_in = 8'hFF; #1;
        if (b_out !== 8'h5A) errors++;
        if (a_out !== 8'h00) errors++;

        gab = 0; gba_n = 0; a_in = 8'hFF; b_in = 8'h0F; #1;
        if (a_out !== 8'hF0) errors++;
        if (b_out !== 8'h00) errors++;

        gab = 0; gba_n = 1; #1;
        if (a_out !== 8'h00 || b_out !== 8'h00) errors++;

        gab = 1; gba_n = 1;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; #1;
            if (b_out !== v[7:0]) errors++;
        end
        gab = 0; gba_n = 0;
        for (int v = 0; v < 256; v++) begin
            b_in = v[7:0]; #1;
            if (a_out !== ~v[7:0]) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x644: %0d errors", errors);
        $display("PASS: tb_ttl_74x644");
        $finish;
    end
endmodule
