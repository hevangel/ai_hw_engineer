`timescale 1ns/1ps
// Synthesizable bounded approximation engine for the original Am9511
// command/domain/accuracy contract. This reconstructs externally observable
// functions, not AMD's private Chebyshev microcode or original cycle counts.
module amd_am9511_derived (
    input logic clk_i, reset_i, start_i,
    input logic [3:0] operation_i,
    input logic [31:0] a_i, b_i,
    output logic busy_o, done_o,
    output logic [31:0] result_o,
    output logic [6:0] status_o
);
`include "amd_am9511_derived_constants.svh"
    localparam logic [4:0] IDLE=0, PREPARE=1, ROOT=2, ROOT_FINISH=3,
        CORDIC_PREPARE=4, CORDIC=5, TAN_DIVIDE=6, LN_INIT=7, LN_SQUARE=8,
        LN_TERM=9, LN_FINISH=10, LOG_SCALE=11, POWER_SCALE=12,
        EXP_INIT=13, EXP_TERM=14, PACK=15, COMPLETE=16, EXP_REDUCE=17;
    logic [4:0] state;
    logic [3:0] operation_q;
    logic [31:0] a_q, b_q;
    logic [5:0] iteration;
    logic signed [63:0] x_q, y_q, z_q, input_q, value_q;
    logic signed [63:0] ln_z, ln_z2, power_q, sum_q, term_q, exp_argument, exp_reduced;
    logic vector_q, inverse_q, flip_q;
    integer exponent_a, exponent_base, scale_q;
    logic [31:0] base;
    logic [63:0] absolute_q;
    logic small_argument, too_large_exp, inverse_domain_error;
    logic [175:0] argument_wide;
    logic phase_start,phase_busy,phase_done;
    logic [63:0] phase_value;
    logic signed [63:0] angle, reduced_angle, next_x, next_y, next_z;
    logic [111:0] radical_q;
    logic [56:0] root_remainder, next_root_remainder;
    logic [58:0] root_trial, root_test;
    logic [55:0] root_q, next_root;
    logic signed [63:0] multiply_a, multiply_b, divide_denominator;
    logic signed [127:0] product, divide_numerator, quotient, power_argument;
    logic division_start, division_busy, division_done;
    logic unused_division_zero;
    logic [63:0] unused_division_remainder;
    logic signed [63:0] ln_result, exp_next_term;
    logic [35:0] packed_value;
    logic [127:0] ratio_absolute, ratio_mask;
    logic [63:0] ratio_magnitude;
    integer ratio_leading, ratio_shift;

    function automatic [35:0] encode_q56(input logic signed [63:0] value,input integer extra_exponent);
        logic [63:0] magnitude, tail_mask;
        logic [23:0] mantissa;
        logic [24:0] rounded;
        logic guard_bit, sticky_bit;
        logic [3:0] error;
        integer leading, shift_count, exponent_value;
        begin
            magnitude=value[63] ? (~value+64'd1) : value;
            leading=0;
            for(integer i=0;i<64;i=i+1)if(magnitude[i])leading=i;
            shift_count=leading-23;
            mantissa=0;tail_mask=0;guard_bit=0;sticky_bit=0;
            if(shift_count>0)begin
                mantissa=24'(magnitude>>shift_count);
                guard_bit=magnitude[shift_count-1];
                if(shift_count>1)begin
                    tail_mask=64'hffffffffffffffff>>(65-shift_count);
                    sticky_bit=(magnitude&tail_mask)!=0;
                end
            end else mantissa=24'(magnitude<<(-shift_count));
            // ASSUMPTION: functional nearest-even format conversion; same
            // documented rounding assumption as the basic float unit.
            rounded={1'b0,mantissa}+{24'd0,(guard_bit&&(sticky_bit||mantissa[0]))};
            exponent_value=leading-55+extra_exponent;
            if(rounded[24])begin rounded=rounded>>1;exponent_value=exponent_value+1;end
            error=exponent_value>63 ? 4'd1 : exponent_value < -64 ? 4'd2 : 4'd0;
            encode_q56=magnitude==0 ? 36'd0 : {error,value[63],7'(exponent_value),rounded[23:0]};
        end
    endfunction

    task automatic raw_finish(input logic [31:0] value,input logic [3:0] error);
        result_o<=value;status_o<={value[31],!value[23],error,1'b0};state<=COMPLETE;
    endtask

    always_comb begin
        exponent_a=int'($signed(a_q[30:24]));
        base=operation_q==11 ? b_q : a_q;
        exponent_base=int'($signed(base[30:24]));
        absolute_q=a_q[23] ? {8'd0,a_q[23:0],32'd0} : 64'd0;
        if(exponent_a>=0)absolute_q=absolute_q<<exponent_a;
        else absolute_q=absolute_q>>(-exponent_a);
        small_argument=!a_q[23] || exponent_a < -11 || (exponent_a== -11 && a_q[23:0]==24'h800000);
        too_large_exp=a_q[23] && (exponent_a>6 || (exponent_a==6 && a_q[23:0]>24'h800000));
        inverse_domain_error=a_q[23] && (exponent_a>1 || (exponent_a==1 && a_q[23:0]>24'h800000));
        argument_wide=a_q[23] ? ({152'd0,a_q[23:0]}<<(exponent_a+88)) : 176'd0;
        angle=$signed(phase_value);
        if(a_q[31])angle=-angle;
        if(angle>Q_PI)angle=angle-Q_TWO_PI;
        if(angle< -Q_PI)angle=angle+Q_TWO_PI;
        reduced_angle=angle;
        if(angle>Q_HALF_PI)reduced_angle=angle-Q_PI;
        else if(angle< -Q_HALF_PI)reduced_angle=angle+Q_PI;

        if(vector_q)begin
            next_x=y_q>=0 ? x_q+(y_q>>>iteration) : x_q-(y_q>>>iteration);
            next_y=y_q>=0 ? y_q-(x_q>>>iteration) : y_q+(x_q>>>iteration);
            next_z=y_q>=0 ? z_q+cordic_angle(iteration) : z_q-cordic_angle(iteration);
        end else begin
            next_x=z_q>=0 ? x_q-(y_q>>>iteration) : x_q+(y_q>>>iteration);
            next_y=z_q>=0 ? y_q+(x_q>>>iteration) : y_q-(x_q>>>iteration);
            next_z=z_q>=0 ? z_q-cordic_angle(iteration) : z_q+cordic_angle(iteration);
        end
        root_trial={root_remainder,radical_q[111:110]};
        root_test=({3'd0,root_q}<<2)|59'd1;
        next_root=root_q<<1;
        next_root_remainder=root_trial[56:0];
        if(root_trial>=root_test)begin
            next_root[0]=1'b1;next_root_remainder=57'(root_trial-root_test);
        end

        multiply_a=0;multiply_b=0;
        case(state)
            PREPARE: begin multiply_a=$signed(absolute_q);multiply_b=$signed(absolute_q);end
            LN_SQUARE:begin multiply_a=ln_z;multiply_b=ln_z;end
            LN_TERM:begin multiply_a=power_q;multiply_b=ln_z2;end
            LN_FINISH:begin multiply_a=Q_LN2;multiply_b=64'(exponent_base-1);end
            LOG_SCALE:begin multiply_a=value_q;multiply_b=Q_LOG10_E;end
            POWER_SCALE:begin multiply_a=value_q;multiply_b=$signed({40'd0,a_q[23:0]});end
            EXP_REDUCE:begin multiply_a=64'(scale_q);multiply_b=Q_LN2;end
            EXP_TERM:begin multiply_a=term_q;multiply_b=exp_reduced;end
            default:begin end
        endcase
        product=multiply_a*multiply_b;
        divide_numerator=0;divide_denominator=1;
        case(state)
            CORDIC_PREPARE:begin
                divide_numerator=128'd1<<80;divide_denominator=$signed({40'd0,a_q[23:0]});
            end
            TAN_DIVIDE:begin divide_numerator=128'(y_q)<<<56;divide_denominator=x_q;end
            LN_INIT:begin
                divide_numerator=(128'({7'd0,base[23:0],33'd0})-128'(Q_ONE))<<<56;
                divide_denominator=$signed({7'd0,base[23:0],33'd0})+Q_ONE;
            end
            LN_TERM:begin divide_numerator=product>>>56;divide_denominator=64'(iteration)*2+1;end
            EXP_INIT:begin divide_numerator=128'(exp_argument);divide_denominator=Q_LN2;end
            EXP_TERM:begin divide_numerator=product>>>56;divide_denominator=64'(iteration);end
            default:begin end
        endcase
        power_argument=product;
        if(exponent_a>=24)power_argument=power_argument<<<(exponent_a-24);
        else power_argument=power_argument>>>(24-exponent_a);
        if(a_q[31])power_argument=-power_argument;
        ln_result=(sum_q<<<1)+64'(product);
        exp_next_term=64'(quotient);
        packed_value=encode_q56(value_q,scale_q);
        ratio_absolute=quotient[127] ? -quotient : quotient;
        ratio_leading=0;
        for(integer i=0;i<128;i=i+1)if(ratio_absolute[i])ratio_leading=i;
        ratio_shift=ratio_leading>62 ? ratio_leading-62 : 0;
        ratio_mask=ratio_shift==0 ? 128'd0 : (128'hffffffffffffffffffffffffffffffff>>(128-ratio_shift));
        ratio_magnitude=64'(ratio_absolute>>ratio_shift)|{63'd0,((ratio_absolute&ratio_mask)!=0)};
    end

    assign busy_o=state!=IDLE;
    assign done_o=state==COMPLETE;
    assign division_start=!division_busy&&!division_done &&
        ((state==CORDIC_PREPARE&&operation_q==7) || state==TAN_DIVIDE || state==LN_INIT ||
         state==LN_TERM || state==EXP_INIT || state==EXP_TERM);
    assign phase_start=state==CORDIC_PREPARE&&operation_q!=7&&!phase_busy&&!phase_done;
    amd_am9511_phase_reducer phase_reducer(.clk_i(clk_i),.reset_i(reset_i),.start_i(phase_start),
        .value_i(argument_wide),.modulus_i(115'(TWO_PI_Q112)),
        .busy_o(phase_busy),.done_o(phase_done),.phase_q56_o(phase_value));
    amd_am9511_divider divider(.clk_i(clk_i),.reset_i(reset_i),.start_i(division_start),.signed_i(1'b1),
        .numerator_i(divide_numerator),.denominator_i(divide_denominator),
        .busy_o(division_busy),.done_o(division_done),.zero_o(unused_division_zero),
        .quotient_o(quotient),.remainder_o(unused_division_remainder));
    always_ff @(posedge clk_i)begin
        if(reset_i)begin
            state<=IDLE;operation_q<=0;a_q<=0;b_q<=0;iteration<=0;
            x_q<=0;y_q<=0;z_q<=0;input_q<=0;value_q<=0;
            ln_z<=0;ln_z2<=0;power_q<=0;sum_q<=0;term_q<=0;exp_argument<=0;exp_reduced<=0;
            vector_q<=0;inverse_q<=0;flip_q<=0;scale_q<=0;
            radical_q<=0;root_remainder<=0;root_q<=0;result_o<=0;status_o<=0;
        end else case(state)
            IDLE:if(start_i)begin
                operation_q<=operation_i;a_q<=a_i;b_q<=b_i;state<=PREPARE;scale_q<=0;
            end
            PREPARE:begin
                input_q<=$signed(absolute_q);iteration<=0;
                case(operation_q)
                    1:begin
                        if(a_q[31]&&a_q[23])raw_finish(a_q,4'd4);
                        else if(!a_q[23])raw_finish(0,0);
                        else begin
                            radical_q<=112'({8'd0,a_q[23:0],32'd0}>>(exponent_a&1))<<56;
                            scale_q<=(exponent_a+(exponent_a&1))/2;
                            root_remainder<=0;root_q<=0;state<=ROOT;
                        end
                    end
                    2,4:if(small_argument)raw_finish(a_q,0);else state<=CORDIC_PREPARE;
                    3:state<=CORDIC_PREPARE;
                    5,6:begin
                        if(inverse_domain_error)raw_finish(a_q,4'd12);
                        else if(a_q[23]&&exponent_a==1&&a_q[23:0]==24'h800000)begin
                            value_q<=operation_q==5 ? (a_q[31] ? -Q_HALF_PI : Q_HALF_PI) : (a_q[31] ? Q_PI : 64'd0);
                            state<=PACK;
                        end else if(small_argument)begin
                            if(operation_q==5)raw_finish(a_q,0);
                            else begin
                                value_q<=a_q[31] ? Q_HALF_PI+$signed(absolute_q) : Q_HALF_PI-$signed(absolute_q);
                                state<=PACK;
                            end
                        end else begin
                            radical_q<=112'(Q_ONE-64'(product>>>56))<<56;
                            root_remainder<=0;root_q<=0;state<=ROOT;
                        end
                    end
                    7:if(small_argument)raw_finish(a_q,0);else state<=CORDIC_PREPARE;
                    8,9,11:begin
                        if(base[31]||!base[23])raw_finish(a_q,4'd4);
                        else state<=LN_INIT;
                    end
                    10:begin
                        if(too_large_exp)raw_finish(a_q,4'd12);
                        else begin exp_argument<=a_q[31] ? -$signed(absolute_q) : $signed(absolute_q);state<=EXP_INIT;end
                    end
                    default:raw_finish(a_q,0);
                endcase
            end
            ROOT:begin
                radical_q<=radical_q<<2;root_q<=next_root;root_remainder<=next_root_remainder;
                iteration<=iteration+6'd1;
                if(iteration==55)state<=ROOT_FINISH;
            end
            ROOT_FINISH:begin
                if(operation_q==1)begin value_q<=$signed({8'd0,root_q});state<=PACK;end
                else begin
                    x_q<=$signed({8'd0,root_q});y_q<=input_q;z_q<=0;
                    vector_q<=1;inverse_q<=0;iteration<=0;state<=CORDIC;
                end
            end
            CORDIC_PREPARE:if((operation_q==7&&division_done)||(operation_q!=7&&phase_done))begin
                if(operation_q==7)begin
                    vector_q<=1;inverse_q<=exponent_a>1 || (exponent_a==1 && a_q[23:0]>24'h800000);
                    x_q<=Q_ONE;z_q<=0;
                    if(exponent_a>1 || (exponent_a==1 && a_q[23:0]>24'h800000))y_q<=64'(quotient>>>exponent_a);
                    else y_q<=input_q;
                end else begin
                    vector_q<=0;flip_q<=angle>Q_HALF_PI || angle< -Q_HALF_PI;
                    x_q<=Q_GAIN;y_q<=0;z_q<=reduced_angle;
                end
                iteration<=0;state<=CORDIC;
            end
            CORDIC:begin
                x_q<=next_x;y_q<=next_y;z_q<=next_z;iteration<=iteration+6'd1;
                if(iteration==51)begin
                    case(operation_q)
                        2:begin value_q<=flip_q ? -next_y : next_y;state<=PACK;end
                        3:begin value_q<=flip_q ? -next_x : next_x;state<=PACK;end
                        4:state<=TAN_DIVIDE;
                        5:begin value_q<=a_q[31] ? -next_z : next_z;state<=PACK;end
                        6:begin value_q<=a_q[31] ? Q_HALF_PI+next_z : Q_HALF_PI-next_z;state<=PACK;end
                        7:begin
                            value_q<=a_q[31] ? -(inverse_q ? Q_HALF_PI-next_z : next_z) :
                                                          (inverse_q ? Q_HALF_PI-next_z : next_z);
                            state<=PACK;
                        end
                        default:raw_finish(a_q,0);
                    endcase
                end
            end
            TAN_DIVIDE:if(division_done)begin
                if(x_q==0)raw_finish(a_q,4'd1);
                else begin
                    value_q<=quotient[127] ? -$signed(ratio_magnitude) : $signed(ratio_magnitude);
                    scale_q<=ratio_shift;state<=PACK;
                end
            end
            LN_INIT:if(division_done)begin ln_z<=64'(quotient);power_q<=64'(quotient);sum_q<=64'(quotient);state<=LN_SQUARE;end
            LN_SQUARE:begin ln_z2<=64'(product>>>56);iteration<=1;state<=LN_TERM;end
            LN_TERM:if(division_done)begin
                power_q<=64'(product>>>56);sum_q<=sum_q+64'(quotient);iteration<=iteration+6'd1;
                if(iteration==20)state<=LN_FINISH;
            end
            LN_FINISH:begin
                value_q<=ln_result;
                state<=operation_q==8 ? LOG_SCALE : operation_q==11 ? POWER_SCALE : PACK;
            end
            LOG_SCALE:begin value_q<=64'(product>>>56);state<=PACK;end
            POWER_SCALE:begin
                if(!a_q[23])begin exp_argument<=0;state<=EXP_INIT;end
                else if(power_argument>128'(Q_ONE)*32 || power_argument< -128'(Q_ONE)*32)raw_finish(a_q,4'd12);
                else begin exp_argument<=64'(power_argument);state<=EXP_INIT;end
            end
            EXP_INIT:if(division_done)begin
                scale_q<=32'(quotient);term_q<=Q_ONE;sum_q<=Q_ONE;iteration<=1;state<=EXP_REDUCE;
            end
            EXP_REDUCE:begin exp_reduced<=exp_argument-64'(product);state<=EXP_TERM;end
            EXP_TERM:if(division_done)begin
                term_q<=exp_next_term;sum_q<=sum_q+exp_next_term;iteration<=iteration+6'd1;
                if(iteration==24)begin value_q<=sum_q+exp_next_term;state<=PACK;end
            end
            PACK:raw_finish(packed_value[31:0],packed_value[35:32]);
            COMPLETE:state<=IDLE;
            default:state<=IDLE;
        endcase
    end
endmodule
