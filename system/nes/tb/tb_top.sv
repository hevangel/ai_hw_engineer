// NES board testbench: clock relationships, frame period, and nestest in
// automation mode (+prg/+chr from scripts/prepare_rom.py with --entry C000)
// running to its final instruction with both result bytes clear.
/* verilator lint_off BLKSEQ */
module tb_top;
    logic clk, rst_n;
    initial begin clk = 0; rst_n = 0; end
    always #1 clk = !clk;       // master clock (one tick per half period)

    logic [5:0] pixel;
    logic [2:0] emphasis, exp_out;
    logic pixel_valid, frame_odd, cpu_clk, cpu_tick, nmi_n;
    logic [8:0] scanline, dot;
    logic [3:0] pulse1, pulse2, triangle, noise;
    logic [6:0] dmc;
    logic [15:0] cpu_addr, cpu_pc, host_addr;
    logic [7:0] cpu_data, cpu_a, cpu_x, cpu_y, cpu_s, cpu_p, host_rdata;
    logic cpu_we, cpu_fetch, cpu_dma, cpu_jammed, cpu_fault;

    nes dut (
        .clk, .rst_n, .por_n(rst_n), .mapper_i(8'd0), .mirror_v_i(1'b0), .chr_ram_i(1'b0),
        .prg_mask_i(19'h3fff), .chr_mask_i(18'h1fff), .pad1_i(8'h00), .pad2_i(8'h00),
        .pixel, .emphasis, .pixel_valid, .scanline, .dot, .frame_odd,
        .pulse1, .pulse2, .triangle, .noise, .dmc,
        .cpu_clk, .cpu_tick, .cpu_addr, .cpu_data, .cpu_we, .cpu_fetch, .cpu_dma,
        .cpu_jammed, .cpu_fault, .exp_out, .cpu_pc, .cpu_a, .cpu_x, .cpu_y, .cpu_s, .cpu_p,
        .nmi_n, .host_addr, .host_rdata
    );

    int errors, checks;
    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) begin errors++; $display("FAIL: %s", what); end
    endtask

    // Count master clocks per CPU cycle and per PPU dot.
    longint ticks, cpu_cycles, dots;
    initial begin errors = 0; checks = 0; ticks = 0; cpu_cycles = 0; dots = 0; end
    always @(posedge clk) if (rst_n) begin
        ticks++;
        if (dut.cpu_tick) cpu_cycles++;
        if (dut.dot_ce) dots++;
    end

    initial begin
        longint frame_start, frame_dots, instructions;
        bit reached_end;
        host_addr = 0;
        repeat (64) @(posedge clk);
        rst_n = 1;

        // nestest automation: the log's last instruction is at $C66E.
        reached_end = 0;
        instructions = 0;
        while (!reached_end && instructions < 20000 && !cpu_jammed) begin
            @(posedge clk);
            if (dut.cpu_tick && cpu_fetch && !cpu_dma) begin
                instructions++;
                if (cpu_addr == 16'hc66e) reached_end = 1;
            end
        end
        check(reached_end, $sformatf("nestest reached $C66E (%0d instructions)", instructions));
        host_addr = 16'h0002; #1;
        check(host_rdata == 8'h00, $sformatf("nestest official result $02 = %02x", host_rdata));
        host_addr = 16'h0003; #1;
        check(host_rdata == 8'h00, $sformatf("nestest unofficial result $03 = %02x", host_rdata));
        check(!cpu_fault, "CPU core fault");

        // Ratios: 12 master clocks per CPU cycle, 4 per dot.
        frame_start = cpu_cycles; frame_dots = dots;
        repeat (12000) @(posedge clk);
        frame_start = cpu_cycles - frame_start; frame_dots = dots - frame_dots;
        check(frame_start == 1000, $sformatf("CPU clock ratio (%0d cycles / 12000)", frame_start));
        check(frame_dots == 3000, $sformatf("PPU dot ratio (%0d dots / 12000)", frame_dots));

        // Frame period with rendering off: 262 x 341 dots, no odd-frame skip.
        wait (scanline == 9'd241 && dot == 9'd1);
        @(posedge clk);
        frame_start = dots;
        wait (scanline == 9'd240);
        wait (scanline == 9'd241 && dot == 9'd1);
        @(posedge clk);
        frame_dots = dots - frame_start;
        check(frame_dots == 262 * 341, $sformatf("frame period %0d dots", frame_dots));


        if (errors == 0) $display("PASS: NES board testbench (%0d checks)", checks);
        else $display("FAIL: %0d of %0d checks", errors, checks);
        $finish;
    end
endmodule
