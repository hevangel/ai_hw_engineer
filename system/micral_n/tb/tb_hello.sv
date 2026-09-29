module tb_hello;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, cpu_enable = 1, substitute = 0;
    logic [7:0] switch_data = 0, panel_input = 0;
    logic rom_protect = 1;
    logic [13:0] host_mem_addr = 0;
    logic [7:0] host_mem_data = 0, host_mem_read;
    logic host_mem_write = 0;
    logic [4:0] host_io_addr = 8;
    logic [7:0] host_io_read;
    logic [13:0] pc, bus_addr;
    logic [7:0] accumulator, bus_data, last_output_data;
    logic [3:0] flags;
    logic halted, retired, bus_mem_read, bus_write, bus_io_read, bus_io_write;
    logic [4:0] last_output_port;
    logic [31:0] cycle_count, instruction_count;
    micral_n dut (.*);
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (integer n=0; n<10000 && !halted; n=n+1) @(negedge clk);
        if (!halted) $fatal(1,"MO5 hello-world program did not halt");
        cpu_enable = 0;
        for (integer i=0; i<12; i=i+1) begin
            host_mem_addr = 14'h1000 + 14'(i);
            #1;
            case (i)
                0: if (host_mem_read !== "H") $fatal(1,"H missing");
                1: if (host_mem_read !== "E") $fatal(1,"E missing");
                2: if (host_mem_read !== "L") $fatal(1,"L missing");
                3: if (host_mem_read !== "L") $fatal(1,"L missing");
                4: if (host_mem_read !== "O") $fatal(1,"O missing");
                5: if (host_mem_read !== " ") $fatal(1,"space missing");
                6: if (host_mem_read !== "W") $fatal(1,"W missing");
                7: if (host_mem_read !== "O") $fatal(1,"O missing");
                8: if (host_mem_read !== "R") $fatal(1,"R missing");
                9: if (host_mem_read !== "L") $fatal(1,"L missing");
                10: if (host_mem_read !== "D") $fatal(1,"D missing");
                11: if (host_mem_read !== 0) $fatal(1,"terminator missing");
            endcase
        end
        $display("PASS: MO5 Micral memory program copied HELLO WORLD to RAM, %0d instructions",instruction_count);
        $finish;
    end
endmodule
