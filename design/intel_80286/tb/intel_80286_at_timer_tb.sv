module intel_80286_at_timer_tb;
    logic clk, rst_n, io_req, io_ready, io_write, port61_bit0;
    logic [15:0] io_addr;
    logic [7:0] io_wdata, rdata;
    logic [2:0] counter_clk, timer_out;
    logic selected, rdata_valid;
    logic [7:0] low_byte, high_byte;

    intel_80286_at_timer dut (
        .clk(clk), .rst_n(rst_n), .io_req_i(io_req), .io_ready_i(io_ready),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata),
        .port61_bit0_i(port61_bit0), .counter_clk_i(counter_clk), .selected_o(selected),
        .rdata_valid_o(rdata_valid), .rdata_o(rdata), .timer_out_o(timer_out)
    );

    task automatic tick;
        clk = 0; #5; clk = 1; #5;
    endtask

    task automatic write_byte(input logic [15:0] address,
                              input logic [7:0] value,
                              input integer stalls);
        io_req = 1; io_write = 1; io_addr = address; io_wdata = value;
        io_ready = 0;
        repeat (stalls) tick();
        io_ready = 1; tick();
        io_req = 0; io_ready = 0; tick();
    endtask

    task automatic read_byte(input logic [15:0] address,
                             output logic [7:0] value);
        io_req = 1; io_write = 0; io_addr = address; io_ready = 0; #1;
        if (!selected || rdata_valid) $fatal(1, "stalled read drove data");
        tick();
        io_ready = 1; #1;
        if (!rdata_valid) $fatal(1, "accepted timer read was not driven");
        value = rdata; tick();
        io_req = 0; io_ready = 0; tick();
    endtask

    task automatic counter_pulse;
        counter_clk = 3'b000; tick();
        counter_clk = 3'b111; tick();
    endtask

    initial begin
        clk = 0; rst_n = 0; io_req = 0; io_ready = 0; io_write = 0;
        io_addr = 0; io_wdata = 0; port61_bit0 = 0; counter_clk = 3'b111;
        tick(); tick(); rst_n = 1; tick();
        if (timer_out !== 3'b111) $fatal(1, "timer reset outputs");

        // Channel 1, binary mode 2, low byte then high byte, reload 8.
        write_byte(16'h0043, 8'h74, 0);
        write_byte(16'h0041, 8'h08, 3);
        write_byte(16'h0041, 8'h00, 0);
        // The counter keeps running while the CPU has a stalled timer read.
        io_req = 1; io_ready = 0; io_write = 0; io_addr = 16'h0041;
        counter_pulse(); counter_pulse(); counter_pulse();
        io_req = 0; tick();
        write_byte(16'h0043, 8'h40, 0); // latch channel 1
        read_byte(16'h0041, low_byte);
        read_byte(16'h0041, high_byte);
        if ({high_byte, low_byte} !== 16'h0006)
            $fatal(1, "timer count or stalled-write byte phase incorrect: %04x",
                   {high_byte, low_byte});

        io_req = 1; io_ready = 1; io_write = 0; io_addr = 16'h0044; #1;
        if (selected || rdata_valid) $fatal(1, "unmodeled port decoded");
        io_req = 0; io_ready = 0; tick();
        $display("PASS: AT timer canonical ports, READY stalls, 8254 byte phases and independent timer clocks");
        $finish;
    end
endmodule
