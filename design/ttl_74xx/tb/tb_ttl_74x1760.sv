`timescale 1ns/1ps
module tb_ttl_74x1760;
    logic oe_n, le;
    logic [1:0] sel;
    logic [9:0] a, b, c, d, y;
    logic hiz;
    ttl_74x1760 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1;
        a = 10'h3FF; b = 10'h155; c = 10'h2AA; d = 10'h001;
        sel = 2'b00; #1; if (y !== 10'h3FF) errors++;
        sel = 2'b01; #1; if (y !== 10'h155) errors++;
        sel = 2'b10; #1; if (y !== 10'h2AA) errors++;
        sel = 2'b11; #1; if (y !== 10'h001) errors++;
        // latch: change sel/inputs after le=0; y should hold last value
        sel = 2'b10; #1; if (y !== 10'h2AA) errors++;
        le = 0; #1;
        sel = 2'b00; #1; if (y !== 10'h2AA) errors++;  // held
        // output enable
        oe_n = 1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1760: %0d errors", errors);
        $display("PASS: tb_ttl_74x1760");
        $finish;
    end
endmodule
