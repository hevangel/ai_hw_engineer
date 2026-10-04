`timescale 1ns/1ps
// Native Am9511 basic floating arithmetic and integer conversions.
// cmd: 10 add, 11 subtract, 12 multiply, 13 divide, 1c/1d float,
// 1e/1f fix. Manufacturer number format; no IEEE encodings in RTL.
module amd_am9511_float (
    input logic clk_i, reset_i, start_i,
    input logic [4:0] operation_i,
    input logic [31:0] a_i, b_i,
    output logic done_o,
    output logic busy_o,
    output logic [31:0] result_o,
    output logic [6:0] status_o,
    output logic float_result_o, single_result_o
);
    logic [35:0] calculation;
    logic [31:0] result;
    logic [3:0] error;
    logic float_result, single_result;
    logic a_zero, b_zero, sa, sb, result_sign;
    integer ea, eb, emax, distance, pack_scale;
    logic [63:0] ma, mb, magnitude, pack_value;
    logic pack_sign, bypass_pack;
    logic division_wait, division_start, division_busy, division_done, division_sign;
    integer division_scale;
    logic [127:0] division_quotient;
    logic [63:0] division_remainder;
    logic unused_division_zero;
    logic unused_quotient_high;
    logic [31:0] integer_value;
    logic [31:0] fixed_operand, fixed_magnitude;
    logic [47:0] product;

    function automatic [63:0] shifted_sticky(input logic [63:0] value,input integer amount);
        logic [63:0] discarded_mask;
        begin
            discarded_mask=0;
            if(amount<=0)shifted_sticky=value;
            else if(amount>=64)shifted_sticky={63'd0,(value!=0)};
            else begin
                discarded_mask=(64'hffffffffffffffff>>(64-amount));
                shifted_sticky=(value>>amount) | {63'd0,((value&discarded_mask)!=0)};
            end
        end
    endfunction

    // Pack magnitude * 2^scale to the native format, wrapping erroneous
    // exponents by 128 as explicitly specified in the manufacturer brief.
    function automatic [35:0] packed_float(input logic [63:0] value,
        input integer scale,input logic negative);
        integer leading, exponent_value, shift_count;
        logic [23:0] mantissa;
        logic [63:0] tail_mask;
        logic [24:0] rounded;
        logic guard_bit, sticky_bit;
        logic [3:0] error_code;
        begin
            leading=0;
            for(integer bit_index=0;bit_index<64;bit_index=bit_index+1)
                if(value[bit_index])leading=bit_index;
            exponent_value=scale+leading+1;
            shift_count=leading-23;
            mantissa=0; tail_mask=0; guard_bit=0; sticky_bit=0;
            if(shift_count>0)begin
                mantissa=24'(value>>shift_count);
                guard_bit=value[shift_count-1];
                if(shift_count>1)begin
                    tail_mask=64'hffffffffffffffff>>(65-shift_count);
                    sticky_bit=(value&tail_mask)!=0;
                end
            end else mantissa=24'(value<<(-shift_count));
            // ASSUMPTION: nearest-even mantissa rounding. Original 1978/1979
            // descriptions do not specify a tie mode; independent host-float
            // emulator uses IEEE host rounding. Original DEMAND/POLL rounding ties pass.
            rounded={1'b0,mantissa[23:0]} + {24'd0,(guard_bit&&(sticky_bit||mantissa[0]))};
            if(rounded[24])begin
                rounded=rounded>>1; exponent_value=exponent_value+1;
            end
            error_code=0;
            if(exponent_value>63)error_code=1;
            if(exponent_value < -64)error_code=2;
            if(value==0)packed_float=0;
            else packed_float={error_code,negative,7'(exponent_value),rounded[23:0]};
        end
    endfunction

    always_comb begin
        a_zero=!a_i[23]; b_zero=!b_i[23];
        sa=a_i[31]^(operation_i==5'h11); sb=b_i[31];
        ea=int'($signed(a_i[30:24])); eb=int'($signed(b_i[30:24]));
        emax=a_zero ? eb : b_zero ? ea : ea>eb ? ea : eb;
        distance=0;
        ma=0; mb=0; magnitude=0;
        product=0; integer_value=0; fixed_operand=0; fixed_magnitude=0;
        calculation=0; result_sign=0;
        pack_value=0; pack_scale=0; pack_sign=0; bypass_pack=0;
        float_result=1; single_result=0;
        case(operation_i)
            5'h10,5'h11: begin
                ma=a_zero ? 0 : shifted_sticky({8'd0,a_i[23:0],32'd0},emax-ea);
                mb=b_zero ? 0 : shifted_sticky({8'd0,b_i[23:0],32'd0},emax-eb);
                if(sa==sb)begin magnitude=ma+mb;result_sign=sa;end
                else if(ma>mb)begin magnitude=ma-mb;result_sign=sa;end
                else begin magnitude=mb-ma;result_sign=sb;end
                pack_value=magnitude;pack_scale=emax-56;pack_sign=result_sign;
            end
            5'h12: begin
                product=a_i[23:0]*b_i[23:0];
                pack_value=(a_zero||b_zero) ? 0 : {16'd0,product};
                pack_scale=ea+eb-48;pack_sign=sa^b_i[31];
            end
            5'h13: begin
                if(a_zero)begin calculation={4'd8,b_i};bypass_pack=1;end
                else begin pack_value=0;end
            end
            5'h1c,5'h1d: begin
                fixed_operand=(operation_i==5'h1d) ? {{16{a_i[15]}},a_i[15:0]} : a_i;
                fixed_magnitude=fixed_operand[31] ? ~fixed_operand+32'd1 : fixed_operand;
                pack_value={32'd0,fixed_magnitude};pack_sign=fixed_operand[31];
            end
            5'h1e,5'h1f: begin
                single_result=operation_i==5'h1f;
                bypass_pack=1;
                distance=ea-24;
                if(!a_zero)begin
                    if(distance>=0)integer_value={8'd0,a_i[23:0]}<<distance;
                    else if(distance > -32)integer_value={8'd0,a_i[23:0]}>>(-distance);
                end
                // Original FIX descriptions reject an integer portion wider
                // than 15/31 bits and retain the original float on overflow.
                if(!a_zero && ea>(single_result ? 15 : 31))begin
                    calculation={4'd1,a_i}; single_result=0;
                end else begin
                    float_result=0;
                    calculation={4'd0,(sa ? ~integer_value[31:0]+32'd1 : integer_value[31:0])};
                    if(single_result)calculation[31:16]=0;
                end
            end
            default: begin calculation=0;bypass_pack=1;end
        endcase
        if(division_wait && division_done)begin
            // Normalized 24-bit operands guarantee a quotient below 2^34.
            pack_value={29'd0,division_quotient[33:0],1'b0}|{63'd0,(division_remainder!=0)};
            pack_scale=division_scale;pack_sign=division_sign;bypass_pack=0;
            float_result=1;single_result=0;
        end
        if(!bypass_pack)calculation=packed_float(pack_value,pack_scale,pack_sign);
        result=calculation[31:0]; error=calculation[35:32];
    end

    assign division_start=start_i&&!division_wait && operation_i==5'h13 && !a_zero&&!b_zero;
    assign busy_o=division_wait;
    assign unused_quotient_high=^division_quotient[127:34];
    amd_am9511_divider divider(.clk_i(clk_i),.reset_i(reset_i),.start_i(division_start),.signed_i(1'b0),
        .numerator_i({72'd0,b_i[23:0],32'd0}),.denominator_i({40'd0,a_i[23:0]}),
        .busy_o(division_busy),.done_o(division_done),.zero_o(unused_division_zero),
        .quotient_o(division_quotient),.remainder_o(division_remainder));
    logic unused_division_busy;
    assign unused_division_busy=division_busy;
    always_ff @(posedge clk_i)begin
        if(reset_i)begin
            done_o<=0; result_o<=0; status_o<=0; float_result_o<=1; single_result_o<=0;
            division_wait<=0;division_sign<=0;division_scale<=0;
        end else begin
            done_o<=0;
            if(start_i&&!division_wait&&division_start)begin
                division_wait<=1;division_sign<=sa^b_i[31];division_scale<=eb-ea-33;
            end else if((start_i&&!division_wait) || (division_wait&&division_done))begin
                done_o<=1;division_wait<=0;
                result_o<=result;
                status_o<={single_result ? result[15] : result[31],
                    float_result ? !result[23] : (single_result ? result[15:0]==0 : result==0),error,1'b0};
                float_result_o<=float_result; single_result_o<=single_result;
            end
        end
    end
endmodule
