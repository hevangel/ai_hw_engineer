`timescale 1ns/1ps
module tb_ttl_74x666;
    logic le, pre_n, clr_n, oe1_n, oe2_n, oerb_n;
    logic [7:0] d_in, d_out, q_out;
    logic d_oe_n, q_oe_n;
    ttl_74x666 dut(.*);
    int errors;

    initial begin
        errors = 0;
        le = 0; pre_n = 1; clr_n = 0; oe1_n = 0; oe2_n = 0; oerb_n = 1; d_in = 0;
        #1;
        // After clear, Q should be 0 and enabled.
        if (q_out !== 8'h00 || q_oe_n !== 0) errors++;

        // Release clear, drive data while LE high (transparent).
        clr_n = 1; le = 1; d_in = 8'h5A; #1;
        if (q_out !== 8'h5A) errors++;

        // LE low holds value.
        le = 0; d_in = 8'hFF; #1;
        if (q_out !== 8'h5A) errors++;

        // Preset.
        pre_n = 0; #1;
        if (q_out !== 8'hFF) errors++;
        pre_n = 1;

        // Clear takes priority while held.
        clr_n = 0; pre_n = 0; #1;
        if (q_out !== 8'h00) errors++;
        clr_n = 1; pre_n = 1;

        // Capture new value, then disable both Q OE pins.
        le = 1; d_in = 8'h3C; #1; le = 0; #1;
        oe1_n = 1; #1;
        if (q_out !== 0 || q_oe_n !== 1) errors++;
        oe1_n = 0; oe2_n = 1; #1;
        if (q_out !== 0 || q_oe_n !== 1) errors++;
        oe2_n = 0; #1;
        if (q_out !== 8'h3C) errors++;

        // Read-back drives D from the stored value.
        oerb_n = 0; #1;
        if (d_out !== 8'h3C || d_oe_n !== 0) errors++;
        oerb_n = 1; #1;
        if (d_oe_n !== 1) errors++;

        // Exhaustive latch capture sweep.
        clr_n = 1; pre_n = 1; le = 1;
        for (int v = 0; v < 256; v++) begin
            d_in = v[7:0]; #1;
            if (q_out !== v[7:0]) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x666: %0d errors", errors);
        $display("PASS: tb_ttl_74x666");
        $finish;
    end
endmodule
