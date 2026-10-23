`timescale 1ns/1ps

module tb_ttl_74x373;
    logic oe_n, le;
    logic [7:0] d, q;

    ttl_74x373 dut (.oe_n(oe_n), .le(le), .d(d), .q(q));

    int errors;
    initial begin
        errors = 0;
        // Transparent mode: q follows d
        oe_n = 1'b0; le = 1'b1; d = 8'h00; #1;
        if (q !== 8'h00) errors++;
        d = 8'hA5; #1;
        if (q !== 8'hA5) errors++;

        // Hold mode: q holds last value
        le = 1'b0; d = 8'h5A; #1;
        if (q !== 8'hA5) errors++;
        d = 8'hFF; #1;
        if (q !== 8'hA5) errors++;

        // Re-open latch
        le = 1'b1; #1;
        if (q !== 8'hFF) errors++;

        // OE high: output forced to 0
        oe_n = 1'b1; #1;
        if (q !== 8'h00) errors++;
        // Even though latch is still tracking d:
        d = 8'h33; #1;
        if (q !== 8'h00) errors++;
        // Re-enable OE, latch should now show 0x33
        oe_n = 1'b0; #1;
        if (q !== 8'h33) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x373: %0d errors", errors);
        $display("PASS: tb_ttl_74x373");
        $finish;
    end
endmodule
