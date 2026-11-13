`timescale 1ns/1ps
module tb_top_a;
    logic clk = 0;
    logic rst_n = 0, cs_n = 1, ior_n = 1, iow_n = 1;
    logic [3:0] reg_addr = 0, dreq = 0;
    logic [7:0] data_i, data_o, cpu_data = 0;
    logic data_oe, hrq, hlda = 0, ready = 1, eop_n = 1, eop_out_n;
    logic [3:0] dack;
    logic [15:0] dma_addr;
    logic addr_oe, adstb, aen, memr_n, memw_n, dma_ior_n, dma_iow_n;
    logic transfer_valid;
    logic [1:0] transfer_channel;
    amd_am9517 #(.REV_A(1'b1)) dut (.reset_i(!rst_n), .*);
    always #5 clk = ~clk;

    logic [7:0] memory [0:65535];
    int checks = 0;

    always_comb begin
        data_i = cpu_data;
        if (aen && !memr_n) data_i = memory[dma_addr];
    end

    task automatic check(input bit condition, input string label_text);
        checks++;
        if (!condition) $fatal(1, "Am9517A check failed: %s at %0t", label_text, $time);
    endtask

    task automatic tick(input int n = 1);
        repeat (n) begin @(posedge clk); #1; end
    endtask

    task automatic reset_chip;
        @(negedge clk);
        rst_n = 0; cs_n = 1; ior_n = 1; iow_n = 1;
        dreq = 0; hlda = 0; ready = 1; eop_n = 1; cpu_data = 0;
        tick(2);
        @(negedge clk); rst_n = 1;
        tick();
    endtask

    task automatic wr(input logic [3:0] offset, input logic [7:0] value);
        @(negedge clk);
        reg_addr = offset; cpu_data = value; cs_n = 0; iow_n = 0; ior_n = 1;
        tick();
        @(negedge clk); cs_n = 1; iow_n = 1;
    endtask

    task automatic rd(input logic [3:0] offset, input logic [7:0] expected);
        @(negedge clk);
        reg_addr = offset; cs_n = 0; ior_n = 0; iow_n = 1;
        #1; check(data_oe && data_o == expected,
                  $sformatf("register %h expected %h actual %h", offset, expected, data_o));
        tick();
        @(negedge clk); cs_n = 1; ior_n = 1;
    endtask

    task automatic word_write(input logic [3:0] offset, input logic [15:0] value);
        wr(12, 0); wr(offset, value[7:0]); wr(offset, value[15:8]);
    endtask

    task automatic program_channel(input int ch, input logic [15:0] address,
                                   input logic [15:0] count, input logic [7:0] mode);
        word_write(4'(2*ch), address); word_write(4'(2*ch+1), count);
        wr(11, (mode & 8'hfc) | 8'(ch));
    endtask

    initial begin
        for (int i = 0; i < 65536; i++) memory[i] = 8'(i);
        reset_chip();

        $display("Am9517A status shows requesting service (software request)");
        // Channel 0 in block mode, software request set, no hardware DREQ.
        program_channel(0, 16'h0100, 0, 8'h88);
        wr(10, 8'h00); // unmask ch0
        dreq = 4'b0000;
        wr(9, 8'h04); // set software request for channel 0
        tick(2);
        // Status: bits 4-7 request pending; ch0 should be requesting service.
        rd(8, 8'h10); // request bit 4 set, TC bits clear
        // Clear request and check
        wr(9, 8'h00); // reset request bit 0
        tick(2);
        rd(8, 8'h00);

        $display("Am9517A masked hardware DREQ not shown as requesting service");
        reset_chip();
        program_channel(1, 16'h0200, 0, 8'h88);
        wr(15, 8'h0f); // mask all
        dreq = 4'b0010; // DREQ1 asserted
        tick(2);
        rd(8, 8'h00); // masked, not requesting service
        wr(10, 8'h01); // unmask ch1
        tick(2);
        rd(8, 8'h20); // ch1 requesting service

        $display("Am9517A register E write remains illegal (no clear-mask command)");
        reset_chip();
        wr(15, 8'h0f); // mask all
        dreq = 4'b0001;
        tick(2);
        wr(14, 8'h00); // undefined/illegal in this implementation context
        tick(2);
        check(!hrq, "illegal E write does not clear masks to enable request");

        $display("Am9517A TEST PASSED checks=%0d", checks);
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "Am9517A regression timeout");
    end
endmodule
