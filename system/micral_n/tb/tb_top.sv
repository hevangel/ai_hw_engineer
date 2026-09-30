module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic cpu_enable = 1;
    logic substitute = 0;
    logic [7:0] switch_data = 0;
    logic [7:0] panel_input = 0;
    logic rom_protect = 1;
    logic [13:0] host_mem_addr = 0;
    logic [7:0] host_mem_data = 0;
    logic host_mem_write = 0;
    logic [7:0] host_mem_read;
    logic [4:0] host_io_addr = 5'd8;
    logic [7:0] host_io_read;
    logic [13:0] pc, bus_addr;
    logic [7:0] accumulator, bus_data, last_output_data;
    logic [3:0] flags;
    logic halted, retired, bus_mem_read, bus_write, bus_io_read, bus_io_write;
    logic [4:0] last_output_port;
    logic [31:0] cycle_count, instruction_count;
    integer output_count = 0;
    integer input_count = 0;
    micral_n dut (.*);
    always @(posedge clk) begin
        if (rst_n && cpu_enable && bus_io_read) input_count <= input_count + 1;
        if (rst_n && cpu_enable && bus_io_write) output_count <= output_count + 1;
    end
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        repeat (120) @(negedge clk);
        if (input_count == 0 || output_count != 0)
            $fatal(1,"MO5 program did not poll input group 5");
        panel_input = 8'h80;
        repeat (120) @(negedge clk);
        if (output_count == 0 || last_output_data == 8'hxx)
            $fatal(1,"MO5 program did not send output after input switch set");
        if (halted) $fatal(1,"MO5 program unexpectedly halted");
        cpu_enable = 0;
        repeat (2) @(negedge clk);
        $display("PASS: Micral N board ran MO5 I/O program, %0d inputs, %0d outputs, port %0d data %02x",
                 input_count,output_count,last_output_port,last_output_data);
        $finish;
    end
endmodule
