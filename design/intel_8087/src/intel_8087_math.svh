// Integer-only extended-real primitives. Included inside modules.
/* verilator lint_off UNUSEDSIGNAL */
localparam logic [79:0] FP_INDEF = 80'hffffc000000000000000;

function automatic logic fp_zero(input logic [79:0] x);
    fp_zero = x[78:0] == 0;
endfunction
function automatic logic fp_inf(input logic [79:0] x);
    fp_inf = x[78:64] == 15'h7fff && x[63:0] == 64'h8000000000000000;
endfunction
function automatic logic fp_nan(input logic [79:0] x);
    fp_nan = x[78:64] == 15'h7fff && x[62:0] != 0;
endfunction
function automatic logic fp_bad(input logic [79:0] x);
    fp_bad = (x[78:64] != 0 && !x[63]) || (fp_nan(x) && !x[62]);
endfunction
function automatic logic [1:0] fp_tag(input logic [79:0] x);
    if(fp_zero(x)) fp_tag = 1;
    else if(x[78:64] == 0 || x[78:64] == 15'h7fff) fp_tag = 2;
    else fp_tag = 0;
endfunction
function automatic logic [130:0] fp_shr(input logic [130:0] x, input integer n);
    logic [130:0] mask;
    begin
        mask = 0;
        if(n <= 0) fp_shr = x;
        else if(n >= 131) fp_shr = {130'd0, (x != 0)};
        else begin
            mask = {131{1'b1}} >> (131-n);
            fp_shr = (x >> n) | {130'd0, ((x & mask) != 0)};
        end
    end
endfunction

// Returns {rounded-up, exception[5:0], temporary-real}. Value is
// magnitude * 2^(exponent-66); normalized input has its leading bit at 66.
function automatic logic [86:0] fp_pack(input logic sign_bit,
    input integer exponent, input logic [130:0] magnitude,
    input logic [1:0] rc, input integer precision,
    input integer emin, input integer emax);
    integer lead, exp_value, discard;
    logic [130:0] value, tail_mask, kept, rounded;
    logic guard_bit, sticky_bit, inexact, increment, tiny;
    logic [5:0] flags;
    logic [79:0] result;
    begin
        value=magnitude; lead=0; flags=0; result={sign_bit,79'd0};
        increment=0; tail_mask=0; kept=0; rounded=0;
        guard_bit=0; sticky_bit=0; inexact=0;
        exp_value=exponent; discard=0; tiny=0;
        for(integer k=0;k<131;k=k+1) if(value[k]) lead=k;
        if(value != 0) begin
            exp_value=exponent+lead-66;
            tiny=exp_value<emin;
            if(lead>66) value=fp_shr(value,lead-66);
            else value=value<<(66-lead);
            if(exp_value<emin) begin
                value=fp_shr(value,emin-exp_value); exp_value=emin;
            end
            discard=67-precision;
            tail_mask={131{1'b1}}>>(131-discard);
            guard_bit=value[discard-1];
            sticky_bit=(value & (tail_mask>>1))!=0;
            inexact=(value & tail_mask)!=0;
            kept=value>>discard;
            case(rc)
                0:increment=guard_bit&&(sticky_bit||kept[0]);
                1:increment=sign_bit&&inexact;
                2:increment=!sign_bit&&inexact;
                default:increment=0;
            endcase
            rounded=kept+{130'd0,increment};
            if(rounded[precision]) begin rounded=rounded>>1; exp_value=exp_value+1; end
            value=rounded<<(64-precision);
            flags[5]=inexact;
            flags[4]=tiny;
            if(exp_value>emax) begin
                flags[3]=1; flags[5]=1;
                // Original 8087 chop overflows to infinity (Intel S-80).
                if((rc==1&&!sign_bit) || (rc==2&&sign_bit))
                    result={sign_bit,15'(emax+16383),64'hffffffffffffffff} &
                           {16'hffff,({64{1'b1}}<<(64-precision))};
                else result={sign_bit,15'h7fff,64'h8000000000000000};
            end else if(value==0) begin
                result={sign_bit,79'd0};
            end else begin
                // A narrower destination's denormal still has a normal
                // temporary-real exponent. Conversion removes that bias.
                if(exp_value==-16382 && !value[63]) result={sign_bit,15'd0,value[63:0]};
                else result={sign_bit,15'(exp_value+16383),value[63:0]};
            end
        end
        fp_pack={increment,flags,result};
    end
endfunction

function automatic logic [79:0] fp_integer(input logic [63:0] bits_value);
    logic negative;
    logic [63:0] magnitude;
    logic [86:0] packed_value;
    begin
        negative=bits_value[63]; magnitude=negative ? (~bits_value+64'd1) : bits_value;
        packed_value=fp_pack(negative,66,{67'd0,magnitude},0,64,-16382,16383);
        fp_integer=packed_value[79:0];
    end
endfunction

// format: 0=real32, 1=real64, 2=real80, 3=int16, 4=int32,
// 5=int64, 6=BCD. Loads preserve full precision, independent of PC.
function automatic logic [85:0] fp_load(input logic [79:0] bits_value,
    input logic [2:0] format_value);
    logic [79:0] value;
    logic [63:0] mantissa, integer_bits;
    logic [5:0] flags;
    logic sign_bit;
    integer exp_value;
    logic [86:0] packed_value;
    begin
        flags=0; value=bits_value; mantissa=0; integer_bits=0;
        sign_bit=0; exp_value=0; packed_value=0;
        case(format_value)
            0,1:begin
                if(format_value==0) begin
                    sign_bit=bits_value[31]; exp_value=int'({1'b0,bits_value[30:23]});
                    mantissa={1'b0,bits_value[22:0],40'd0};
                    if(exp_value==255) begin
                        value={sign_bit,15'h7fff,1'b1,bits_value[22:0],40'd0};
                    end else begin
                        if(exp_value!=0) mantissa[63]=1;
                        else if(mantissa!=0) flags[1]=1;
                        exp_value=(exp_value==0 ? 1:exp_value)-127;
                        packed_value=fp_pack(sign_bit,exp_value,{64'd0,mantissa,3'd0},0,64,-16382,16383);
                        value=packed_value[79:0];
                    end
                end else begin
                    sign_bit=bits_value[63]; exp_value=int'({1'b0,bits_value[62:52]});
                    mantissa={1'b0,bits_value[51:0],11'd0};
                    if(exp_value==2047) begin
                        value={sign_bit,15'h7fff,1'b1,bits_value[51:0],11'd0};
                    end else begin
                        if(exp_value!=0) mantissa[63]=1;
                        else if(mantissa!=0) flags[1]=1;
                        exp_value=(exp_value==0 ? 1:exp_value)-1023;
                        packed_value=fp_pack(sign_bit,exp_value,{64'd0,mantissa,3'd0},0,64,-16382,16383);
                        value=packed_value[79:0];
                    end
                end
            end
            2:begin end // FLD temporary-real is an exact bit transfer.
            3:value=fp_integer({{48{bits_value[15]}},bits_value[15:0]});
            4:value=fp_integer({{32{bits_value[31]}},bits_value[31:0]});
            5:value=fp_integer(bits_value[63:0]);
            6:begin
                for(integer k=17;k>=0;k=k-1) begin
                    if(bits_value[k*4+:4]>9) flags[0]=1;
                    integer_bits=integer_bits*64'd10+{60'd0,bits_value[k*4+:4]};
                end
                if(bits_value[79]) integer_bits=~integer_bits+64'd1;
                value=flags[0] ? FP_INDEF:fp_integer(integer_bits);
            end
            default:value=FP_INDEF;
        endcase
        fp_load={flags,value};
    end
endfunction

function automatic logic [86:0] fp_to_integer(input logic [79:0] x,
    input logic [1:0] rc, input integer width_value);
    integer exponent, distance;
    logic [130:0] magnitude, mask_value, rounded;
    logic increment, inexact, guard_bit, sticky_bit;
    logic [5:0] flags;
    logic [63:0] result;
    begin
        exponent=int'({1'b0,x[78:64]})-16383;
        magnitude={67'd0,x[63:0]}; distance=63-exponent;
        mask_value=0; increment=0; inexact=0; guard_bit=0; sticky_bit=0; flags=0;
        if(distance>0) begin
            if(distance>=131) begin inexact=magnitude!=0; magnitude=0; end
            else begin
                mask_value={131{1'b1}}>>(131-distance);
                guard_bit=magnitude[distance-1];
                sticky_bit=(magnitude&(mask_value>>1))!=0;
                inexact=(magnitude&mask_value)!=0;
                magnitude=magnitude>>distance;
            end
            case(rc)
                0:increment=guard_bit&&(sticky_bit||magnitude[0]);
                1:increment=x[79]&&inexact;
                2:increment=!x[79]&&inexact;
                default:increment=0;
            endcase
        end else if(distance>=-67) magnitude=magnitude<<(-distance);
        else flags[0]=1;
        rounded=magnitude+{130'd0,increment};
        if(fp_nan(x)||fp_inf(x)||fp_bad(x)||exponent>63) flags[0]=1;
        if(rounded > (131'd1<<(width_value-1)) ||
            (rounded==(131'd1<<(width_value-1))&&!x[79])) flags[0]=1;
        result=x[79] ? (~rounded[63:0]+64'd1):rounded[63:0];
        if(x[78:64]==0 && x[63:0]!=0) flags[0]=1;
        if(flags[0]) result=64'd1<<(width_value-1);
        else flags[5]=inexact;
        fp_to_integer={increment,flags,16'd0,result};
    end
endfunction

function automatic logic [86:0] fp_store(input logic [79:0] x,
    input logic [2:0] format_value, input logic [1:0] rc);
    logic [86:0] converted;
    logic [79:0] value, result;
    logic [63:0] magnitude;
    logic [5:0] flags;
    logic increment;
    integer bias_value, exponent;
    begin
        result=x; value=x; converted=0; flags=0; magnitude=0;
        bias_value=0; exponent=0; increment=0;
        case(format_value)
            0,1:begin
                bias_value=format_value==0 ? 127:1023;
                if(fp_nan(x)||fp_inf(x)) begin
                    if(format_value==0) result={48'd0,x[79],8'hff,x[62:40]};
                    else result={16'd0,x[79],11'h7ff,x[62:11]};
                end else if(fp_bad(x)) begin result= format_value==0 ? 80'hffc00000:80'hfff8000000000000; flags[0]=1; end
                else begin
                    converted=fp_pack(x[79],(x[78:64]==0?1:int'({1'b0,x[78:64]}))-16383,
                        {64'd0,x[63:0],3'd0},rc,format_value==0?24:53,
                        1-bias_value,bias_value);
                    value=converted[79:0]; flags=converted[85:80]; increment=converted[86];
                    exponent=int'({1'b0,value[78:64]})-16383+bias_value;
                    if(fp_zero(value)) exponent=0;
                    else if(fp_inf(value)) exponent=2*bias_value+1;
                    else if(!value[63]) exponent=0;
                    if(format_value==0) result={48'd0,value[79],8'(exponent),value[62:40]};
                    else result={16'd0,value[79],11'(exponent),value[62:11]};
                end
            end
            2:begin end
            3,4,5:begin
                converted=fp_to_integer(x,rc,format_value==3?16:(format_value==4?32:64));
                result=converted[79:0]; flags=converted[85:80]; increment=converted[86];
            end
            6:begin
                converted=fp_to_integer(x,rc,64); flags=converted[85:80]; increment=converted[86];
                magnitude=x[79] ? (~converted[63:0]+64'd1):converted[63:0];
                result={x[79],79'd0};
                if(magnitude>64'd999999999999999999 || flags[0]) begin
                    flags=6'b000001; result=80'hffffc000000000000000;
                end else for(integer k=0;k<18;k=k+1) begin
                    result[k*4+:4]=4'(magnitude%10); magnitude=magnitude/10;
                end
            end
            default:begin result=FP_INDEF; flags[0]=1; end
        endcase
        fp_store={increment,flags,result};
    end
endfunction
/* verilator lint_on UNUSEDSIGNAL */
