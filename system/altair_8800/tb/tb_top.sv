// Altair 8800 board testbench: front-panel deposit/run/examine of the
// Operator's Manual add program, protect, single step, 88-SIO echo and
// sense-switch input. Source: spec/spec.md.
`timescale 1ns/1ps
module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic run_sw = 0;
    logic step_sw = 0, examine_sw = 0, examine_next_sw = 0;
    logic deposit_sw = 0, deposit_next_sw = 0;
    logic reset_sw = 0, clr_sw = 0, protect_sw = 0, unprotect_sw = 0;
    logic [15:0] address_sw = 0;
    logic [7:0] data_sw = 0;
    logic [7:0] tty_in_data = 0;
    logic tty_in_we = 0;
    logic tty_in_ready;
    logic [15:0] tty_tx_delay = 300;
    logic tty_out_we;
    logic [7:0] tty_out_data;
    logic [15:0] host_mem_addr = 0;
    logic [7:0] host_mem_rdata;
    logic [15:0] lamp_addr, display_addr, cpu_pc, cpu_sp;
    logic [7:0] lamp_data, lamp_status, cpu_flags;
    logic lamp_inte, lamp_hlda, lamp_prot, lamp_wait, lamp_hlta;
    logic running, halted, protect_lamp, fault, retired;
    logic [55:0] cpu_regs;
    logic [31:0] cycle_count, instruction_count;
    logic [11:0] rx_count;

    altair_8800 #(.RAM_KIB(16)) dut (.*);

    logic [7:0] last_tx;
    logic got_tx = 0;
    always @(posedge clk) if (tty_out_we) begin
        last_tx <= tty_out_data;
        got_tx <= 1'b1;
    end

    task automatic tick(int n = 1);
        repeat (n) @(negedge clk);
    endtask

    task automatic read_mem(input logic [15:0] addr, output logic [7:0] value);
        begin
            host_mem_addr = addr;
            #1;
            value = host_mem_rdata;
        end
    endtask

    task automatic do_reset;
        begin
            @(negedge clk) reset_sw = 1;
            @(negedge clk) reset_sw = 0;
            tick(6);
        end
    endtask

    task automatic do_examine(input logic [15:0] addr);
        begin
            @(negedge clk) begin
                address_sw = addr;
                examine_sw = 1;
            end
            @(negedge clk) examine_sw = 0;
            tick();
        end
    endtask

    // EXAMINE the address, then DEPOSIT the data switch byte there.
    task automatic do_deposit(input logic [15:0] addr, input logic [7:0] value);
        begin
            do_examine(addr);
            @(negedge clk) begin
                data_sw = value;
                deposit_sw = 1;
            end
            @(negedge clk) deposit_sw = 0;
            tick();
        end
    endtask

    task automatic do_deposit_next(input logic [7:0] value);
        begin
            @(negedge clk) begin
                data_sw = value;
                deposit_next_sw = 1;
            end
            @(negedge clk) deposit_next_sw = 0;
            tick();
        end
    endtask

    task automatic do_step;
        begin
            @(negedge clk) step_sw = 1;
            tick(); // one tick latches stepping and clears any stale retire
            repeat (1000) begin
                tick();
                if (retired) break;
            end
            if (!retired) $fatal(1, "single step did not retire an instruction");
            @(negedge clk) step_sw = 0;
            tick(3);
        end
    endtask

    task automatic deposit_seq(input logic [15:0] addr, input byte seq[]);
        begin
            do_deposit(addr, seq[0]);
            for (int i = 1; i < seq.size(); ++i) do_deposit_next(seq[i]);
        end
    endtask

    logic [7:0] value;
    logic [31:0] instructions_before;
    initial begin
        tick(2);
        rst_n = 1;
        tick(2);

        // Stopped machine grants the panel the bus (HLDA lamp on).
        if (!lamp_hlda) $fatal(1, "HLDA lamp must light when stopped");

        // Operator's Manual add program: (0200)+(0201)->(0202), octal.
        do_reset();
        deposit_seq(16'h0000, '{8'h3a, 8'h80, 8'h00, 8'h47, 8'h3a, 8'h81,
                                8'h00, 8'h80, 8'h32, 8'h82, 8'h00, 8'hc3,
                                8'h00, 8'h00});
        // Operands 12 and 34 through DEPOSIT / DEPOSIT NEXT.
        do_deposit(16'h0080, 8'd12);
        do_deposit_next(8'd34);
        read_mem(16'h0080, value);
        if (value != 8'd12) $fatal(1, "panel deposit did not store operand 1");
        read_mem(16'h0081, value);
        if (value != 8'd34) $fatal(1, "panel deposit did not store operand 2");
        if (lamp_addr != 16'h81 || lamp_data != 8'd34)
            $fatal(1, "deposit next did not advance and display address 0x81");

        // RESET then RUN; the program loops forever, so run, stop, examine.
        do_reset();
        if (cpu_pc != 16'h0000) $fatal(1, "RESET must set the program counter to 0");
        @(negedge clk) run_sw = 1;
        tick(3000);
        @(negedge clk) run_sw = 0;
        tick(6);
        if (!lamp_hlda) $fatal(1, "STOP must be acknowledged by HLDA");
        do_examine(16'h0082);
        if (lamp_data != 8'd46) $fatal(1, "add program produced %0d, expected 46", lamp_data);
        read_mem(16'h0082, value);
        if (value != 8'd46) $fatal(1, "memory result wrong");

        // PROTECT blocks panel deposits; UNPROTECT restores them.
        @(negedge clk) protect_sw = 1;
        @(negedge clk) protect_sw = 0;
        tick();
        if (!lamp_prot) $fatal(1, "PROT lamp must light");
        do_deposit(16'h0082, 8'hff);
        read_mem(16'h0082, value);
        if (value != 8'd46) $fatal(1, "protected memory accepted a deposit");
        @(negedge clk) unprotect_sw = 1;
        @(negedge clk) unprotect_sw = 0;
        tick();
        do_deposit(16'h0082, 8'h55);
        read_mem(16'h0082, value);
        if (value != 8'h55) $fatal(1, "unprotect did not allow deposits");

        // Single step: each actuation retires exactly one instruction and
        // completes the next instruction's M1 opcode fetch (the original
        // panel stops at the next M1), so PC lands inside the next opcode.
        do_reset();
        deposit_seq(16'h0000, '{8'h3a, 8'h80, 8'h00, 8'h00});
        do_reset();
        if (dut.stepping) $fatal(1, "stepping must be idle when stopped");
        instructions_before = instruction_count;
        do_step();
        if (cpu_pc != 16'h0004 || cpu_regs[55:48] != 8'd12 ||
            instruction_count != instructions_before + 1)
            $fatal(1, "first step did not complete LDA (pc=%0h a=%0h n=%0d)",
                   cpu_pc, cpu_regs[55:48], instruction_count);
        do_step();
        if (cpu_pc != 16'h0005 || instruction_count != instructions_before + 2)
            $fatal(1, "second step did not execute NOP (pc=%0h n=%0d)",
                   cpu_pc, instruction_count);
        if (!lamp_hlda) $fatal(1, "panel must regain the bus after a step");

        // 88-SIO echo loop: IN 00/ANI 01/JNZ, IN 01, OUT 01, JMP.
        do_reset();
        deposit_seq(16'h0000, '{8'hdb, 8'h00, 8'he6, 8'h01, 8'hc2, 8'h00,
                                8'h00, 8'hdb, 8'h01, 8'hd3, 8'h01, 8'hc3,
                                8'h00, 8'h00});
        do_reset();
        got_tx = 0;
        @(negedge clk) run_sw = 1;
        tick(4);
        // Console input arrives; software polls status bit 0 for it.
        @(negedge clk) begin
            tty_in_data = 8'h41;
            tty_in_we = 1;
        end
        @(negedge clk) tty_in_we = 0;
        repeat (6000) begin
            tick();
            if (got_tx) break;
        end
        if (!got_tx || last_tx != 8'h41)
            $fatal(1, "88-SIO echo failed (tx=%0h)", last_tx);

        // STOP so the panel can deposit the next program.
        @(negedge clk) run_sw = 0;
        tick(6);
        if (!lamp_hlda) $fatal(1, "panel must regain the bus after STOP");

        // Sense switches: upper address switches read at port FFh.
        do_reset();
        deposit_seq(16'h0000, '{8'hdb, 8'hff, 8'h32, 8'h10, 8'h00, 8'h76});
        @(negedge clk) address_sw = 16'hab00;
        do_reset();
        @(negedge clk) run_sw = 1;
        tick(2000);
        read_mem(16'h0010, value);
        if (value != 8'hab) $fatal(1, "sense switch input failed (got %0h)", value);
        if (!lamp_hlta) $fatal(1, "HALT must light the HLTA lamp");

        $display("PASS: Altair 8800 board panel, SIO and sense-switch checks");
        $finish;
    end
endmodule
