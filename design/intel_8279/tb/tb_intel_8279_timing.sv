`timescale 1ns / 1ps

module tb_intel_8279_timing;
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;
    logic rst_n = 1'b0;
    logic [3:0] sl;
    logic [7:0] data_o;
    logic data_oe;
    logic irq;
    logic [3:0] out_a;
    logic [3:0] out_b;
    logic bd_n;

    intel_8279 dut (
        .clk(clk), .rst_n(rst_n),
        .cs_n(1'b1), .rd_n(1'b1), .wr_n(1'b1),
        .a0(1'b0), .data_i(8'h00),
        .data_o(data_o), .data_oe(data_oe), .irq(irq),
        .sl(sl), .rl(8'hFF), .shift(1'b1), .cntl_stb(1'b1),
        .out_a(out_a), .out_b(out_b), .bd_n(bd_n)
    );

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;
        #1;
        if (data_o !== 8'h00 || data_oe !== 1'b0 || irq !== 1'b0 ||
            out_a !== 4'h0 || out_b !== 4'h0 || bd_n !== 1'b1)
            $fatal(1, "default reset outputs incorrect");
        repeat (31*64) @(posedge clk);
        #1;
        if (sl !== 4'd0) $fatal(1, "default scan advanced too early");
        @(posedge clk); #1;
        if (sl !== 4'd1) $fatal(1, "default scan did not advance after 31*64 clocks");
        $display("8279 default timing passed: 31*64 clocks per digit");
        $finish;
    end
endmodule
