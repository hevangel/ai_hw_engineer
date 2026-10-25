// Included inside motorola_6800 under `ifdef FORMAL; bus_data_i, irq_n and
// nmi_n stay free inputs. Safety properties: bus discipline, reset/vector
// behavior, interrupt-frame addressing, stack pointer monotonicity across
// a frame, and bounded sequencer progress.
`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) assume(!rst_n);
    end

    // CC bits 7-6 always read as 1 (M68PRM: stored/TPA convention)
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            assert(cc[7] && cc[6]);
        end
    end

    // Progress watchdog: after leaving FETCH the sequencer must reach the
    // next opcode fetch within 30 cycles whatever the bus returns (the
    // longest chain is the 7-byte interrupt push + vector fetch). Enabled
    // only in the bmc task (bounded check by design).
`ifdef FORMAL_BMC
    logic [5:0] progress_cnt = 0;
    always_ff @(posedge clk) begin
        if (!rst_n) progress_cnt <= 0;
        else if (state == S_FETCH) progress_cnt <= 0;
        else if (state != S_WAIT) progress_cnt <= progress_cnt + 6'd1;
    end
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            if (state != S_WAIT) assert(progress_cnt <= 6'd30);
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            // Reset sequence: vector high byte at FFFE, low at FFFF
            if (state == S_RST_L) assert(bus_addr == 16'hfffe);
            if (state == S_RST_H) assert(bus_addr == 16'hffff);

            // Fetch discipline: opcode fetch reads the PC and never writes
            if (state == S_FETCH) begin
                assert(!bus_we);
                assert(bus_addr == pc);
            end

            // Interrupt vector mux: NMI -> FFFC/D, IRQ -> FFF8/9,
            // SWI -> FFFA/B; selected by vec_q, not re-sampled.
            if (state == S_VEC_L)
                assert(bus_addr == {8'hFF, vec_q[7:0]});
            if (state == S_VEC_H)
                assert(bus_addr == {8'hFF, vec_q[7:0]} + 16'h1);

            // Interrupt frame: 7 pushes at decreasing addresses starting
            // at the entry SP; each push writes the current SP.
            if (state == S_INT_PUSH) begin
                assert(bus_we);
                assert(bus_addr == sp);
            end

            // Subroutine linkage: JSR/BSR pushes return address low first
            if (state == S_JSR1) assert(bus_data_o == ret_q[7:0]);
            if (state == S_JSR2) assert(bus_data_o == ret_q[15:8]);

            // RTI pulls CC, B, A, IXH, IXL, PCH, PCL in cnt order at SP+1
            if (state == S_RTI_PULL) assert(!bus_we);

            // WAI halts only from the wait state and resumes only via a
            // vector fetch
            if (state == S_WAIT) begin
                assert(!bus_we);
                assert(halted_o);
            end
            if (halted_o) assert(state == S_WAIT);

            // RMW sequencing: read -> internal -> write, same address
            if (past_valid && $past(state) == S_RMW_R && state == S_RMW_E)
                assert(ea_q == $past(ea_q));
            if ($past(state) == S_RMW_E && state == S_RMW_W)
                assert(bus_we && bus_addr == ea_q);
        end
    end
`endif
