`timescale 1ns/1ps
module tb_ttl_74x657;
    logic t_r, oe_n, odd;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n;
    logic a_oe_n, b_oe_n, parity_oe_n, err_oe_n;
    ttl_74x657 dut(.*);
    int errors;

    initial begin
        errors = 0;

        // Disabled.
        oe_n = 1; t_r = 1; odd = 1; a_in = 8'hFF; b_in = 0; parity_in = 0; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (a_oe_n !== 1 || b_oe_n !== 1 || parity_oe_n !== 1 || err_oe_n !== 1) errors++;

        // Transmit, odd parity, A has 8 ones (even count). parity_out should be 1.
        oe_n = 0; t_r = 1; odd = 1; a_in = 8'hFF; #1;
        if (b_out !== 8'hFF) errors++;
        if (parity_out !== 1) errors++;  // ^FF=0 XOR odd=1 -> 1
        if (b_oe_n !== 0 || parity_oe_n !== 0) errors++;
        if (err_oe_n !== 1) errors++;

        // Transmit, odd parity, A has 1 one. parity_out should be 0.
        a_in = 8'h01; #1;
        if (parity_out !== 0) errors++;  // ^01=1 XOR 1 -> 0

        // Transmit, even parity, A has 3 ones. parity_out should be 1.
        odd = 0; a_in = 8'h07; #1;
        if (parity_out !== 1) errors++;  // ^07=1 XOR 0 -> 1

        // Receive, odd parity, B even bits, parity_in=1 -> no error (err_n=1).
        oe_n = 0; t_r = 0; odd = 1; b_in = 8'h33; parity_in = 1; #1;
        if (a_out !== 8'h33) errors++;
        if (a_oe_n !== 0 || err_oe_n !== 0) errors++;
        if (b_oe_n !== 1 || parity_oe_n !== 1) errors++;
        // ^33=0 (four ones), parity_in=1, odd=1; ^=0; err_n=~0=1 (no error). ✓
        if (err_n !== 1) errors++;

        // Same data, parity_in=0 -> error.
        parity_in = 0; #1;
        // ^=0^0^1=1; err_n=~1=0 (error). ✓
        if (err_n !== 0) errors++;

        // Receive, even parity, B has odd bits, parity_in=1 -> no error.
        odd = 0; b_in = 8'h01; parity_in = 1; #1;
        // ^01=1^1^0=0; err_n=1 (no error). ✓
        if (err_n !== 1) errors++;

        // Receive, even parity, B has odd bits, parity_in=0 -> error.
        parity_in = 0; #1;
        // ^01=1^0^0=1; err_n=0 (error). ✓
        if (err_n !== 0) errors++;

        // Sweep: transmit, odd parity, parity_out must satisfy total-odd.
        oe_n = 0; t_r = 1; odd = 1;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; #1;
            if (^{a_in, parity_out} !== 1'b1) begin
                errors++; $display("transmit-odd v=%h parity=%b", a_in, parity_out);
            end
        end
        // Sweep: transmit, even parity.
        odd = 0;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; #1;
            if (^{a_in, parity_out} !== 1'b0) begin
                errors++; $display("transmit-even v=%h parity=%b", a_in, parity_out);
            end
        end

        // Sweep: receive, odd parity, exhaustive over (b_in, parity_in).
        oe_n = 0; t_r = 0; odd = 1;
        begin : recv_sweep
            logic exp_no_error;
            for (int v = 0; v < 256; v++) begin
                b_in = v[7:0];
                for (int p = 0; p < 2; p++) begin
                    parity_in = p[0]; #1;
                    exp_no_error = ^{b_in, parity_in};  // total odd -> no error under odd parity
                    if (err_n !== exp_no_error) begin
                        errors++; $display("recv-odd b=%h p=%b err_n=%b exp=%b",
                                           b_in, parity_in, err_n, exp_no_error);
                    end
                end
            end
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x657: %0d errors", errors);
        $display("PASS: tb_ttl_74x657");
        $finish;
    end
endmodule
