module tb_top;
    logic clk;
    logic rst_n;
    logic [15:0] cpu_addr;
    logic [7:0] cpu_data_o, cpu_data_i, text_data;
    logic [6:0] key_data;
    logic cpu_we, key_valid;
    logic [9:0] text_addr;
    apple_ii_memory dut (.*);
    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; cpu_addr = 0; cpu_data_o = 0;
        cpu_we = 0; key_data = 0; key_valid = 0; text_addr = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        cpu_addr = 16'h0400; cpu_data_o = 8'hc1; cpu_we = 1;
        @(negedge clk);
        cpu_we = 0;
        if (cpu_data_i !== 8'hc1 || text_data !== 8'hc1)
            $fatal(1, "text RAM write/read failed");
        key_data = 7'h41; key_valid = 1;
        @(negedge clk);
        key_valid = 0; cpu_addr = 16'hc000;
        if (cpu_data_i !== 8'hc1) $fatal(1, "keyboard latch failed");
        cpu_addr = 16'hc010;
        @(negedge clk);
        cpu_addr = 16'hc000;
        #1;
        if (cpu_data_i !== 8'h41) $fatal(1, "keyboard strobe clear failed");
        $display("PASS: Apple II RAM, text page, keyboard latch and strobe");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "timeout");
    end
endmodule
