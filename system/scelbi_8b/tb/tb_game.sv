// SCELBI 8B system test: boots SCELBAL, types in the Shooting Stars game
// (spec/reference/shooting_stars.bas) through the bit-banger console with
// FIFO backpressure, RUNs it, plays with sequential guesses until the game
// concedes, and declines the rematch. The secret comes from SCELBAL's own
// RND, and every check runs against the console transcript.
module tb_game;
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

    // Console transcript ring.
    reg [7:0] log [0:16383];
    integer log_n = 0;
    always @(posedge clk) begin
        if (rst_n && cpu_enable && tty_tx_strobe) begin
            log[log_n & 16383] = tty_tx_data & 8'h7f;
            log_n = log_n + 1;
        end
    end

    // True when the transcript contains `text` (len bytes) within
    // [from, to). String literals are right-aligned in the packed vector,
    // so character 0 lives in the highest byte of the literal.
    function automatic logic contains(input integer from, input integer to,
                                      input integer len, input [1023:0] text);
        integer k, j;
        begin
            contains = 1'b0;
            for (j = from; j <= to - len; j = j + 1) begin
                contains = 1'b1;
                for (k = 0; k < len; k = k + 1)
                    if (log[(j + k) & 16383] !== text[(len - k)*8 - 1 -: 8])
                        contains = 1'b0;
                if (contains) j = to;
            end
        end
    endfunction

    // Type one byte with FIFO backpressure.
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

    // Stream a program file (hex image, one byte per entry) at the machine's
    // own pace, pausing briefly every so often for line processing.
    reg [7:0] prog [0:4095];
    task automatic tty_type_file;
        integer k;
        begin
            for (k = 0; k < 4096; k = k + 1) begin
                if (prog[k] === 8'hxx || prog[k] === 8'hzz || prog[k] === 8'hff) begin
                    k = 4096;
                end else begin
                    tty_send(prog[k]);
                    if ((k & 15) == 15) repeat (40000) @(negedge clk);
                end
            end
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

    // Wait until `text` appears at or after `from` (the typed-program echo
    // would otherwise satisfy these waits early) or ~40s of machine time
    // passes, which fails the enclosing check.
    task automatic wait_for_text(input integer from, input integer len,
                                 input [1023:0] text, input integer guards);
        integer g;
        begin
            for (g = 0; g < guards; g = g + 1) begin
                if (contains(from, log_n, len, text)) g = guards;
                else repeat (100000) @(negedge clk);
            end
        end
    endtask

    // Send a decimal number.
    task automatic send_number(input integer value);
        integer d, started;
        begin
            started = 0;
            if (value >= 100) begin
                tty_send("0" + value / 100);
                started = 1;
            end
            d = (value / 10) % 10;
            if (d != 0 || started) tty_send("0" + d);
            tty_send("0" + value % 10);
            tty_send(8'h0d);
        end
    endtask

    integer m0, m1, m2, m3;
    integer i, guess;

    initial begin
        $readmemh("system/scelbi_8b/build/shooting_stars.hex", prog);
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i = 0; i < 500000; i = i + 1) @(negedge clk);

        // SCRatch, then type the whole game in.
        m0 = log_n;
        tty_send("S"); tty_send("C"); tty_send("R"); tty_send(8'h0d);
        wait_quiet(1200000);
        tty_type_file;
        wait_quiet(1200000);
        m1 = log_n;
        if (!contains(m0, m1, 5, "READY")) $fatal(1, "no READY after SCR");
        if (!contains(m0, m1, 10, "(100 * RND")) $fatal(1, "game line 290 echo missing");

        // Run: the game welcomes, offers the rules, and prompts with '?'.
        tty_send("R"); tty_send("U"); tty_send("N"); tty_send(8'h0d);
        wait_for_text(m1, 21, "TYPE 1 TO SEE RULES, ", 400);
        m2 = log_n;
        if (!contains(m1, m2, 9, "WELCOME T")) begin
            $display("DEBUG run [%0d..%0d]:", m1, log_n);
            for (i = m1; i < log_n; i = i + 1) begin
                if (log[i & 16383] == 13 || log[i & 16383] == 10) $write("\n");
                else $write("%c", log[i & 16383]);
            end
            $display("\nDEBUG end (halted=%b pc=%04x instr=%0d)", halted, pc, instruction_count);
            $fatal(1, "welcome text missing");
        end

        // Take the rules, then wait for the guess prompt.
        tty_send("1"); tty_send(8'h0d);
        wait_for_text(m2, 6, "GUESS?", 400);
        if (!contains(m2, log_n, 21, "OK, STARSEEKER, I AM TH")) $fatal(1, "game prompt missing");

        // Play: the first guess must earn at least one star hint, then count
        // upward until the game concedes.
        m3 = log_n;
        tty_send("1"); tty_send(8'h0d);
        wait_for_text(m3, 2, " *", 400);
        wait_for_text(m3, 6, "GUESS?", 600);
        if (!contains(m3, log_n, 2, " *")) $fatal(1, "no star hint for the first guess");
        for (guess = 2; guess <= 100; guess = guess + 1) begin
            send_number(guess);
            wait_for_text(m3, 9, "THAT'S IT", 600);
            if (contains(m3, log_n, 9, "THAT'S IT")) begin
                guess = 200;
            end else begin
                wait_for_text(m3, 6, "GUESS?", 600);
                m3 = log_n;
            end
        end
        if (!contains(m3, log_n, 9, "THAT'S IT")) $fatal(1, "game never conceded");

        // Win banner: the star burst and the guess count.
        if (!contains(m3, log_n, 6, "** ** ")) $fatal(1, "win star burst missing");
        wait_for_text(m3, 8, "GUESSES.", 400);
        if (!contains(m3, log_n, 8, "GUESSES.")) $fatal(1, "guess count sentence missing");

        // Decline the rematch; the game says goodbye and ENDs.
        tty_send("0"); tty_send(8'h0d);
        wait_for_text(m3, 8, "GOODBYE ", 400);
        if (!contains(m3, log_n, 8, "GOODBYE ")) $fatal(1, "goodbye text missing");
        if (halted) $fatal(1, "interpreter halted unexpectedly");

        $display("PASS: SCELBAL BASIC booted, Shooting Stars typed in, played to a win and exited (%0d instructions, %0d console bytes)",
                 instruction_count, log_n);
        $finish;
    end
endmodule
