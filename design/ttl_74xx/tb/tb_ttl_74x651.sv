`timescale 1ns/1ps
module tb_ttl_74x651;
    logic gab, gba_n, sab, sba, cab, cba;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x651 dut(.*);
    int errors;

    initial begin
        errors = 0;
        gab = 0; gba_n = 1; sab = 0; sba = 0; cab = 0; cba = 0;
        a_in = 0; b_in = 0; #1;
        if (a_out !== 0 || b_out !== 0) errors++;

        // A->B real-time, inverting.
        gab = 1; sab = 0; a_in = 8'h0F; #1;
        if (b_out !== 8'hF0) errors++;

        // Capture A->B then stored.
        a_in = 8'hA5; cab = 0; #1; cab = 1; #1; a_in = 8'h00; sab = 1; #1;
        if (b_out !== 8'h5A) errors++;

        // B->A real-time, inverting.
        gab = 0; gba_n = 0; sba = 0; b_in = 8'h33; #1;
        if (a_out !== 8'hCC) errors++;

        b_in = 8'h7E; cba = 0; #1; cba = 1; #1; b_in = 8'h00; sba = 1; #1;
        if (a_out !== 8'h81) errors++;

        // Both enabled: A->B stored + B->A stored simultaneously.
        gab = 1; gba_n = 0; sab = 1; sba = 1; #1;
        if (b_out !== 8'h5A) errors++;
        if (a_out !== 8'h81) errors++;

        // Both disabled.
        gab = 0; gba_n = 1; #1;
        if (a_out !== 0 || b_out !== 0) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x651: %0d errors", errors);
        $display("PASS: tb_ttl_74x651");
        $finish;
    end
endmodule
