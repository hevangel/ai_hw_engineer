`timescale 1ns/1ps
// Am9511 fixed arithmetic, derived from AMD algorithm command descriptions.
// TOS=a, NOS=b. Operation: 0 add, 1 subtract, 2 multiply low,
// 3 multiply high, 4 divide, 5 negate. Transport is internal to this rebuild.
module amd_am9511_fixed (
    input logic clk_i, reset_i, start_i, single_i,
    input logic [2:0] operation_i,
    input logic [31:0] a_i, b_i,
    output logic busy_o, done_o,
    output logic [31:0] result_o,
    output logic [6:0] status_o,
    output logic result_defined_o
);
    localparam logic [1:0] IDLE=0, MULTIPLY=1, DIVIDE=2, COMPLETE=3;
    logic [1:0] state;
    logic single_q, sign_q, upper_q;
    logic [5:0] remaining;
    logic [63:0] product_q, multiplicand_q;
    logic [31:0] multiplier_q, divisor_q, quotient_q;
    logic [30:0] remainder_q;
    logic [31:0] a, b, minimum, mask, abs_a, abs_b;
    logic a_sign, b_sign;
    logic [32:0] sum;
    logic [63:0] product_step, signed_product;
    logic [31:0] mul_result, div_result;
    logic [31:0] trial_remainder;
    logic [30:0] next_remainder;
    logic [31:0] next_quotient;
    logic add_overflow, sub_overflow;

    function automatic [6:0] flags(input logic [31:0] value,
        input logic is_single, input logic [3:0] error, input logic carry);
        flags={is_single ? value[15] : value[31],
               is_single ? (value[15:0]==0) : (value==0),error,carry};
    endfunction

    always_comb begin
        mask=single_i ? 32'h0000ffff : 32'hffffffff;
        minimum=single_i ? 32'h00008000 : 32'h80000000;
        a=a_i & mask;
        b=b_i & mask;
        a_sign=single_i ? a[15] : a[31];
        b_sign=single_i ? b[15] : b[31];
        abs_a=a_sign ? ((~a+32'd1)&mask) : a;
        abs_b=b_sign ? ((~b+32'd1)&mask) : b;
        sum={1'b0,b}+{1'b0,a};
        add_overflow=(a_sign==b_sign) &&
            (a_sign != (single_i ? sum[15] : sum[31]));
        sub_overflow=(a==minimum) || ((a_sign!=b_sign) &&
            (b_sign != (single_i ? ((b-a)&32'h8000)!=0 : ((b-a)&32'h80000000)!=0)));
        product_step=product_q + (multiplier_q[0] ? multiplicand_q : 64'd0);
        signed_product=sign_q ? (~product_step+64'd1) : product_step;
        mul_result=upper_q ? (single_q ? {16'd0,signed_product[31:16]} : signed_product[63:32])
                           : (single_q ? {16'd0,signed_product[15:0]} : signed_product[31:0]);
        trial_remainder={remainder_q,quotient_q[31]};
        next_remainder=trial_remainder[30:0];
        next_quotient={quotient_q[30:0],1'b0};
        if(trial_remainder >= divisor_q)begin
            next_remainder=31'(trial_remainder-divisor_q);
            next_quotient[0]=1'b1;
        end
        div_result=sign_q ? (~next_quotient+32'd1) : next_quotient;
        if(single_q)div_result={16'd0,div_result[15:0]};
    end

    assign busy_o=(state!=IDLE);
    assign done_o=(state==COMPLETE);

    always_ff @(posedge clk_i) begin
        if(reset_i)begin
            state<=IDLE;
            single_q<=0; sign_q<=0; upper_q<=0; remaining<=0;
            product_q<=0; multiplicand_q<=0; multiplier_q<=0;
            divisor_q<=0; quotient_q<=0; remainder_q<=0;
            result_o<=0; status_o<=0; result_defined_o<=1;
        end else begin
            case(state)
                IDLE: if(start_i)begin
                    single_q<=single_i;
                    result_defined_o<=1;
                    case(operation_i)
                        0: begin
                            result_o<=sum[31:0]&mask;
                            status_o<=flags(sum[31:0]&mask,single_i,{3'b000,add_overflow},
                                            single_i ? sum[16] : sum[32]);
                            state<=COMPLETE;
                        end
                        1: begin
                            result_o<=(b-a)&mask;
                            status_o<=flags((b-a)&mask,single_i,{3'b000,sub_overflow},b<a);
                            state<=COMPLETE;
                        end
                        2,3: begin
                            if(a==minimum || b==minimum)begin
                                result_o<=minimum;
                                status_o<=flags(minimum,single_i,4'd1,1'b0);
                                // AMD defines single-upper and both lower results;
                                // double-upper is explicitly meaningless on this error.
                                result_defined_o<=single_i || operation_i==2;
                                state<=COMPLETE;
                            end else begin
                                product_q<=0; multiplicand_q<={32'd0,abs_b};
                                multiplier_q<=abs_a; sign_q<=a_sign^b_sign;
                                upper_q<=operation_i==3;
                                remaining<=single_i ? 6'd16 : 6'd32;
                                state<=MULTIPLY;
                            end
                        end
                        4: begin
                            if(a==0)begin
                                result_o<=b;
                                status_o<=flags(b,single_i,4'd8,1'b0);
                                state<=COMPLETE;
                            end else if(!single_i && (a==minimum || b==minimum))begin
                                result_o<=0; status_o<=flags(0,1'b0,4'd1,1'b0);
                                result_defined_o<=0; state<=COMPLETE;
                            end else begin
                                divisor_q<=abs_a;
                                // A 32-step unsigned division also covers 16-bit
                                // arguments without two differently aligned dividers.
                                quotient_q<=abs_b; remainder_q<=0;
                                remaining<=32; sign_q<=a_sign^b_sign;
                                state<=DIVIDE;
                            end
                        end
                        5: begin
                            result_o<=(~a+32'd1)&mask;
                            status_o<=flags((~a+32'd1)&mask,single_i,{3'b000,(a==minimum)},1'b0);
                            state<=COMPLETE;
                        end
                        default: begin
                            result_o<=0; status_o<=0;
                            result_defined_o<=0; state<=COMPLETE;
                        end
                    endcase
                end
                MULTIPLY: begin
                    product_q<=product_step;
                    multiplicand_q<=multiplicand_q<<1;
                    multiplier_q<=multiplier_q>>1;
                    remaining<=remaining-6'd1;
                    if(remaining==1)begin
                        result_o<=mul_result;
                        status_o<=flags(mul_result,single_q,
                            {3'b000,(!upper_q && (single_q ? signed_product[31:16]!=0 : signed_product[63:32]!=0))},1'b0);
                        state<=COMPLETE;
                    end
                end
                DIVIDE: begin
                    remainder_q<=next_remainder;
                    quotient_q<=next_quotient;
                    remaining<=remaining-6'd1;
                    if(remaining==1)begin
                        result_o<=div_result;
                        // ASSUMPTION: SDIV -32768/-1 wraps its 16-bit quotient
                        // without an extra error; original SDIV lists only divide
                        // by zero. External ova.c div16 agrees; original DEMAND/POLL limit case passes.
                        status_o<=flags(div_result,single_q,4'd0,1'b0);
                        state<=COMPLETE;
                    end
                end
                COMPLETE: state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
`ifdef FORMAL
`include "amd_am9511_fixed_props.sv"
`endif
endmodule
