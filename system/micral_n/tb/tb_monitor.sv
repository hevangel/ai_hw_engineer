// Micral N recovered-firmware regression: boots the original MIC-01 monitor
// ROM through the documented front-panel procedure (R2E manual II.3.1:
// substitute 44 30 3B over the fetches at PC 0/1/2 = JMP $3B30) and checks
// the monitor's documented TTY behavior over the ASR-33 card.
module tb_monitor;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic cpu_enable = 1;
    logic substitute;
    logic [7:0] switch_data;
    logic [7:0] panel_input = 0;
    logic rom_protect = 1;
    logic tty_rx_push = 0;
    logic [7:0] tty_rx_data = 0;
    logic tty_rx_full;
    logic [7:0] tty_tx_data;
    logic tty_tx_strobe;
    logic [13:0] host_mem_addr = 0;
    logic [7:0] host_mem_data = 0;
    logic host_mem_write = 0;
    logic [7:0] host_mem_read;
    logic [4:0] host_io_addr = 8;
    logic [7:0] host_io_read;
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

    micral_n dut (.*);

    // Panel entry: substitute the three bytes of JMP $3B30 into the fetches
    // at PC 0/1/2 (manual II.3.1), combinationally so the substitution lands
    // on the fetch cycle itself.
    logic [2:0] injected = 0;
    always_comb begin
        if (rst_n && cpu_enable && bus_mem_read && bus_addr == {11'd0, injected} && injected < 3) begin
            substitute = 1;
            case (injected)
                0: switch_data = 8'h44;
                1: switch_data = 8'h30;
                default: switch_data = 8'h3b;
            endcase
        end else begin
            substitute = 0;
            switch_data = 8'h00;
        end
    end
    always @(posedge clk)
        if (rst_n && cpu_enable && bus_mem_read && bus_addr == {11'd0, injected} && injected < 3)
            injected <= injected + 1;

    // TTY output log.
    logic [7:0] tty_log [0:4095];
    integer tx_n = 0;
    always @(posedge clk) begin
        if (tty_tx_strobe && tx_n < 4096) begin
            tty_log[tx_n] <= tty_tx_data;
            tx_n <= tx_n + 1;
        end
    end

    task automatic expect_output(input integer offset, input [7:0] byte_expected,
                                 input string what);
        if (offset >= tx_n || tty_log[offset] !== byte_expected)
            $fatal(1, "TTY output %0d: expected %02x (%s), got %s", offset,
                   byte_expected, what,
                   offset < tx_n ? $sformatf("%02x", tty_log[offset]) : "EOF");
    endtask

    // Push one byte for exactly one clock.
    task automatic tty_send(input [7:0] value);
        begin
            @(negedge clk);
            tty_rx_data = value;
            tty_rx_push = 1;
            @(negedge clk);
            tty_rx_push = 0;
        end
    endtask

    integer i;
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        // Give the monitor time to reach its prompt. It must print
        // CR LF SP (0x8d = CR with the monitor's software parity bit set,
        // 0x0a = LF, 0xa0 = SP with parity) through the ASR-33 card.
        for (i = 0; i < 20000 && tx_n < 3; i = i + 1) @(negedge clk);
        expect_output(0, 8'h8d, "CR with parity");
        expect_output(1, 8'h0a, "LF");
        expect_output(2, 8'ha0, "SP with parity");
        if (instruction_count < 100) $fatal(1, "monitor barely executed");

        // Unknown command 'Z': the manual (II.3.2) says a typed letter is
        // followed by ': ' and an unknown letter prints '?', which cancels.
        tty_send("Z");
        for (i = 0; i < 20000 && tx_n < 7; i = i + 1) @(negedge clk);
        expect_output(3, "Z", "echo of Z");
        expect_output(4, 8'h3a, "colon after letter");
        expect_output(5, 8'ha0, "space after colon");
        expect_output(6, 8'h3f, "unknown-command question mark");

        // The memory command 'M' prompts for an address with ': '; a CR
        // cancels the entry and the monitor prints 'M?' (manual II.3.2: CR
        // cancels), then the prompt line returns.
        tty_send("M");
        for (i = 0; i < 20000 && tx_n < 13; i = i + 1) @(negedge clk);
        expect_output(10, "M", "echo of M");
        expect_output(11, 8'h3a, "colon after M");
        expect_output(12, 8'ha0, "space after colon");
        tty_send(8'h0d);
        for (i = 0; i < 20000 && tx_n < 15; i = i + 1) @(negedge clk);
        expect_output(13, 8'h8d, "CR echo with parity");
        expect_output(14, 8'h3f, "cancel question mark");
        for (i = 0; i < 20000 && tx_n < 18; i = i + 1) @(negedge clk);
        expect_output(15, 8'h8d, "prompt CR");
        expect_output(16, 8'h0a, "prompt LF");
        expect_output(17, 8'ha0, "prompt SP");
        if (halted) $fatal(1, "monitor halted unexpectedly");
        cpu_enable = 0;
        repeat (2) @(negedge clk);
        $display("PASS: MIC-01 monitor boots via the manual panel procedure, \
prints its prompt, echoes, cancels unknown commands, and prompts for M \
(%0d instructions, %0d TTY bytes)", instruction_count, tx_n);
        $finish;
    end
endmodule
