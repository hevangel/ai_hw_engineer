`timescale 1ns/1ps
module tb_ttl_74x648;
    logic g_n, dir, sab, sba, cab, cba;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x648 dut(.*);
    int errors;

    initial begin
        errors = 0;
        g_n = 1; dir = 0; sab = 0; sba = 0; cab = 0; cba = 0;
        a_in = 0; b_in = 0; #1;
        if (a_out !== 0 || b_out !== 0) errors++;

        // A->B real-time, inverting.
        g_n = 0; dir = 1; sab = 0; a_in = 8'h0F; #1;
        if (b_out !== 8'hF0) errors++;

        // Capture into A->B latch then stored mode.
        a_in = 8'hA5; cab = 0; #1; cab = 1; #1; a_in = 8'h00; sab = 1; #1;
        if (b_out !== 8'h5A) errors++;

        // B->A real-time, inverting.
        dir = 0; sba = 0; b_in = 8'h33; #1;
        if (a_out !== 8'hCC) errors++;

        // B->A stored.
        b_in = 8'h7E; cba = 0; #1; cba = 1; #1; b_in = 8'h00; sba = 1; #1;
        if (a_out !== 8'h81) errors++;

        // Disabled.
        g_n = 1; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (a_oe_n !== 1 || b_oe_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x648: %0d errors", errors);
        $display("PASS: tb_ttl_74x648");
        $finish;
    end
endmodule
