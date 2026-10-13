// Included inside mos_6502 under `ifdef FORMAL; bus_data_i/irq_n/nmi_n stay
// free inputs. Safety properties: bus discipline, fault containment,
// interrupt-vector muxing, stack addressing, and bounded progress.
`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) assume(!rst_n);
    end

    // Progress watchdog: after leaving FETCH the sequencer must reach the
    // next opcode fetch (or a documented fault) within 40 cycles, whatever
    // the bus returns. Every documented-opcode path is an unconditional
    // state chain, so this proves the core cannot deadlock on any memory
    // image. Enabled only in the bmc task (bounded check by design).
`ifdef FORMAL_BMC
    logic [6:0] progress_cnt = 0;
    always_ff @(posedge clk) begin
        if (!rst_n) progress_cnt <= 0;
        else if (state == S_FETCH) progress_cnt <= 0;
        else if (state != S_FAULT) progress_cnt <= progress_cnt + 7'd1;
    end
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            if (!f_undoc(opcode)) begin
                assert(progress_cnt <= 7'd40);
            end else begin
                // undocumented opcode: fetch must fault within 2 cycles
                if (progress_cnt > 7'd2) assert(0);
            end
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            // Reset sequence: the vector lives at FFFC/FFFD
            if (state == S_RST_L) assert(bus_addr == 16'hfffc);
            if (state == S_RST_H) assert(bus_addr == 16'hfffd);

            // Fetch discipline: opcode fetch reads the PC and never writes
            if (state == S_FETCH) begin
                assert(!bus_we);
                assert(bus_addr == pc);
            end

            // Fault containment: only undocumented opcodes fault, the fault
            // state is terminal, and an IRQ/BRK hijack (opcode forced to 00,
            // documented) can never lead there.
            if (state == S_FAULT) begin
                assert(f_undoc(opcode));
                assert(bus_we == 1'b0);
            end
            if (past_valid && $past(rst_n) && $past(state) == S_FAULT)
                assert(state == S_FAULT);

            // Interrupt vector mux: NMI -> FFFA/B, IRQ/BRK -> FFFE/F, and
            // the choice is latched from int_nmi_q, not re-sampled.
            if (state == S_VEC_L)
                assert(bus_addr == (int_nmi_q ? 16'hfffa : 16'hfffe));
            if (state == S_VEC_H)
                assert(bus_addr == (int_nmi_q ? 16'hfffb : 16'hffff));

            // Stack discipline: pushes write page 1 at S; pulls read page 1
            // at S+1 (the pre-increment pull address). STA/RMW stores target
            // memory and are excluded.
            if (bus_we && (state == S_PSH || state == S_JSR_PH ||
                           state == S_JSR_PL || state == S_BRK_PH ||
                           state == S_BRK_PL || state == S_BRK_PS))
                assert(bus_addr == {8'h01, s});
            if (state == S_PUL || state == S_RTS_L || state == S_RTS_H ||
                state == S_RTI_P || state == S_RTI_L || state == S_RTI_H)
                assert(bus_addr == {8'h01, s + 8'd1});

            // B-flag push rules: BRK pushes B=1, hardware IRQ pushes B=0;
            // bit 5 always pushes as 1 (BRK_PS drives the byte).
            if (state == S_BRK_PS) begin
                if (brk_is_brk) assert(bus_data_o[4] == 1'b1);
                else            assert(bus_data_o[4] == 1'b0);
                assert(bus_data_o[5] == 1'b1);
            end
            if (state == S_PSH && op == O_PHP) begin
                assert(bus_data_o[4] == 1'b1);
                assert(bus_data_o[5] == 1'b1);
            end
            if (state == S_PSH && op == O_PHA)
                assert(bus_data_o == a);
        end
    end
`endif
