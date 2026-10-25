module mos_6560_audio (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         ce_i,
    input  logic [127:0] config_i,
    output logic         sample_o,
    output logic [3:0]   voices_o,
    output logic [8:0]   level_o
);
    // Prescale masks select every 8th/4th/2nd/each half-rate sample.
    function automatic logic [7:0] prescale(input int ch);
        case (ch)
            0: prescale = 8'h0f;
            1: prescale = 8'h07;
            2: prescale = 8'h03;
            default: prescale = 8'h01;
        endcase
    endfunction
    logic phase_q;
    logic [7:0] div_q, div_d;
    logic [3:0][6:0] count_q, count_d;
    logic [3:0][7:0] sreg_q, sreg_d;
    logic [15:0] lfsr_q, lfsr_d;
    logic lfsr0_q, lfsr0_d;
    logic [7:0] reg_value;
    logic enabled, feedback;
    logic [2:0] bits;
    logic [3:0] volume;
    logic unused_config;
    assign unused_config = ^{config_i[127:116], config_i[79:0]};

    assign sample_o = rst_n && ce_i && phase_q;
    assign volume = config_i[115:112];

    always_comb begin
        div_d = div_q;
        count_d = count_q;
        sreg_d = sreg_q;
        lfsr_d = lfsr_q;
        lfsr0_d = lfsr0_q;
        reg_value = 0;
        enabled = 0;
        feedback = 0;
        if (sample_o) begin
            for (int ch = 0; ch < 4; ch++) begin
                reg_value = config_i[80 + 8*ch +: 8];
                enabled = reg_value[7];
                if ((div_q & prescale(ch)) == 0) begin
                    if (count_q[ch] != 7'h7f) begin
                        count_d[ch] = count_q[ch] + 7'd1;
                    end else begin
                        count_d[ch] = reg_value[6:0] + 7'd1;
                        if (ch == 3) begin
                            // The noise shifter advances on LFSR bit-0 rises.
                            if (lfsr_q[0] && !lfsr0_q)
                                sreg_d[ch] = {sreg_q[ch][6:0], !sreg_q[ch][7] && enabled};
                            feedback = lfsr_q[3] ^ lfsr_q[12] ^ lfsr_q[14] ^ lfsr_q[15];
                            lfsr0_d = lfsr_q[0];
                            lfsr_d = {lfsr_q[14:0], !(!feedback && enabled)};
                        end else begin
                            sreg_d[ch] = {sreg_q[ch][6:0], !sreg_q[ch][7] && enabled};
                        end
                    end
                end
            end
            div_d = div_q + 8'd2;
        end
        // The sample reflects the shifter outputs updated by this sample step.
        voices_o = {sreg_d[3][0] && config_i[111], sreg_d[2][0], sreg_d[1][0], sreg_d[0][0]};
        bits = {2'b0, voices_o[0]} + {2'b0, voices_o[1]} +
               {2'b0, voices_o[2]} + {2'b0, voices_o[3]};
        // Digital index into the reference's DAC; its analog curve is open.
        level_o = ({6'd0, bits} * 9'd7 + 9'd1) * {5'd0, volume};
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization; sound runs at half the system
        // clock with the sample phase counted from initialization.
        if (!rst_n) begin
            phase_q <= 0;
            div_q <= 0;
            count_q <= '0;
            sreg_q <= '0;
            lfsr_q <= 0;
            lfsr0_q <= 0;
        end else begin
            if (ce_i)
                phase_q <= !phase_q;
            div_q <= div_d;
            count_q <= count_d;
            sreg_q <= sreg_d;
            lfsr_q <= lfsr_d;
            lfsr0_q <= lfsr0_d;
        end
    end
endmodule
