// Micral N front-panel semantics at the RTL level (review M5): SUB
// substitution of the instruction stream, single-cycle stepping, the 8-tick
// STEP bound every instruction must respect, TRAP stop-at-PC, and INIT
// reset. The R2E manual section VI is the source for the control meanings.
module tb_panel;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic cpu_enable = 0;
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
    logic [13:0] pc, bus_addr;
    logic [7:0] accumulator, bus_data, last_output_data;
    logic [3:0] flags;
    logic halted, retired, bus_mem_read, bus_write, bus_io_read, bus_io_write;
    logic [4:0] last_output_port;
    logic [31:0] cycle_count, instruction_count;

    micral_n dut (.*);

    // SUB drives the data switches onto the bus for as long as it is on;
    // here it is armed for one fetch at sub_pc.
    logic sub_armed = 0;
    logic [13:0] sub_pc = 0;
    logic sub_done = 0;
    always_comb begin
        if (sub_armed && !sub_done && bus_mem_read && bus_addr == sub_pc) begin
            substitute = 1;
            switch_data = 8'hff; // HLT
        end else begin
            substitute = 0;
            switch_data = 8'h00;
        end
    end
    always @(posedge clk)
        if (sub_armed && !sub_done && bus_mem_read && bus_addr == sub_pc)
            sub_done <= 1;

    integer guard, k, ticks;
    logic [13:0] trap;

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Single-cycle stepping (the panel's cycle step): one enabled clock
        // per press advances the fetch by exactly one byte.
        cpu_enable = 1; @(negedge clk); cpu_enable = 0;
        if (pc !== 14'd1) $fatal(1, "cycle step 1: pc %04x", pc);
        cpu_enable = 1; @(negedge clk); cpu_enable = 0;
        if (pc !== 14'd2) $fatal(1, "cycle step 2: pc %04x", pc);
        cpu_enable = 1; @(negedge clk); cpu_enable = 0;
        cpu_enable = 1; @(negedge clk); cpu_enable = 0;
        if (pc !== 14'd4) $fatal(1, "cycle step 4: pc %04x", pc);
        if (instruction_count !== 32'd2) $fatal(1, "two instructions after cycle steps: %0d",
                                               instruction_count);

        // Instruction STEP bound: no instruction may need more than 8
        // enabled clocks (the host STEP applies exactly this bound).
        cpu_enable = 1;
        ticks = 0;
        for (k = 0; k < 3000; k = k + 1) begin
            @(negedge clk);
            ticks = ticks + 1;
            if (retired) begin
                if (ticks > 8) $fatal(1, "instruction needed %0d ticks", ticks);
                ticks = 0;
            end
        end
        cpu_enable = 0;
        @(negedge clk);

        // TRAP: stop the first time an instruction retires with pc == trap
        // (post-retirement PC, as the host simulator applies it). The demo's
        // wait loop is LAI/INP/OR/JTZ at pc 3-6; trap right after the INP.
        trap = 14'd5;
        guard = 0;
        cpu_enable = 1;
        while (guard < 100000) begin
            @(negedge clk);
            guard = guard + 1;
            if (retired && pc == trap) begin
                cpu_enable = 0;
                break;
            end
        end
        if (guard >= 100000) $fatal(1, "TRAP at %04x never hit", trap);
        if (pc !== trap) $fatal(1, "TRAP stopped at %04x", pc);

        // SUB: substitute an HLT into the fetch at pc 3, then run. The CPU
        // must execute the substituted byte, not memory.
        repeat (2) @(negedge clk);
        sub_armed = 1;
        sub_pc = 14'd3;
        cpu_enable = 1;
        guard = 0;
        while (guard < 1000 && !halted) begin
            @(negedge clk);
            guard = guard + 1;
        end
        if (!halted) $fatal(1, "SUBstituted HLT did not halt the CPU");
        cpu_enable = 0;
        sub_armed = 0;

        // INIT: synchronous reset clears PC and counters even after SUB.
        rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        if (pc !== 14'd0) $fatal(1, "INIT left pc at %04x", pc);
        if (instruction_count !== 32'd0) $fatal(1, "INIT left instruction_count %0d",
                                                instruction_count);
        if (halted) $fatal(1, "INIT left the CPU halted");

        // POKE while running must not swallow anything (review M2): the
        // board stalls the CPU during host writes, so the poke lands and the
        // CPU resumes afterwards.
        cpu_enable = 1;
        host_mem_write = 1;
        host_mem_addr = 14'h1000;
        host_mem_data = 8'h5a;
        @(negedge clk);
        host_mem_write = 0;
        @(negedge clk);
        cpu_enable = 0;
        @(negedge clk);
        host_mem_addr = 14'h1000;
        #1;
        if (host_mem_read !== 8'h5a) $fatal(1, "POKE lost while running");
        if (instruction_count == 32'd0) $fatal(1, "CPU did not resume after POKE");

        $display("PASS: cycle step, STEP bound, TRAP, SUB HLT, INIT, and POKE-while-running all behave at the RTL level");
        $finish;
    end
endmodule
