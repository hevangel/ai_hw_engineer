`timescale 1ns/1ps
module tb_ttl_74x610;
    logic clk, wr_n, oe_n, latch_en, hiz;
    logic [3:0] virt;
    logic [11:0] d, phys;
    ttl_74x610 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; oe_n=0; latch_en=1;
        virt=4'd3; d=12'h123; wr_n=0; tick;
        wr_n=1; #1; if (phys !== 12'h123) errors++;
        virt=4'd5; d=12'hABC; wr_n=0; tick;
        wr_n=1; #1; if (phys !== 12'hABC) errors++;
        virt=4'd3; #1; if (phys !== 12'h123) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x610: %0d errors", errors);
        $display("PASS: tb_ttl_74x610");
        $finish;
    end
endmodule
