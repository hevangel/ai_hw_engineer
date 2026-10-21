`timescale 1ns/1ps
module tb_ttl_74x823;
    logic clk, clr_n, clken_n, oe_n;
    logic [8:0] d, q;
    logic q_oe_n;
    ttl_74x823 dut(.*);
    int errors;
    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; clken_n = 0; oe_n = 0; d = 0;
        #1;
        if (q !== 0) errors++;

        // Release CLR, capture data.
        clr_n = 1; d = 9'h1A5; tick();
        if (q !== 9'h1A5) errors++;

        // Hold with CLKEN high.
        clken_n = 1; d = 9'h0FF; tick();
        if (q !== 9'h1A5) errors++;

        // Re-enable CLKEN and capture.
        clken_n = 0; d = 9'h0AA; tick();
        if (q !== 9'h0AA) errors++;

        // Async clear.
        clr_n = 0; #1;
        if (q !== 0) errors++;
        clr_n = 1;

        // /OE gates output only.
        d = 9'h155; tick();
        oe_n = 1; #1;
        if (q !== 0 || q_oe_n !== 1) errors++;
        d = 9'h0EE; tick();
        oe_n = 0; #1;
        if (q !== 9'h0EE) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x823: %0d errors", errors);
        $display("PASS: tb_ttl_74x823");
        $finish;
    end
endmodule
