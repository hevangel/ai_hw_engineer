`timescale 1ns / 1ps

module tb_intel_8279;
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n = 1'b0;
    logic cs_n = 1'b1;
    logic rd_n = 1'b1;
    logic wr_n = 1'b1;
    logic a0 = 1'b0;
    logic [7:0] data_i = 8'h00;
    logic [7:0] data_o;
    logic data_oe;
    logic irq;
    logic [3:0] sl;
    logic [7:0] rl;
    logic shift = 1'b1;
    logic cntl_stb = 1'b1;
    logic [3:0] out_a;
    logic [3:0] out_b;
    logic bd_n;
    logic keyboard_drive = 1'b0;
    logic [3:0] target_scan = 4'd0;
    logic [7:0] target_rl = 8'hFF;
    logic [7:0] rl_static = 8'hFF;
    integer checks = 0;
    integer failures = 0;

    always_comb rl = keyboard_drive ? ((sl == target_scan) ? target_rl : 8'hFF) : rl_static;

    intel_8279 #(.SCAN_DIV(1)) dut (.*);

    task automatic expect_byte(input string label, input logic [7:0] got,
                               input logic [7:0] wanted);
        checks = checks + 1;
        if (got !== wanted) begin
            failures = failures + 1;
            $display("FAIL %s: got %02h expected %02h", label, got, wanted);
        end
    endtask

    task automatic expect_bit(input string label, input logic got, input logic wanted);
        checks = checks + 1;
        if (got !== wanted) begin
            failures = failures + 1;
            $display("FAIL %s: got %b expected %b", label, got, wanted);
        end
    endtask

    task automatic cpu_write(input logic command, input logic [7:0] value);
        @(negedge clk);
        cs_n = 1'b0;
        wr_n = 1'b0;
        rd_n = 1'b1;
        a0 = command;
        data_i = value;
        @(posedge clk);
        #1;
        @(negedge clk);
        cs_n = 1'b1;
        wr_n = 1'b1;
    endtask

    task automatic cpu_read(input logic status_read, output logic [7:0] value);
        @(negedge clk);
        cs_n = 1'b0;
        rd_n = 1'b0;
        wr_n = 1'b1;
        a0 = status_read;
        #1;
        expect_bit("read output enable", data_oe, 1'b1);
        value = data_o;
        @(posedge clk);
        #1;
        @(negedge clk);
        cs_n = 1'b1;
        rd_n = 1'b1;
    endtask

    task automatic wait_cycles(input integer count);
        repeat (count) @(posedge clk);
        #1;
    endtask

    task automatic reset_dut;
        @(negedge clk);
        rst_n = 1'b0;
        cs_n = 1'b1;
        rd_n = 1'b1;
        wr_n = 1'b1;
        keyboard_drive = 1'b0;
        rl_static = 8'hFF;
        shift = 1'b1;
        cntl_stb = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    endtask

    logic [7:0] value;
    initial begin
        reset_dut();
        cpu_read(1'b1, value);
        expect_byte("reset status", value, 8'h00);
        cpu_write(1'b1, 8'h22); // divide by two

        // Shared display pointer, read/write auto-increment, and nibble inhibit.
        cpu_write(1'b1, 8'h90);
        cpu_write(1'b0, 8'h12);
        cpu_write(1'b0, 8'h34);
        cpu_write(1'b1, 8'h70);
        cpu_read(1'b0, value); expect_byte("display 0", value, 8'h12);
        cpu_read(1'b0, value); expect_byte("display 1", value, 8'h34);
        cpu_write(1'b1, 8'h80);
        cpu_read(1'b0, value); expect_byte("shared pointer", value, 8'h12);
        cpu_write(1'b1, 8'hA8); // inhibit nibble A
        cpu_write(1'b1, 8'h80);
        cpu_write(1'b0, 8'hFF);
        cpu_write(1'b1, 8'h60);
        cpu_read(1'b0, value); expect_byte("inhibit A", value, 8'hF2);
        cpu_write(1'b1, 8'hA0);

        // Clear all is asynchronous to the CPU and blocks display writes.
        cpu_write(1'b1, 8'hD1);
        cpu_read(1'b1, value); expect_bit("display unavailable", value[7], 1'b1);
        expect_bit("blank display while clear", bd_n, 1'b0);
        cpu_write(1'b1, 8'h80);
        cpu_write(1'b0, 8'hCC);
        wait_cycles(40);
        cpu_read(1'b1, value); expect_bit("clear complete", value[7], 1'b0);
        expect_bit("display enabled after clear", bd_n, 1'b1);
        cpu_write(1'b1, 8'h60);
        cpu_read(1'b0, value); expect_byte("clear pattern", value, 8'h00);
        cpu_write(1'b1, 8'hDC); // clear display to FF
        wait_cycles(22);
        cpu_write(1'b1, 8'hA2); // blank A to the programmed FF code
        expect_byte("blank A code", {4'h0, out_a}, 8'h0F);
        cpu_write(1'b1, 8'hA0);
        cpu_write(1'b1, 8'hD1); // clear back to zero
        wait_cycles(22);

        // Right entry rotates visible positions while RAM remains addressable.
        cpu_write(1'b1, 8'h10);
        cpu_write(1'b1, 8'h90);
        cpu_write(1'b0, 8'h11);
        cpu_write(1'b0, 8'h22);
        cpu_write(1'b1, 8'h60);
        cpu_read(1'b0, value); expect_byte("right RAM 0", value, 8'h11);
        cpu_write(1'b1, 8'h61);
        cpu_read(1'b0, value); expect_byte("right RAM 1", value, 8'h22);
        wait_cycles(16);
        while (sl != 4'd7) @(posedge clk);
        #1;
        expect_byte("rightmost display output", {out_b, out_a}, 8'h22);

        // Decoded scan exposes only four display positions.
        cpu_write(1'b1, 8'h09);
        wait_cycles(12);
        checks = checks + 1;
        if (!(sl == 4'b1110 || sl == 4'b1101 || sl == 4'b1011 || sl == 4'b0111)) begin
            failures = failures + 1;
            $display("FAIL decoded scan: %b", sl);
        end

        // Sensor changes latch IRQ and freeze RAM until non-AI read / EOI.
        cpu_write(1'b1, 8'h04);
        keyboard_drive = 1'b1;
        target_scan = 4'd0;
        target_rl = 8'hFE;
        wait_cycles(20);
        expect_bit("sensor IRQ", irq, 1'b1);
        cpu_write(1'b1, 8'h40);
        cpu_read(1'b0, value); expect_byte("sensor row zero", value, 8'hFE);
        expect_bit("sensor IRQ cleared by non-AI read", irq, 1'b0);
        keyboard_drive = 1'b0;
        wait_cycles(20);
        expect_bit("sensor release IRQ", irq, 1'b1);
        cpu_write(1'b1, 8'h50);
        cpu_read(1'b0, value); expect_byte("sensor auto-increment read", value, 8'hFF);
        expect_bit("sensor AI retains IRQ", irq, 1'b1);
        cpu_write(1'b1, 8'hE0);
        expect_bit("sensor EOI", irq, 1'b0);

        // Strobed input FIFO, IRQ, count, and underrun.
        cpu_write(1'b1, 8'h06);
        cpu_write(1'b1, 8'hC2);
        rl_static = 8'hA5;
        @(negedge clk); cntl_stb = 1'b0;
        wait_cycles(2);
        @(negedge clk); cntl_stb = 1'b1;
        wait_cycles(2);
        expect_bit("strobe IRQ", irq, 1'b1);
        cpu_read(1'b1, value); expect_byte("strobe status count", value, 8'h01);
        cpu_write(1'b1, 8'h40);
        cpu_read(1'b0, value); expect_byte("strobe data", value, 8'hA5);
        expect_bit("strobe drained IRQ", irq, 1'b0);
        cpu_read(1'b0, value);
        cpu_read(1'b1, value); expect_bit("underrun", value[4], 1'b1);

        // Nine rising strobes fill the FIFO and set sticky overrun.
        cpu_write(1'b1, 8'hC2);
        for (int k = 0; k < 9; k = k + 1) begin
            rl_static = 8'(k);
            @(negedge clk); cntl_stb = 1'b0;
            wait_cycles(2);
            @(negedge clk); cntl_stb = 1'b1;
            wait_cycles(2);
        end
        cpu_read(1'b1, value); expect_byte("FIFO full overrun", value, 8'h28);
        for (int k = 0; k < 8; k = k + 1) begin
            cpu_read(1'b0, value);
            expect_byte("FIFO order", value, 8'(k));
        end
        cpu_read(1'b1, value); expect_byte("overrun sticky", value, 8'h20);
        rl_static = 8'hFF;

        // Two same-row keys in rollover mode must occupy distinct FIFO slots.
        cpu_write(1'b1, 8'h02);
        cpu_write(1'b1, 8'hC2);
        keyboard_drive = 1'b1;
        target_scan = 4'd0;
        target_rl = 8'hFC;
        wait_cycles(70);
        cpu_read(1'b1, value); expect_byte("rollover count", value, 8'h02);
        cpu_write(1'b1, 8'h40);
        cpu_read(1'b0, value); expect_byte("rollover first", value, 8'h00);
        cpu_read(1'b0, value); expect_byte("rollover second", value, 8'h01);
        keyboard_drive = 1'b0;
        wait_cycles(25);

        // Two-key lockout waits until only one key remains.
        cpu_write(1'b1, 8'h00);
        cpu_write(1'b1, 8'hC2);
        keyboard_drive = 1'b1;
        target_rl = 8'hFC;
        wait_cycles(50);
        cpu_read(1'b1, value); expect_byte("lockout count", value, 8'h00);
        target_rl = 8'hFE;
        wait_cycles(25);
        cpu_read(1'b1, value); expect_byte("lockout release count", value, 8'h01);
        keyboard_drive = 1'b0;
        wait_cycles(25);

        // N-key special-error mode halts entry and asserts IRQ on overlap.
        cpu_write(1'b1, 8'h02);
        cpu_write(1'b1, 8'hC2);
        cpu_read(1'b1, value); expect_byte("special precondition FIFO clear", value, 8'h00);
        cpu_write(1'b1, 8'hF0);
        keyboard_drive = 1'b1;
        target_rl = 8'hFC;
        wait_cycles(50);
        cpu_read(1'b1, value);
        expect_bit("special error status", value[6], 1'b1);
        expect_bit("special error IRQ", irq, 1'b1);
        expect_byte("special error count", {5'b0, value[2:0]}, 8'h00);

        if (failures != 0) $fatal(1, "8279: %0d failures of %0d checks", failures, checks);
        $display("8279 simulation result: %0d checks, Failures: 0", checks);
        $display("TEST PASSED");
        $finish;
    end
endmodule
