// APU frame counter (sequencer) with region-specific step positions.
module ricoh_2a03_frame #(
    parameter bit PAL = 1'b0
) (
    input  logic clk, rst_n,
    input  logic apu_phase_i,     // 1 during an APU ("put") cycle
    input  logic wr_i,            // $4017 write this cycle
    input  logic [1:0] mode_i,    // $4017 bits 7:6
    input  logic irq_clear_i,     // $4015 read this cycle
    output logic quarter_o, half_o,
    output logic irq_o
);
    localparam logic [15:0] S1 = PAL ? 16'd8313  : 16'd7457;
    localparam logic [15:0] S2 = PAL ? 16'd16627 : 16'd14913;
    localparam logic [15:0] S3 = PAL ? 16'd24939 : 16'd22371;
    localparam logic [15:0] S4 = PAL ? 16'd33252 : 16'd29828;
    localparam logic [15:0] S5 = PAL ? 16'd41565 : 16'd37281;
    logic five_step, inhibit;
    logic [15:0] count;
    logic [2:0] reset_delay;
    logic pending_five;
    logic reset_now;
    assign reset_now = reset_delay == 3'd1;

    always_comb begin
        quarter_o = 1'b0; half_o = 1'b0;
        if (reset_now) begin
            quarter_o = pending_five; half_o = pending_five;
        end else if (count == S1 || count == S3) quarter_o = 1'b1;
        else if (count == S2) begin quarter_o = 1'b1; half_o = 1'b1; end
        else if (!five_step && count == S4 + 16'd1) begin quarter_o = 1'b1; half_o = 1'b1; end
        else if (five_step && count == S5) begin quarter_o = 1'b1; half_o = 1'b1; end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            five_step <= 1'b0; inhibit <= 1'b0; count <= '0; irq_o <= 1'b0;
            reset_delay <= '0; pending_five <= 1'b0;
        end else begin
            if (reset_now || (!five_step && count == S4 + 16'd2) || (five_step && count == S5 + 16'd1))
                count <= 16'd1; // this cycle is cycle 0 of the next sequence
            else count <= count + 16'd1;
            if (reset_delay != 0) reset_delay <= reset_delay - 3'd1;
            if (!five_step && !inhibit && count >= S4 && count <= S4 + 16'd2) irq_o <= 1'b1;
            if (irq_clear_i) irq_o <= 1'b0;
            if (wr_i) begin
                five_step <= mode_i[1]; inhibit <= mode_i[0]; pending_five <= mode_i[1];
                if (mode_i[0]) irq_o <= 1'b0;
                // Counter reset 3 cycles after a write during an APU cycle, 4 otherwise.
                reset_delay <= apu_phase_i ? 3'd3 : 3'd4;
            end
        end
    end
endmodule
