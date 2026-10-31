`timescale 1ns/1ps

module tb_ttl_74x374;
    logic clk, oe_n;
    logic [7:0] d, q;

    ttl_74x374 dut (.clk(clk), .oe_n(oe_n), .d(d), .q(q));

    task automatic tick;
        clk = 0; #1; clk = 1; #1; clk = 0; #1;
    endtask

    int errors;
    initial begin
        errors = 0;
        oe_n = 1'b0; clk = 0; d = 8'h00; #1;
        tick;
        if (q !== 8'h00) errors++;

        d = 8'hA5; tick;
        if (q !== 8'hA5) errors++;

        d = 8'hFF; tick;
        if (q !== 8'hFF) errors++;

        // Hold under no clock edge
        d = 8'h00; #1;
        if (q !== 8'hFF) errors++;

        // OE gates the output
        oe_n = 1'b1; #1;
        if (q !== 8'h00) errors++;
        oe_n = 1'b0; #1;
        if (q !== 8'hFF) errors++;

        // 32 random vectors
        for (int i = 0; i < 32; i++) begin
            d = 8'($random); tick;
            if (q !== d) errors++;
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x374: %0d errors", errors);
        $display("PASS: tb_ttl_74x374");
        $finish;
    end
endmodule
