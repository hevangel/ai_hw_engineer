module intel_8087_alu (
    input logic [79:0] a_i, b_i,
    input logic [3:0] op_i,
    input logic [15:0] control_i,
    output logic [79:0] result_o,
    output logic [5:0] exceptions_o,
    output logic rounded_up_o,
    output logic [3:0] condition_o
);
`include "intel_8087_math.svh"
    integer ea, eb, exponent, precision, delta, scale;
    logic sa, sb, sign_value;
    logic [63:0] ma, mb;
    logic [130:0] va, vb, magnitude, numerator, quotient, remainder_value;
    logic [127:0] product;
    logic [65:0] sqrt_remainder, trial;
    logic [63:0] root;
    logic [86:0] packed_value, integer_value, wrapped_value;
    logic invalid, infinity_result, zero_result, bypass;
    logic unused_control;
    assign unused_control = ^{control_i[15:13],control_i[7:0],integer_value[79:64],wrapped_value[84:80]};
    always_comb begin
        ea=(a_i[78:64]==0?1:int'({1'b0,a_i[78:64]}))-16383;
        eb=(b_i[78:64]==0?1:int'({1'b0,b_i[78:64]}))-16383;
        ma=a_i[63:0]; mb=b_i[63:0]; sa=a_i[79]; sb=b_i[79];
        va=0; vb=0; magnitude=0; numerator=0; quotient=0; remainder_value=0;
        product=0; root=0; sqrt_remainder=0; trial=0; packed_value=0; integer_value=0;wrapped_value=0;
        exponent=ea; sign_value=sa; delta=0; scale=0;
        invalid=0; infinity_result=0; zero_result=0; bypass=0;
        result_o=FP_INDEF; exceptions_o=0; rounded_up_o=0; condition_o=0;
        // ASSUMPTION: reserved PC=01 uses 64 bits; excluded from compatibility.
        precision=control_i[9:8]==0 ? 24 : (control_i[9:8]==2 ? 53:64);
        if(a_i[78:64]==0 && ma!=0) exceptions_o[1]=1;
        if(b_i[78:64]==0 && mb!=0 && op_i!=4 && op_i!=5) exceptions_o[1]=1;
        // Normalize denormal significands before arithmetic.
        for(integer k=0;k<63;k=k+1) begin
            if(ma!=0&&!ma[63]) begin ma=ma<<1; ea=ea-1; end
            if(mb!=0&&!mb[63]) begin mb=mb<<1; eb=eb-1; end
        end
        if(op_i==2) sb=!sb;
        exponent=ea;
        case(op_i)
            0,2:begin
                exponent=ea>eb?ea:eb;
                va=fp_shr({64'd0,ma,3'd0},exponent-ea);
                vb=fp_shr({64'd0,mb,3'd0},exponent-eb);
                if(sa==sb) magnitude=va+vb;
                else if(va>vb) magnitude=va-vb;
                else begin magnitude=vb-va; sign_value=sb; end
                if(magnitude==0) sign_value=(sa==sb)?sa:(control_i[11:10]==1);
                infinity_result=fp_inf(a_i)||fp_inf(b_i);
                if(fp_inf(a_i)&&fp_inf(b_i)&&(!control_i[12]||sa!=sb)) invalid=1;
                if(fp_inf(b_i)&&!fp_inf(a_i)) sign_value=sb;
            end
            1:begin
                sign_value=sa^sb; exponent=ea+eb;
                product=ma*mb;
                magnitude=fp_shr({3'd0,product},60);
                infinity_result=fp_inf(a_i)||fp_inf(b_i);
                if(infinity_result&&(fp_zero(a_i)||fp_zero(b_i))) invalid=1;
            end
            3:begin
                sign_value=sa^sb; exponent=ea-eb;
                numerator={1'b0,ma,66'd0};
                if(mb!=0) begin
                    quotient=numerator/{67'd0,mb};
                    remainder_value=numerator%{67'd0,mb};
                    magnitude=quotient|{130'd0,(remainder_value!=0)};
                end
                infinity_result=fp_inf(a_i)||fp_zero(b_i);
                zero_result=fp_inf(b_i)||fp_zero(a_i);
                if(fp_zero(b_i)&&!fp_zero(a_i)&&!fp_inf(a_i)) exceptions_o[2]=1;
                if((fp_inf(a_i)&&fp_inf(b_i)) || (fp_zero(a_i)&&fp_zero(b_i)) ||
                    (b_i[78:64]==0&&b_i[63:0]!=0)||(!b_i[63]&&!fp_zero(b_i))) invalid=1;
            end
            4:begin
                invalid=fp_bad(a_i)||(sa&&!fp_zero(a_i)) ||
                    (a_i[78:64]==0&&!fp_zero(a_i)) || (fp_inf(a_i)&&!control_i[12]);
                infinity_result=fp_inf(a_i); zero_result=fp_zero(a_i);
                // Restoring square root, 64 output significand bits plus
                // a remainder-derived rounding decision below.
                numerator={3'd0,ma,64'd0};
                if((ea&1)==0) numerator=numerator>>1;
                exponent=ea>>>1;
                for(integer k=63;k>=0;k=k-1) begin
                    sqrt_remainder=(sqrt_remainder<<2)|{64'd0,numerator[k*2+:2]};
                    trial={root,2'b01};
                    if(sqrt_remainder>=trial) begin
                        sqrt_remainder=sqrt_remainder-trial; root=(root<<1)|64'd1;
                    end else root=root<<1;
                end
                // sqrt(N)-root >= 1/2 iff remainder > root.
                magnitude={64'd0,root,3'd0};
                if(sqrt_remainder>{2'd0,root}) magnitude=magnitude|131'd5;
                else if(sqrt_remainder!=0) magnitude=magnitude|131'd1;
            end
            5:begin
                invalid=fp_bad(a_i); bypass=1; result_o=a_i;
                if(ea<63&&!fp_inf(a_i)&&!fp_nan(a_i)) begin
                    integer_value=fp_to_integer(a_i,control_i[11:10],64);
                    result_o=fp_integer(integer_value[63:0]);
                    if(result_o[78:0]==0) result_o[79]=sa;
                    exceptions_o=integer_value[85:80]; rounded_up_o=integer_value[86];
                end
            end
            6:begin
                integer_value=fp_to_integer(b_i,3,16);
                scale=int'($signed(integer_value[15:0]));
                exponent=ea+scale; magnitude={64'd0,ma,3'd0};
                infinity_result=fp_inf(a_i); zero_result=fp_zero(a_i);
            end
            7:begin
                invalid=fp_bad(b_i)||fp_inf(a_i)||fp_zero(b_i)||b_i[78:64]==0;
                bypass=1; result_o=a_i;
                delta=ea-eb;
                if(delta>=0&&!invalid) begin
                    // Reduce at most 63 quotient bits per invocation.
                    scale=delta>63 ? delta-63:0;
                    numerator={67'd0,ma}<<(delta-scale);
                    quotient=numerator/{67'd0,mb};
                    remainder_value=numerator%{67'd0,mb};
                    packed_value=fp_pack(sa,eb+scale+3,remainder_value,3,64,-16382,16383);
                    result_o=packed_value[79:0];
                    // Intel 8087 datasheet table 4a: C3=Q1,C1=Q0,C0=Q2.
                    condition_o={quotient[1],(delta>63),quotient[0],quotient[2]};
                end
                exceptions_o[5]=0;
            end
            default:begin invalid=1; end
        endcase
        if(fp_nan(a_i)||((op_i!=4&&op_i!=5)&&fp_nan(b_i))) begin
            result_o=fp_nan(a_i)?a_i:b_i;
            if(fp_nan(a_i)&&fp_nan(b_i)&&b_i[78:0]>a_i[78:0]) result_o=b_i;
            // Original 8087 propagates the larger NaN and signals invalid;
            // it does not implement the later quiet-NaN exception exemption.
            bypass=1; exceptions_o[0]=1; invalid=0;
        end else if(!bypass) begin
            if(infinity_result) result_o={sign_value,15'h7fff,64'h8000000000000000};
            else if(zero_result) result_o={sign_value,79'd0};
            else begin
                packed_value=fp_pack(sign_value,exponent,magnitude,control_i[11:10],
                    (op_i==6?64:precision),-16382,16383);
                if((packed_value[83]&&!control_i[3])||(packed_value[84]&&!control_i[4])) begin
                    // Intel S-20 table S-6: register traps retain a scaled
                    // result, with the exponent adjusted by 24576.
                    wrapped_value=fp_pack(sign_value,exponent+(packed_value[83]?-24576:24576),
                        magnitude,control_i[11:10],(op_i==6?64:precision),-16382,16383);
                    packed_value[79:0]=wrapped_value[79:0];
                    packed_value[85]=wrapped_value[85];packed_value[86]=wrapped_value[86];
                end
                result_o=packed_value[79:0]; exceptions_o=exceptions_o|packed_value[85:80];
                rounded_up_o=packed_value[86];
            end
        end
        if(invalid) begin result_o=FP_INDEF; exceptions_o[0]=1; end
    end
endmodule
