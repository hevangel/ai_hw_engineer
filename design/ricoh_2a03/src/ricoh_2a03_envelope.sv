// APU envelope generator (pulse and noise channels).
module ricoh_2a03_envelope (
    input  logic clk, rst_n,
    input  logic start_i,        // write to the channel's fourth register
    input  logic quarter_i,      // quarter-frame clock
    input  logic loop_i,
    input  logic constant_i,
    input  logic [3:0] period_i, // V field: constant volume or divider period
    output logic [3:0] volume_o
);
    logic start;
    logic [3:0] divider, decay;
    assign volume_o = constant_i ? period_i : decay;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start <= 1'b0; divider <= '0; decay <= '0;
        end else begin
            if (quarter_i) begin
                if (start) begin
                    start <= 1'b0; decay <= 4'd15; divider <= period_i;
                end else if (divider == 0) begin
                    divider <= period_i;
                    if (decay != 0) decay <= decay - 4'd1;
                    else if (loop_i) decay <= 4'd15;
                end else divider <= divider - 4'd1;
            end
            // A register write after the clock in the same cycle still arms
            // the next quarter-frame restart.
            if (start_i) start <= 1'b1;
        end
    end
endmodule
