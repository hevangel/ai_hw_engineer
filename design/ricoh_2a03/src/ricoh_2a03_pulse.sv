// APU pulse channel. NEGATE_ONES selects pulse 1's one's-complement sweep.
module ricoh_2a03_pulse #(
    parameter bit NEGATE_ONES = 1'b1
) (
    input  logic clk, rst_n,
    input  logic apu_tick_i, quarter_i, half_i,
    input  logic enable_i,
    input  logic wr_i,
    input  logic [1:0] reg_i,
    input  logic [7:0] data_i,
    output logic active_o,
    output logic [3:0] out_o
);
    logic [1:0] duty;
    logic halt, constant;
    logic [3:0] vol;
    logic sweep_en, sweep_neg, sweep_reload;
    logic [2:0] sweep_period, sweep_shift, sweep_div;
    logic [10:0] period, timer;
    logic [2:0] step;
    logic [11:0] change, target;
    logic mute, seq_bit;
    logic [3:0] env_vol;
    logic [4:0] len_index;

    assign change = {1'b0, period >> sweep_shift};
    always_comb begin
        if (!sweep_neg) target = {1'b0, period} + change;
        else if (NEGATE_ONES) target = {1'b0, period} - change - 12'd1;
        else target = {1'b0, period} - change;
    end
    // Negative results never mute (they wrap above 7FF only when adding).
    assign mute = period < 11'd8 || (!sweep_neg && target > 12'h7ff);

    always_comb begin
        case (duty)
            2'd0: seq_bit = step == 3'd1;
            2'd1: seq_bit = step == 3'd1 || step == 3'd2;
            2'd2: seq_bit = step >= 3'd1 && step <= 3'd4;
            default: seq_bit = !(step == 3'd1 || step == 3'd2);
        endcase
    end
    assign out_o = (seq_bit && active_o && !mute) ? env_vol : 4'd0;
    assign len_index = data_i[7:3];

    ricoh_2a03_length length_unit (
        .clk, .rst_n, .enable_i, .halt_i(halt), .load_i(wr_i && reg_i == 2'd3),
        .index_i(len_index), .half_i, .active_o
    );
    ricoh_2a03_envelope envelope_unit (
        .clk, .rst_n, .start_i(wr_i && reg_i == 2'd3), .quarter_i,
        .loop_i(halt), .constant_i(constant), .period_i(vol), .volume_o(env_vol)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            duty <= '0; halt <= 1'b0; constant <= 1'b0; vol <= '0;
            sweep_en <= 1'b0; sweep_neg <= 1'b0; sweep_reload <= 1'b0;
            sweep_period <= '0; sweep_shift <= '0; sweep_div <= '0;
            period <= '0; timer <= '0; step <= '0;
        end else begin
            // Timer: one decrement per APU cycle; the sequencer steps
            // backwards through the duty table on reload.
            if (apu_tick_i) begin
                if (timer == 0) begin
                    timer <= period;
                    step <= step - 3'd1;
                end else timer <= timer - 11'd1;
            end
            // Sweep unit on half-frame clocks.
            if (half_i) begin
                if (sweep_div == 0 && sweep_en && sweep_shift != 0 && !mute)
                    period <= target[10:0];
                if (sweep_div == 0 || sweep_reload) begin
                    sweep_div <= sweep_period; sweep_reload <= 1'b0;
                end else sweep_div <= sweep_div - 3'd1;
            end
            if (wr_i) begin
                case (reg_i)
                    2'd0: begin duty <= data_i[7:6]; halt <= data_i[5];
                                constant <= data_i[4]; vol <= data_i[3:0]; end
                    2'd1: begin sweep_en <= data_i[7]; sweep_period <= data_i[6:4];
                                sweep_neg <= data_i[3]; sweep_shift <= data_i[2:0];
                                sweep_reload <= 1'b1; end
                    2'd2: period[7:0] <= data_i;
                    default: begin period[10:8] <= data_i[2:0]; step <= '0; end
                endcase
            end
        end
    end
`ifdef FORMAL
    // Periods below 8 always mute the channel.
    always_comb if (period < 11'd8) assert(out_o == 4'd0);
`endif
endmodule
