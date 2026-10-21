`timescale 1ns/1ps
module tb_ttl_74x667;
    logic le, pre_n, clr_n, oe1_n, oe2_n, oerb_n;
    logic [7:0] d_in, d_out, q_out;
    logic d_oe_n, q_oe_n;
    ttl_74x667 dut(.*);
    int errors;

    initial begin
        errors = 0;
        le = 0; pre_n = 1; clr_n = 0; oe1_n = 0; oe2_n = 0; oerb_n = 1; d_in = 0;
        #1;
        // After clear: latch=0, /Q output = 0xFF.
        if (q_out !== 8'hFF || q_oe_n !== 0) errors++;

        clr_n = 1; le = 1; d_in = 8'h5A; #1;
        if (q_out !== 8'hA5) errors++;

        le = 0; d_in = 8'hFF; #1;
        if (q_out !== 8'hA5) errors++;

        pre_n = 0; #1;
        if (q_out !== 8'h00) errors++;  // latch=FF, /Q=00
        pre_n = 1;

        clr_n = 0; #1;
        if (q_out !== 8'hFF) errors++;  // latch=00, /Q=FF
        clr_n = 1;

        // Read-back is the TRUE latched value (not inverted).
        le = 1; d_in = 8'h3C; #1; le = 0; #1;
        oerb_n = 0; #1;
        if (d_out !== 8'h3C || d_oe_n !== 0) errors++;
        oerb_n = 1;

        // Sweep: Q must be ~D when LE high.
        clr_n = 1; pre_n = 1; le = 1; oe1_n = 0; oe2_n = 0;
        for (int v = 0; v < 256; v++) begin
            d_in = v[7:0]; #1;
            if (q_out !== ~v[7:0]) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x667: %0d errors", errors);
        $display("PASS: tb_ttl_74x667");
        $finish;
    end
endmodule
