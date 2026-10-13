// Cover-only environment: reachability witnesses for the sequencer states,
// the NMOS quirks, and the interrupt paths. This file is never included by
// the BMC or safety prove tasks; bus_data_i stays free so the solver can
// build arbitrary opcode streams after the reset assumption.
`ifdef FORMAL_COVER
    logic [5:0] cover_cycle = 0;
    always_ff @(posedge clk) begin
        if (cover_cycle < 63) cover_cycle <= cover_cycle + 6'd1;
        assume(rst_n == (cover_cycle != 0));
    end

    always_ff @(posedge clk) begin
        if (rst_n) begin
            // addressing-mode datapath states
            cover(state == S_IMM);
            cover(state == S_ZP);
            cover(state == S_ZPI);
            cover(state == S_ABS_L);
            cover(state == S_PTR_L);
            cover(state == S_PTR_H);
            cover(state == S_IND_L);
            // JMP ($xxFF) page-wrap bug: the high-byte read wraps to page 0
            cover(state == S_IND_H && ptr_q[7:0] == 8'hff && bus_addr[7:0] == 8'h00);
            cover(state == S_RD);
            cover(state == S_WR);
            cover(state == S_EXEC);
            cover(state == S_EXEC_M);
            cover(state == S_RMWR);
            cover(state == S_RMWW);
            cover(state == S_REL);
            cover(state == S_PSH);
            cover(state == S_PUL);
            cover(state == S_JSR_L);
            cover(state == S_JSR_PH);
            cover(state == S_RTS_L);
            cover(state == S_RTI_P);
            // interrupt entry: both hijack kinds and the vector reads
            cover(state == S_BRK_PAD && brk_is_brk);
            cover(state == S_BRK_PAD && !brk_is_brk && int_nmi_q);
            cover(state == S_BRK_PAD && !brk_is_brk && !int_nmi_q);
            cover(state == S_VEC_L && int_nmi_q);
            cover(state == S_VEC_L && !int_nmi_q);
            // decimal-mode arithmetic reaches EXEC with D set
            cover(state == S_EXEC && p[FD] && op == O_ADC);
            cover(state == S_EXEC && p[FD] && op == O_SBC);
            // documented fault path and the terminal state
            cover(state == S_FAULT && f_undoc(opcode));
        end
    end
`endif
