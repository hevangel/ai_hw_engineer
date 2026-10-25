// Cover points for motorola_6809 (non-vacuity of the safety properties and
// reachability of the interesting architectural corners).
`ifdef FORMAL_COVER
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            cover(state == S_WAIT);                        // CWAI wait
            cover(state == S_SYNCW);                       // SYNC wait
            cover(state == S_PUSHQ && pq_int && pbm_q == 8'h01); // frame CC
            cover(state == S_PUSHQ && pq_us);              // PSHU push
            cover(state == S_PULLQ && pq_us);              // PULU pull
            cover(state == S_VEC_L && vec_q == 16'hFFFC);  // NMI vector
            cover(state == S_VEC_L && vec_q == 16'hFFF6);  // FIRQ vector
            cover(state == S_VEC_L && vec_q == 16'hFFF2);  // SWI3 vector
            cover(state == S_RTIQ);                        // RTI entry
            cover(state == S_RMW_W);                       // memory RMW
            cover(state == S_INDF2);                       // indirect ea
            cover(irq_req);                                // masked-level IRQ
            cover(firq_req);                               // masked FIRQ
        end
    end
`endif
