// Space Invaders board testbench. Boots the original ROM, checks both
// interrupt vectors execute, the watchdog stays fed, the shift register
// matches the hardware page example, and a coin inserts a credit in work
// RAM. Source: spec/spec.md.
`timescale 1ns/1ps
module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic run_sw = 0, step_sw = 0, reset_sw = 0, freeze = 0;
    logic [7:0] in0 = 0, in1 = 0, in2 = 0;
    logic [12:0] host_vram_addr = 0;
    logic [7:0] host_vram_rdata;
    logic [15:0] host_mem_addr = 0;
    logic [7:0] host_mem_rdata;
    logic snd3_we, snd5_we;
    logic [7:0] snd3_data, snd5_data;
    logic running, halted, fault;
    logic [15:0] cpu_pc, cpu_sp, shift_reg;
    logic [55:0] cpu_regs;
    logic [7:0] cpu_flags;
    logic [2:0] shift_offset;
    logic retired;
    logic [31:0] cycle_count, instruction_count, frame_count,
                 interrupt_count, watchdog_reset_count;

    space_invaders dut (.*);

    // Both ISRs must be entered through their vectors.
    logic hit_rst8 = 0, hit_rst10 = 0;
    always @(posedge clk) begin
        if (cpu_pc == 16'h0008) hit_rst8 <= 1'b1;
        if (cpu_pc == 16'h0010) hit_rst10 <= 1'b1;
    end

    // Shift-register unit test instance (same module as the board uses).
    logic sh_data_we = 0, sh_off_we = 0;
    logic [7:0] sh_data = 0, sh_bus = 0;
    logic [15:0] sh_reg;
    logic [2:0] sh_off;
    logic [7:0] sh_result;
    si_shift shifter (.clk, .rst_n(rst_n), .data_we(sh_data_we), .data(sh_data),
                      .offset_we(sh_off_we), .offset_bus(sh_bus),
                      .shift_reg(sh_reg), .shift_offset(sh_off), .result(sh_result));

    task automatic tick(int n = 1);
        repeat (n) @(negedge clk);
    endtask

    task automatic run_machine(int cycles);
        begin
            repeat (cycles) @(negedge clk);
        end
    endtask

    task automatic peek(input logic [15:0] addr, output logic [7:0] value);
        begin
            host_mem_addr = addr;
            #1;
            value = host_mem_rdata;
        end
    endtask

    logic [7:0] vram_or;
    integer i;
    logic [7:0] expected [0:7];
    logic [7:0] credit;
    initial begin
        // reg 0xFFAA read at offsets 0..7: result = reg >> (8-offset).
        expected[0] = 8'hff; expected[1] = 8'hff; expected[2] = 8'hfe;
        expected[3] = 8'hfd; expected[4] = 8'hfa; expected[5] = 8'hf5;
        expected[6] = 8'hea; expected[7] = 8'hd5;

        tick(2);
        rst_n = 1;
        tick(2);

        // ---- Shift register: hardware page example (00 -> AA -> FF).
        @(negedge clk) begin sh_data = 8'h00; sh_data_we = 1; end
        @(negedge clk) begin sh_data = 8'haa; end
        @(negedge clk) begin sh_data = 8'hff; end
        @(negedge clk) sh_data_we = 0;
        tick();
        if (sh_reg !== 16'hffaa)
            $fatal(1, "shift register sequence wrong: %04x", sh_reg);
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk) begin sh_bus = i[7:0]; sh_off_we = 1; end
            @(negedge clk) sh_off_we = 0;
            tick();
            if (sh_result !== expected[i])
                $fatal(1, "shift offset %0d read %02x expected %02x",
                       i, sh_result, expected[i]);
        end

        // ---- Boot the original ROM.
        @(negedge clk) reset_sw = 1;
        @(negedge clk) reset_sw = 0;
        tick(6);
        @(negedge clk) run_sw = 1;
        run_machine(3_000_000);

        if (!hit_rst8) $fatal(1, "RST 8 ISR at 0008h was never entered");
        if (!hit_rst10) $fatal(1, "RST 10 ISR at 0010h was never entered");
        if (frame_count == 0) $fatal(1, "no frames elapsed");
        // Two events fire per frame, but the CPU only accepts them with
        // INTE=1: the boot phase runs DI and longer ISR bodies mask the
        // next event, as on real hardware. Require both vectors served
        // and near-steady-state delivery.
        if (interrupt_count < 2 * frame_count - 20)
            $fatal(1, "interrupts=%0d too few for frames=%0d",
                   interrupt_count, frame_count);
        if (watchdog_reset_count != 0)
            $fatal(1, "watchdog fired %0d times during boot/attract",
                   watchdog_reset_count);
        if (fault) $fatal(1, "CPU fault (undefined opcode path)");
        if (halted) $fatal(1, "CPU halted during boot");
        if (instruction_count < 100000)
            $fatal(1, "only %0d instructions executed", instruction_count);

        // Attract mode has drawn something into VRAM.
        vram_or = 0;
        for (i = 0; i < 7168; i = i + 1) begin
            host_vram_addr = i[12:0];
            #1;
            vram_or = vram_or | host_vram_rdata;
        end
        if (vram_or == 8'h00) $fatal(1, "VRAM empty after 3M cycles");

        // ---- Coin inserts a credit (BCD counter at 20EBh).
        @(negedge clk) in1 = 8'h01;    // CREDIT bit
        run_machine(200_000);
        @(negedge clk) in1 = 8'h00;
        run_machine(400_000);
        peek(16'h20eb, credit);
        if (credit != 8'h01)
            $fatal(1, "coin did not increment credit (20EB=%02x)", credit);
        if (watchdog_reset_count != 0)
            $fatal(1, "watchdog fired during coin handling");

        run_sw = 0;
        tick(6);
        $display("PASS: Space Invaders board boot, interrupts (%0d), frames (%0d), shift register, coin credit",
                 interrupt_count, frame_count);
        $finish;
    end
endmodule
