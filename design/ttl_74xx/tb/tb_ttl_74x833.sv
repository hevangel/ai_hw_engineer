`timescale 1ns/1ps
module tb_ttl_74x833;
    logic clk, clr_n, oea_n, oeb_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n;
    logic a_oe_n, b_oe_n, parity_oe_n;
    ttl_74x833 dut(.*);
    int errors;

    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask

    initial begin
        errors = 0;
        clk = 0; clr_n = 1; oea_n = 1; oeb_n = 1;
        a_in = 0; b_in = 0; parity_in = 0;
        #1;
        // Async clear pulse to initialize the error register.
        clr_n = 0; #1;
        if (err_n !== 1) errors++;
        clr_n = 1;

        // Isolation: nothing driven.
        if (a_oe_n !== 1 || b_oe_n !== 1 || parity_oe_n !== 1) errors++;

        // Transmit normal odd-parity: A=8'h0F (4 ones, even) → PARITY=1.
        oea_n = 1; oeb_n = 0; a_in = 8'h0F; #1;
        if (b_out !== 8'h0F) errors++;
        if (parity_out !== 1) errors++;
        if (b_oe_n !== 0 || parity_oe_n !== 0) errors++;

        // A=8'h07 (3 ones, odd) → PARITY=0.
        a_in = 8'h07; #1;
        if (parity_out !== 0) errors++;

        // Transmit inverted-parity (forced error): A=0x0F → PARITY=0.
        oea_n = 0; oeb_n = 0; a_in = 8'h0F; #1;
        if (b_out !== 8'h0F) errors++;
        if (parity_out !== 0) errors++;

        // Receive: clear, then sample a no-error case.
        clr_n = 0; #1; clr_n = 1; #1;
        oea_n = 0; oeb_n = 1;
        b_in = 8'h0F; parity_in = 1; tick();  // ^{0F,1} = 0^1 = 1 → no error
        if (err_n !== 1) errors++;
        if (a_out !== 8'h0F || a_oe_n !== 0) errors++;

        // Receive with error: parity_in=0 over even-popcount B.
        b_in = 8'h0F; parity_in = 0; tick();  // ^{0F,0} = 0 → error
        if (err_n !== 0) errors++;

        // Sticky-low: subsequent good samples don't clear.
        b_in = 8'h07; parity_in = 0; tick();  // ^{07,0} = 1 → "good" but stays low
        if (err_n !== 0) errors++;

        // Only /CLR clears.
        clr_n = 0; #1;
        if (err_n !== 1) errors++;
        clr_n = 1;

        // Sweep parity generation: across all 256 A values, ^A ^ PARITY_out must = 1.
        oea_n = 1; oeb_n = 0;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; #1;
            if ((^a_in ^ parity_out) !== 1'b1) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x833: %0d errors", errors);
        $display("PASS: tb_ttl_74x833");
        $finish;
    end
endmodule
