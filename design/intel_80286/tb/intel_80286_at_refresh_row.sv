// IBM 5170 sheet 21: LS590 U32 has CCK and RCK on +REFRESH, CCKEN#
// grounded and CCLR# on -RESET. Its G# is U95 Q1-bar. LS125 U79
// drives -MEMR from Q1-bar when Q2-bar enables the buffer.
module intel_80286_at_refresh_row (
    input  logic       reset_n_i,
    input  logic       refresh_i,
    input  logic       chain_q1_i,
    input  logic       chain_q2_i,
    output logic [7:0] row_o,
    output logic       row_oe_o,
    output logic       memr_n_o,
    output logic       memr_oe_o,
    output logic [7:0] counter_o
);
    logic [7:0] row_latch;
    // TI SN74LS590: tied rising clocks capture the old count while the
    // counter increments. CCLR# resets only the counter, not the register.
    always_ff @(posedge refresh_i or negedge reset_n_i) begin
        if (!reset_n_i) counter_o <= 8'h00;
        else counter_o <= counter_o + 8'h01;
    end
    always_ff @(posedge refresh_i) row_latch <= counter_o;
    assign row_o = row_latch;
    assign row_oe_o = chain_q1_i;
    assign memr_n_o = !chain_q1_i;
    assign memr_oe_o = chain_q2_i;
endmodule
