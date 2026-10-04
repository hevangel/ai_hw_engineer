`timescale 1ns/1ps
// Internal reusable restoring divider: 128-bit numerator / 64-bit denominator.
// Signed mode truncates toward zero. Results are low-width two's complement;
// zero divisor returns zero and raises zero_o. One bit is processed per clock.
module amd_am9511_divider (
    input logic clk_i, reset_i, start_i, signed_i,
    input logic [127:0] numerator_i,
    input logic [63:0] denominator_i,
    output logic busy_o, done_o, zero_o,
    output logic [127:0] quotient_o,
    output logic [63:0] remainder_o
);
    localparam logic [1:0] IDLE=0, RUN=1, COMPLETE=2;
    logic [1:0] state;
    logic quotient_negative, remainder_negative;
    logic [7:0] remaining;
    logic [127:0] quotient_q, next_quotient;
    logic [63:0] divisor_q, remainder_q, next_remainder;
    logic [64:0] trial;
    always_comb begin
        trial={remainder_q,quotient_q[127]};
        next_quotient={quotient_q[126:0],1'b0};
        next_remainder=trial[63:0];
        if(trial>={1'b0,divisor_q})begin
            next_remainder=64'(trial-{1'b0,divisor_q});next_quotient[0]=1'b1;
        end
    end
    assign busy_o=state!=IDLE;
    assign done_o=state==COMPLETE;
    always_ff @(posedge clk_i)begin
        if(reset_i)begin
            state<=IDLE;quotient_negative<=0;remainder_negative<=0;
            remaining<=0;quotient_q<=0;divisor_q<=0;remainder_q<=0;
            quotient_o<=0;remainder_o<=0;zero_o<=0;
        end else case(state)
            IDLE:if(start_i)begin
                zero_o<=denominator_i==0;
                if(denominator_i==0)begin quotient_o<=0;remainder_o<=0;state<=COMPLETE;end
                else begin
                    quotient_negative<=signed_i&&(numerator_i[127]^denominator_i[63]);
                    remainder_negative<=signed_i&&numerator_i[127];
                    quotient_q<=signed_i&&numerator_i[127] ? -numerator_i : numerator_i;
                    divisor_q<=signed_i&&denominator_i[63] ? -denominator_i : denominator_i;
                    remainder_q<=0;remaining<=128;state<=RUN;
                end
            end
            RUN:begin
                quotient_q<=next_quotient;remainder_q<=next_remainder;remaining<=remaining-8'd1;
                if(remaining==1)begin
                    quotient_o<=quotient_negative ? -next_quotient : next_quotient;
                    remainder_o<=remainder_negative ? -next_remainder : next_remainder;
                    state<=COMPLETE;
                end
            end
            COMPLETE:state<=IDLE;
            default:state<=IDLE;
        endcase
    end
endmodule
