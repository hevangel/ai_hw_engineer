// APU noise channel: 15-bit LFSR with long/short feedback taps.
module ricoh_2a03_noise #(
    parameter bit PAL = 1'b0
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
    // Noise period in CPU cycles.
    function automatic logic [11:0] noise_period(input logic pal, input logic [3:0] index);
        if (!pal) begin
            case (index)
                4'd0: noise_period = 12'd4;    4'd1: noise_period = 12'd8;
                4'd2: noise_period = 12'd16;   4'd3: noise_period = 12'd32;
                4'd4: noise_period = 12'd64;   4'd5: noise_period = 12'd96;
                4'd6: noise_period = 12'd128;  4'd7: noise_period = 12'd160;
                4'd8: noise_period = 12'd202;  4'd9: noise_period = 12'd254;
                4'd10: noise_period = 12'd380; 4'd11: noise_period = 12'd508;
                4'd12: noise_period = 12'd762; 4'd13: noise_period = 12'd1016;
                4'd14: noise_period = 12'd2034; default: noise_period = 12'd4068;
            endcase
        end else begin
            case (index)
                4'd0: noise_period = 12'd4;    4'd1: noise_period = 12'd8;
                4'd2: noise_period = 12'd14;   4'd3: noise_period = 12'd30;
                4'd4: noise_period = 12'd60;   4'd5: noise_period = 12'd88;
                4'd6: noise_period = 12'd118;  4'd7: noise_period = 12'd148;
                4'd8: noise_period = 12'd188;  4'd9: noise_period = 12'd236;
                4'd10: noise_period = 12'd354; 4'd11: noise_period = 12'd472;
                4'd12: noise_period = 12'd708; 4'd13: noise_period = 12'd944;
                4'd14: noise_period = 12'd1890; default: noise_period = 12'd3778;
            endcase
        end
    endfunction
    logic halt, constant, short_mode;
    logic [3:0] vol, period_index, env_vol;
    logic [10:0] timer;
    logic [14:0] lfsr;
    logic feedback;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [11:0] reload_cycles;   // every table entry is even
    /* verilator lint_on UNUSEDSIGNAL */
    assign reload_cycles = noise_period(PAL, period_index);
    assign feedback = lfsr[0] ^ (short_mode ? lfsr[6] : lfsr[1]);
    assign out_o = (!lfsr[0] && active_o) ? env_vol : 4'd0;

    ricoh_2a03_length length_unit (
        .clk, .rst_n, .enable_i, .halt_i(halt), .load_i(wr_i && reg_i == 2'd3),
        .index_i(data_i[7:3]), .half_i, .active_o
    );
    ricoh_2a03_envelope envelope_unit (
        .clk, .rst_n, .start_i(wr_i && reg_i == 2'd3), .quarter_i,
        .loop_i(halt), .constant_i(constant), .period_i(vol), .volume_o(env_vol)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            halt <= 1'b0; constant <= 1'b0; short_mode <= 1'b0; vol <= '0;
            period_index <= '0; timer <= '0; lfsr <= 15'd1;
        end else begin
            // Table values are CPU cycles; the timer counts APU cycles.
            if (apu_tick_i) begin
                if (timer == 0) begin
                    timer <= reload_cycles[11:1] - 11'd1;
                    lfsr <= {feedback, lfsr[14:1]};
                end else timer <= timer - 11'd1;
            end
            if (wr_i) begin
                case (reg_i)
                    2'd0: begin halt <= data_i[5]; constant <= data_i[4]; vol <= data_i[3:0]; end
                    2'd2: begin short_mode <= data_i[7]; period_index <= data_i[3:0]; end
                    default: ;
                endcase
            end
        end
    end
endmodule
