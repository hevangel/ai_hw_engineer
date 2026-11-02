// Digital RESET path from the Intersil 82C284 clock-generator datasheet.
// This is not a complete 82C284 model: analog RES qualification and CLK/PCLK
// generation are outside this module.
module intel_80286_82c284_reset #(
    parameter int RES_SYNC_DELAY_CLKS = 2
) (
    input  logic clk_i,       // 82C284 external CLK, twice processor rate
    input  logic res_n_i,     // active-low 82C284 RES input
    output logic reset_o      // active-high 80C286 RESET output
);
    // The Intersil June 2004 82C284 datasheet says RES is synchronized at the
    // falling edge of CLK and takes one or two CLK periods to affect RESET.
    // Parameterize that documented digital delay; use 2 for the conservative
    // default. RESET polarity is opposite to RES.
    // ASSUMPTION: A27. The synchronizer powers up holding "RES asserted", so
    // RESET is high from power-up until RES has been sampled high for the
    // configured delay. This avoids an X RESET before the first CLK falls and
    // matches a board that holds RES low through power-up.
    // verilator lint_off PROCASSINIT
    logic [1:0] res_sync_q = 2'b00;
    // verilator lint_on PROCASSINIT

    // Only the documented one- or two-CLK delays are representable.
    if (RES_SYNC_DELAY_CLKS < 1 || RES_SYNC_DELAY_CLKS > 2) begin : g_bad_delay
        $error("RES_SYNC_DELAY_CLKS must be 1 or 2");
    end

    always_ff @(negedge clk_i) begin
        res_sync_q <= {res_sync_q[0], res_n_i};
    end

    always_comb begin
        reset_o = !res_sync_q[RES_SYNC_DELAY_CLKS - 1];
    end
endmodule
