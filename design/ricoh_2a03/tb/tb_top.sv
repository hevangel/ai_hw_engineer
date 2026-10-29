`timescale 1ns/1ps
// Directed chip-level checks for the 2A03/2A07 additions around the shared
// 6502 core: OAM DMA, DMC DMA, frame counter/IRQ, length counter, pulse,
// triangle and noise channels, $4015 and controller-port strobes.
module tb_top;
`ifdef PAL_REGION
    localparam bit REGION = 1'b1;
`else
    localparam bit REGION = 1'b0;
`endif
    localparam int S4 = REGION ? 33252 : 29828;
    localparam int S2 = REGION ? 16627 : 14913;
    localparam int S1 = REGION ? 8313 : 7457;
    logic clk = 0, rst_n = 0, irq_n = 1, nmi_n = 1;
    logic por_n;
    assign por_n = rst_n;    // every reset here is a power-on
    logic [15:0] addr_o, pc_o;
    logic [7:0] data_i, data_o, a_o, x_o, y_o, s_o, p_o;
    logic we_o, ext_rd_o, oe1_n_o, oe2_n_o, dma_o, fetch_o, jammed_o, fault_o;
    logic [2:0] out_o;
    logic [3:0] pulse1_o, pulse2_o, triangle_o, noise_o;
    logic [6:0] dmc_o;
    logic [7:0] mem [0:65535];
    int unsigned cycle, checks;
    logic [7:0] pad_bits;

    ricoh_2a03 #(.REGION(REGION)) dut (.*);

    // Board: flat RAM/ROM except the controller buffer on $4016 reads.
    always_comb begin
        data_i = mem[addr_o];
        if (!oe1_n_o) data_i = {3'b010, 4'b0000, pad_bits[0]};
    end
    always_ff @(posedge clk) if (rst_n && we_o) mem[addr_o] <= data_o;
    always_ff @(posedge clk) cycle <= rst_n ? cycle + 1 : 0;

    task automatic tick; #1 clk = 1; #1 clk = 0; endtask
    task automatic check(input bit ok, input string what);
        if (!ok) $fatal(1, "2A03 FAIL: %s (cycle %0d PC=%04x)", what, cycle, pc_o);
        checks++;
    endtask
    task automatic load_program(input logic [7:0] bytes [], input logic [15:0] at);
        foreach (bytes[i]) mem[at + 16'(i)] = bytes[i];
    endtask
    task automatic start(input logic [15:0] entry);
        mem[16'hfffc] = entry[7:0]; mem[16'hfffd] = entry[15:8];
        rst_n = 0; tick(); tick(); rst_n = 1;
    endtask
    task automatic run_until_pc(input logic [15:0] target, input int limit);
        int n = 0;
        while (!(fetch_o && pc_o == target)) begin
            tick(); n++;
            check(n < limit, $sformatf("reach PC %04x", target));
            check(!jammed_o && !fault_o, "core healthy");
        end
    endtask

    // Reference LFSR for the noise check (NESdev APU Noise).
    function automatic logic [14:0] lfsr_step(input logic [14:0] r, input bit short_mode);
        lfsr_step = {r[0] ^ (short_mode ? r[6] : r[1]), r[14:1]};
    endfunction

    initial begin
        int dma_cycles, writes, first_write, stall, hi, lo, edges, irq_cycle, fetches;
        logic [14:0] model, lfsr_before;
        logic [3:0] prev;
        logic prev_irq;
        foreach (mem[i]) mem[i] = 8'hea;
        mem[16'hfffe] = 8'h00; mem[16'hffff] = 8'h90;
        pad_bits = 8'h01;

        // ---- OAM DMA: LDA #$02; STA $4014; JMP * ----
        for (int i = 0; i < 256; i++) mem[16'h0200 + 16'(i)] = 8'(i) ^ 8'h5a;
        load_program('{8'ha9, 8'h02, 8'h8d, 8'h14, 8'h40, 8'h4c, 8'h05, 8'h80}, 16'h8000);
        start(16'h8000);
        run_until_pc(16'h8002, 20);
        while (!(we_o && addr_o == 16'h4014)) tick();
        tick();
        stall = 0; dma_cycles = 0; writes = 0;
        while (!(fetch_o && pc_o == 16'h8005 && dut.core_rdy)) begin
            if (dma_o) dma_cycles++;
            if (dma_o && we_o) begin
                check(addr_o == 16'h2004, "OAM DMA writes $2004");
                check(data_o == (8'(writes) ^ 8'h5a), "OAM DMA byte order/value");
                writes++;
            end
            if (dma_o && !we_o && writes < 256 && addr_o[15:8] == 8'h02)
                check(addr_o[7:0] == 8'(writes), "OAM DMA source address");
            stall++; tick();
            check(stall < 600, "OAM DMA terminates");
        end
        check(writes == 256, "256 OAM DMA writes");
        // Halt cycle + optional alignment + 512 transfers, then the halted
        // opcode fetch repeats: 513/514 cycles of CPU stall.
        check(stall == 513 || stall == 514, $sformatf("OAM DMA length %0d", stall));
        check(dma_cycles == stall - 1, "DMA owns every stall cycle after the halt");

        // ---- Frame IRQ: CLI; JMP *.  Handler: LDA $4015; STA $10; LDA #$40; STA $4017; RTI ----
        load_program('{8'h58, 8'h4c, 8'h01, 8'h80}, 16'h8000);
        load_program('{8'had, 8'h15, 8'h40, 8'h85, 8'h10, 8'ha9, 8'h40, 8'h8d, 8'h17, 8'h40, 8'h40}, 16'h9000);
        mem[16'h0010] = 8'h00;
        start(16'h8000);
        irq_cycle = -1; prev_irq = 0;
        while (!(fetch_o && pc_o == 16'h900a)) begin
            if (dut.apu.frame_irq && !prev_irq && irq_cycle < 0) irq_cycle = cycle;
            prev_irq = dut.apu.frame_irq;
            tick();
            check(cycle < S4 + 200, "frame IRQ handled");
        end
        // cycle counts edges after reset release; the flag is visible during
        // counter cycle S4 (counter value S4 is reached S4 edges after reset).
        check(irq_cycle == S4 + 1, $sformatf("frame IRQ flag cycle %0d", irq_cycle));
        tick(); tick();
        check(mem[16'h0010][6], "$4015 bit 6 reports frame IRQ");
        check(!dut.apu.frame_irq, "$4015 read clears frame IRQ");

        // ---- Length counter, pulse duty/period ----
        // LDA #$01 STA $4015; LDA #$BF STA $4000; LDA #$10 STA $4002; LDA #$18 STA $4003; JMP *
        load_program('{8'ha9, 8'h01, 8'h8d, 8'h15, 8'h40, 8'ha9, 8'hbf, 8'h8d, 8'h00, 8'h40,
                       8'ha9, 8'h10, 8'h8d, 8'h02, 8'h40, 8'ha9, 8'h18, 8'h8d, 8'h03, 8'h40,
                       8'h4c, 8'h14, 8'h80}, 16'h8000);
        start(16'h8000);
        run_until_pc(16'h8014, 100);
        check(dut.apu.p1_act, "pulse 1 length loaded");
        // Duty 2 (50%), period 16: 8 steps x 17 APU cycles x 2 = 272 CPU cycles.
        while (pulse1_o != 0) tick();
        while (pulse1_o == 0) tick();
        hi = 0; while (pulse1_o == 4'd15) begin hi++; tick(); end
        lo = 0; while (pulse1_o == 4'd0) begin lo++; tick(); end
        check(hi == 136 && lo == 136, $sformatf("pulse 50%% duty high=%0d low=%0d", hi, lo));
        // Halt cleared + length index 3 (=2): two half-frame clocks silence it.
        load_program('{8'ha9, 8'h9f, 8'h8d, 8'h00, 8'h40, 8'ha9, 8'h18, 8'h8d, 8'h03, 8'h40,
                       8'h4c, 8'h2a, 8'h80}, 16'h8020);
        load_program('{8'ha9, 8'h01, 8'h8d, 8'h15, 8'h40, 8'h4c, 8'h20, 8'h80}, 16'h8000);
        start(16'h8000);
        run_until_pc(16'h802a, 100);
        check(dut.apu.p1_act, "length 2 loaded");
        while (cycle < S2 + 2) tick();
        check(dut.apu.p1_act, "one half-frame leaves length 1");
        while (cycle < S4 + 4) tick();
        check(!dut.apu.p1_act && pulse1_o == 0, "second half-frame silences pulse 1");

        // ---- Triangle: linear 127, period 0x20, 32-step sequence every CPU cycle ----
        // LDA #$04 STA $4015; LDA #$FF STA $4008; LDA #$20 STA $400A; LDA #$08 STA $400B; JMP *
        load_program('{8'ha9, 8'h04, 8'h8d, 8'h15, 8'h40, 8'ha9, 8'hff, 8'h8d, 8'h08, 8'h40,
                       8'ha9, 8'h20, 8'h8d, 8'h0a, 8'h40, 8'ha9, 8'h08, 8'h8d, 8'h0b, 8'h40,
                       8'h4c, 8'h14, 8'h80}, 16'h8000);
        start(16'h8000);
        run_until_pc(16'h8014, 100);
        while (cycle < S1 + 100) tick();      // first quarter frame loads the linear counter
        prev = triangle_o; edges = 0; hi = 0;
        for (int i = 0; i < 33 * 32; i++) begin
            tick();
            if (triangle_o != prev) begin
                check(triangle_o == prev + 1 || triangle_o == prev - 1 ||
                      triangle_o == prev, "triangle steps by one");
                edges++;
            end
            prev = triangle_o;
        end
        // 33 CPU cycles per step; 32 steps include two repeated levels (0 and 15).
        check(edges == 30, $sformatf("triangle level changes %0d", edges));

        // ---- Noise: constant volume 15, period index 0, long mode ----
        // LDA #$08 STA $4015; LDA #$3F STA $400C; LDA #$00 STA $400E; LDA #$08 STA $400F; JMP *
        load_program('{8'ha9, 8'h08, 8'h8d, 8'h15, 8'h40, 8'ha9, 8'h3f, 8'h8d, 8'h0c, 8'h40,
                       8'ha9, 8'h00, 8'h8d, 8'h0e, 8'h40, 8'ha9, 8'h08, 8'h8d, 8'h0f, 8'h40,
                       8'h4c, 8'h14, 8'h80}, 16'h8000);
        start(16'h8000);
        run_until_pc(16'h8014, 100);
        model = dut.apu.noise.lfsr;
        for (int i = 0; i < 2000; i++) begin
            lfsr_before = dut.apu.noise.lfsr;
            tick();
            if (dut.apu.noise.lfsr != lfsr_before) begin
                model = lfsr_step(model, 1'b0);
                check(dut.apu.noise.lfsr == model, "noise LFSR matches reference sequence");
            end
            check(noise_o == (model[0] ? 4'd0 : 4'd15), "noise output gating");
        end

        // ---- DMC DMA: rate F, $C000, 17 bytes, IRQ ----
        // LDA #$8F STA $4010; LDA #$00 STA $4012; LDA #$01 STA $4013; LDA #$10 STA $4015; JMP *
        for (int i = 0; i < 17; i++) mem[16'hc000 + 16'(i)] = 8'hff;
        load_program('{8'ha9, 8'h8f, 8'h8d, 8'h10, 8'h40, 8'ha9, 8'h00, 8'h8d, 8'h12, 8'h40,
                       8'ha9, 8'h01, 8'h8d, 8'h13, 8'h40, 8'ha9, 8'h10, 8'h8d, 8'h15, 8'h40,
                       8'h4c, 8'h14, 8'h80}, 16'h8000);
        start(16'h8000);
        fetches = 0;
        while (cycle < 17 * 8 * 54 + 400) begin
            if (dma_o && !we_o && addr_o >= 16'hc000) begin
                check(addr_o == 16'hc000 + 16'(fetches), "DMC sample address sequence");
                fetches++;
            end
            tick();
        end
        check(fetches == 17, $sformatf("DMC fetched %0d bytes", fetches));
        check(dut.apu.dmc_irq && !dut.apu.dmc_act, "DMC IRQ at end of sample");
        check(dmc_o > 7'd60, "DMC level rises with all-ones samples");

        // ---- Controller port: LDA #$01 STA $4016; LDA $4016; STA $20; JMP * ----
        load_program('{8'ha9, 8'h01, 8'h8d, 8'h16, 8'h40, 8'had, 8'h16, 8'h40, 8'h85, 8'h20,
                       8'h4c, 8'h0a, 8'h80}, 16'h8000);
        start(16'h8000);
        edges = 0;
        while (!(fetch_o && pc_o == 16'h800a)) begin
            if (!oe1_n_o) begin edges++; check(addr_o == 16'h4016 && !we_o, "/OE1 only on $4016 reads"); end
            check(oe2_n_o, "/OE2 idle");
            tick();
        end
        check(out_o == 3'b001, "OUT0 latched by $4016 write");
        check(edges == 1, "single /OE1 strobe");
        check(mem[16'h0020] == 8'h41, "D0 from port with open-bus upper bits");

        $display("RICOH 2A03 TB PASS: region=%0d checks=%0d", REGION, checks);
        $finish;
    end
endmodule
