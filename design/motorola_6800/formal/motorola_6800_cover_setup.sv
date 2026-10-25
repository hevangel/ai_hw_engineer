// Cover points for motorola_6800 (non-vacuity of the safety properties and
// reachability of the interesting architectural corners).
`ifdef FORMAL_COVER
    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            cover(state == S_WAIT);                       // WAI wait reached
            cover(state == S_WAIT && !irq_n);             // IRQ wake pending
            cover(state == S_INT_PUSH && cnt == 3'd6);    // frame CC byte
            cover(state == S_VEC_L && vec_q == 16'hFFFC); // NMI vector
            cover(state == S_VEC_L && vec_q == 16'hFFFA); // SWI vector
            cover(state == S_VEC_L && vec_q == 16'hFFF8); // IRQ vector
            cover(state == S_RTI_PULL && cnt == 3'd6);    // RTI last byte
            cover(state == S_JSR_GO);                     // JSR/BSR jump
            cover(state == S_RMW_W);                      // memory RMW write
            cover(state == S_WR_L);                       // 16-bit store
            cover(irq_req);                               // masked-level IRQ
        end
    end
`endif
