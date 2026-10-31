// SCELBI 8B boot test: after reset SCELBAL signs on, accepts the SIMH
// guide's example program, and computes the floating-point result.
module tb_calc;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic cpu_enable = 1;
    logic tty_rx_push = 0;
    logic [7:0] tty_rx_data = 0;
    logic tty_rx_full;
    logic [7:0] tty_tx_data;
    logic tty_tx_strobe;
    logic [13:0] host_mem_addr = 0;
    logic [7:0] host_mem_data = 0;
    logic host_mem_write = 0;
    logic [7:0] host_mem_read;
    logic [13:0] pc;
    logic [7:0] accumulator;
    logic [3:0] flags;
    logic halted, retired;
    logic [13:0] bus_addr;
    logic [7:0] bus_data;
    logic bus_mem_read, bus_write, bus_io_read, bus_io_write;
    logic [4:0] last_output_port;
    logic [7:0] last_output_data;
    logic [31:0] cycle_count, instruction_count;

    scelbi_8b dut (.*);

    reg [7:0] log [0:4095];
    integer log_n = 0;
    always @(posedge clk) begin
        if (rst_n && cpu_enable && tty_tx_strobe) begin
            log[log_n & 4095] = tty_tx_data & 8'h7f;
            log_n = log_n + 1;
        end
    end

    function automatic logic contains(input integer from, input integer to,
                                      input integer len, input [1023:0] text);
        integer k, j;
        begin
            contains = 1'b0;
            for (j = from; j <= to - len; j = j + 1) begin
                contains = 1'b1;
                for (k = 0; k < len; k = k + 1)
                    if (log[(j + k) & 4095] !== text[(len - k)*8 - 1 -: 8])
                        contains = 1'b0;
                if (contains) j = to;
            end
        end
    endfunction

    task automatic tty_send(input [7:0] value);
        begin
            @(negedge clk);
            while (tty_rx_full) @(negedge clk);
            tty_rx_data = value;
            tty_rx_push = 1;
            @(negedge clk);
            tty_rx_push = 0;
        end
    endtask

    task automatic wait_quiet(input integer cycles);
        integer k, last;
        begin
            last = log_n;
            for (k = 0; k < cycles; k = k + 1) begin
                @(negedge clk);
                if (log_n != last) begin
                    last = log_n;
                    k = 0;
                end
            end
        end
    endtask

    integer m0, m1;
    integer i;
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i = 0; i < 500000; i = i + 1) @(negedge clk);
        m0 = log_n;

        // The SIMH SCELBI guide's example session, exactly.
        tty_send("S"); tty_send("C"); tty_send("R"); tty_send(8'h0d);
        wait_quiet(400000);
        if (!contains(m0, log_n, 5, "READY")) $fatal(1, "no READY after boot and SCR");
        m1 = log_n;
        tty_send("1"); tty_send("0"); tty_send(" "); tty_send("A"); tty_send("=");
        tty_send("1"); tty_send(8'h0d);
        wait_quiet(300000);
        tty_send("2"); tty_send("0"); tty_send(" "); tty_send("B"); tty_send("=");
        tty_send("7"); tty_send(8'h0d);
        wait_quiet(300000);
        tty_send("3"); tty_send("0"); tty_send(" "); tty_send("P"); tty_send("R");
        tty_send("I"); tty_send("N"); tty_send("T"); tty_send(" "); tty_send("\"");
        tty_send("A"); tty_send(" "); tty_send("+"); tty_send(" "); tty_send("B");
        tty_send(" "); tty_send("="); tty_send("\""); tty_send(";");
        tty_send(8'h0d);
        wait_quiet(300000);
        tty_send("4"); tty_send("0"); tty_send(" "); tty_send("P"); tty_send("R");
        tty_send("I"); tty_send("N"); tty_send("T"); tty_send(" "); tty_send("A");
        tty_send("+"); tty_send("B"); tty_send(8'h0d);
        wait_quiet(300000);
        tty_send("R"); tty_send("U"); tty_send("N"); tty_send(8'h0d);
        wait_quiet(600000);
        if (!contains(m1, log_n, 7, "A + B =")) $fatal(1, "PRINT string missing");
        if (!contains(m1, log_n, 3, "8.0")) $fatal(1, "floating point result missing");
        if (halted) $fatal(1, "interpreter halted unexpectedly");
        $display("PASS: SCELBAL READY, program entry, LIST-less RUN computed A + B = 8.0 (%0d instructions)",
                 instruction_count);
        $finish;
    end
endmodule
