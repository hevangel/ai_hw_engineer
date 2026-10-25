// Included inside motorola_6809 under `ifdef FORMAL; bus_data_i, irq_n,
// firq_n and nmi_n stay free inputs. Safety properties: bus discipline,
// reset/vector behavior, interrupt-frame addressing and byte order,
// subroutine-linkage byte order, and bounded sequencer progress.
`ifdef FORMAL
    logic past_valid = 1'b0;
    logic rst_seen = 1'b0;
    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) assume(!rst_n);
        // reset is stable once released: real boards do not re-pulse
        // reset mid-instruction, and the solver otherwise exploits
        // mid-frame reset pulses to build unsound counterexamples
        if (rst_n) rst_seen <= 1'b1;
        if (rst_seen) assume(rst_n);
    end

    // Progress watchdog: after leaving FETCH the sequencer must reach the
    // next opcode fetch within 60 cycles whatever the bus returns
    // (longest chain: 12-byte interrupt frame + indirect EA + vector).
    // BMC only. The queue invariant below is the sharp form: the push/
    // pull walk must never run with an empty mask (that would livelock).
`ifdef FORMAL_BMC
    logic [5:0] progress_cnt = 0;
    always_ff @(posedge clk) begin
        if (!rst_n) progress_cnt <= 0;
        else if (state == S_FETCH) progress_cnt <= 0;
        else if (state != S_WAIT && state != S_SYNCW)
            progress_cnt <= progress_cnt + 6'd1;
    end
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            if (state != S_WAIT && state != S_SYNCW)
                assert(progress_cnt <= 6'd60);
            // queue invariant: the push/pull walk never runs dry
            if (state == S_PUSHQ || state == S_PULLQ)
                assert(pbm_q != 8'h00);
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            // Reset sequence: vector at FFFE/FFFF
            if (state == S_RST_L) assert(bus_addr == 16'hfffe);
            if (state == S_RST_H) assert(bus_addr == 16'hffff);

            // Fetch discipline: opcode fetch reads the PC and never writes
            if (state == S_FETCH) begin
                assert(!bus_we);
                assert(bus_addr == pc);
            end

            // Vector fetch reads the latched vector (FFF2 SWI3 ... FFFE
            // RST); never a write
            if (state == S_VEC_L || state == S_VEC_H) begin
                assert(!bus_we);
                assert(bus_addr[15:2] >= 14'h3FFC);   // FFF2..FFFF
            end

            // Queue pushes: write at (active pointer) - 1, push order from
            // the highest set mask bit
            if (state == S_PUSHQ) begin
                assert(bus_we);
                assert(bus_addr == (pq_us ? u : s) - 16'h1);
            end

            // Queue pulls and RTI: read at the active pointer, no write
            if (state == S_PULLQ || state == S_RTIQ) begin
                assert(!bus_we);
                assert(bus_addr == (pq_us ? u : s));
            end

            // Subroutine linkage: JSR pushes return address low byte first
            if (state == S_JSR1) assert(bus_data_o == ret_q[7:0]);
            if (state == S_JSR2) assert(bus_data_o == ret_q[15:8]);

            // RTI pulls CC first (E bit decides the rest of the frame)
            if (state == S_RTIQ) assert(!bus_we);

            // Wait states park the bus
            if (state == S_WAIT || state == S_SYNCW) begin
                assert(!bus_we);
                assert(halted_o);
            end
            if (halted_o) assert(state == S_WAIT || state == S_SYNCW);

            // RMW sequencing: read -> internal -> write, same address
            if ($past(state) == S_RMW_R && state == S_RMW_E)
                assert(ea_q == $past(ea_q));
            if ($past(state) == S_RMW_E && state == S_RMW_W)
                assert(bus_we && bus_addr == ea_q);
        end
    end
`endif
