// ASSUMPTION: iterative transcendental reconstruction uses convergent series
// on Intel's reduced domains; see the spec's approximation ledger.
// original Intel microcode and bit-identical transcendental rounding are not
// claimed. One shared integer-significand ALU executes every micro-operation.
module intel_8087_trans #(
    parameter int VARIANT = 0
) (
    input logic clk, rst_n, start_i,
    input logic [2:0] op_i, // 0=2xm1, 1=yl2x, 2=tan, 3=atan, 4=yl2xp1,
                            // 80387 only: 5=sin, 6=cos, 7=sincos
    input logic [79:0] x_i, y_i,
    output logic done_o,
    output logic [79:0] result_o,
    output logic [79:0] result2_o   // FSINCOS cosine (80387)
);
    localparam logic [79:0] ONE=80'h3fff8000000000000000;
    localparam logic [79:0] TWO=80'h40008000000000000000;
    localparam logic [79:0] LN2=80'h3ffeb17217f7d1cf79ac;
    localparam logic [79:0] TWO_LOG2E=80'h4000b8aa3b295c17f0bc;
    // 80387 trigonometric argument reduction uses Intel's documented 66-bit
    // pi, 0.C90FDAA22168C234C x 2^2 (a truncation of pi). In 2^-128 fixed
    // point, pi/2 = C90FDAA22168C234Ch << 61.
    localparam logic [129:0] HALF_PI_FX=130'h0c90fdaa22168c234c << 61;
    localparam logic [79:0] PI_4=80'h3ffec90fdaa22168c235;
    localparam logic [79:0] PI_2=80'h3fffc90fdaa22168c235;
    localparam logic [79:0] PI=80'h4000c90fdaa22168c235;
`include "intel_8087_math.svh"
    logic [5:0] phase;
    logic [2:0] operation;
    logic [6:0] iteration;
    logic [79:0] x,y,z,z2,term,sum,aux,base_exp;
    logic [79:0] a,b,value;
    // 80387 reduction and post-processing state.
    logic [191:0] red_x;
    logic [129:0] red_rem;
    logic [1:0] red_q;   // the two low quotient bits select the quadrant
    logic [7:0] red_i;
    logic [1:0] quad;
    logic xneg,yneg,swap,trig387,atan387,rneg;
    logic [130:0] red_trial;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [86:0] red_packed;   // only the magnitude (the sign is rneg) is used
    /* verilator lint_on UNUSEDSIGNAL */
    logic [3:0] alu_op;
    logic [5:0] unused_flags;
    logic unused_round;
    logic [3:0] unused_cc;
    intel_8087_alu #(.VARIANT(VARIANT)) alu(.enable_i(phase!=0),.a_i(a),.b_i(b),.op_i(alu_op),.control_i(16'h13ff),
        .result_o(value),.exceptions_o(unused_flags),.rounded_up_o(unused_round),.condition_o(unused_cc));
    always_comb begin
        a=0; b=0; alu_op=0;
        case(phase)
            1:begin a=x; b=LN2; alu_op=1; end
            2:begin a=term; b=z; alu_op=1; end
            3:begin a=aux; b=fp_integer({57'd0,iteration}); alu_op=3; end
            4:begin a=sum; b=term; end
            10:begin a=x; b=operation==4?TWO:ONE; end
            11:begin a=x; b=ONE; alu_op=2; end
            12:begin a=operation==4?x:z; b=aux; alu_op=3; end
            13:begin a=z; b=z; alu_op=1; end
            14:begin a=term; b=z2; alu_op=1; end
            15:begin a=term; b=fp_integer({56'd0,iteration,1'b1}); alu_op=3; end
            16:begin a=sum; b=aux; end
            17:begin a=sum; b=TWO_LOG2E; alu_op=1; end
            18:begin a=aux; b=base_exp; end
            19:begin a=sum; b=y; alu_op=1; end
            20:begin a=x; b=x; alu_op=1; end
            21:begin a=term; b=z2; alu_op=1; end
            22:begin a=aux; b=fp_integer(64'(int'(iteration)*2*(int'(iteration)*2+1))); alu_op=3; end
            23:begin a=sum; b=term; end
            24:begin a=term; b=z2; alu_op=1; end
            25:begin a=aux; b=fp_integer(64'((int'(iteration)*2-1)*int'(iteration)*2)); alu_op=3; end
            26:begin a=z; b=term; end
            27:begin a=sum; b=z; alu_op=3; end
            30:begin a=y; b=x; alu_op=3; end
            31:begin a=z; b=z; alu_op=1; end
            32:begin a=aux; b=ONE; end
            33:begin a=aux; alu_op=4; end
            34:begin a=aux; b=ONE; end
            35:begin a=z; b=aux; alu_op=3; end
            36:begin a=z; b=z; alu_op=1; end
            37:begin a=term; b=z2; alu_op=1; end
            38:begin a=term; b=fp_integer({56'd0,iteration,1'b1}); alu_op=3; end
            39:begin a=sum; b=aux; end
            40:begin a=sum; b=TWO; alu_op=1; end
            // 80387 FPATAN octant/quadrant adjustment and FPTAN quotient.
            41:begin a=PI_2; b=result_o; alu_op=2; end
            42:begin a=PI; b=result_o; alu_op=2; end
            43:begin a=quad[0]?z:sum; b=quad[0]?sum:z; alu_op=3; end
            default:begin end
        endcase
    end
    always_comb begin
        red_trial={red_rem,red_x[191]}-{1'b0,HALF_PI_FX};
        // Rounded quotient: the remainder becomes |x - q*pi/2| <= pi/4.
        red_packed=fp_pack(1'b0,-62,{1'b0,red_rem},2'd0,64,-16382,16383);
    end
    logic red_round_up;
    logic [129:0] red_mag;
    always_comb begin
        red_round_up=({red_rem,1'b0}>{1'b0,HALF_PI_FX})||({red_rem,1'b0}=={1'b0,HALF_PI_FX}&&red_q[0]);
        red_mag=red_round_up ? HALF_PI_FX-red_rem : red_rem;
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            phase<=0; done_o<=0; result_o<=0; result2_o<=0; operation<=0; iteration<=0;
            red_x<=0; red_rem<=0; red_q<=0; red_i<=0; quad<=0; xneg<=0; yneg<=0; swap<=0;
            trig387<=0; atan387<=0; rneg<=0;
            x<=0;y<=0;z<=0;z2<=0;term<=0;sum<=0;aux<=0;base_exp<=0;
        end else begin
            done_o<=0;
            if(start_i&&phase==0) begin
                operation<=op_i; x<=x_i; y<=y_i; iteration<=0; base_exp<=0;
                trig387<=0; atan387<=0; quad<=0; xneg<=x_i[79]; yneg<=y_i[79]; swap<=0;
                case(op_i)
                    0:phase<=1;
                    1:begin
                        x<={1'b0,15'h3fff,x_i[63:0]};
                        base_exp<=fp_integer(64'($signed({1'b0,x_i[78:64]})-17'sd16383));
                        phase<=10;
                    end
                    2,5,6,7:begin
                        if(VARIANT==2) begin
                            // 80387 FPTAN/FSIN/FCOS/FSINCOS on |x| < 2^63
                            // (finite, nonzero; the controller handles the
                            // rest): reduce |x| modulo pi/2 when |x| > pi/4.
                            trig387<=1; x<={1'b0,x_i[78:0]};
                            if({1'b0,x_i[78:0]}<=PI_4) phase<=20;
                            else begin
                                // |x| = M*2^(e-63), e in [-1,62]; X = M << (e+65).
                                red_x<={x_i[63:0],128'd0} >> (8'd63-8'(int'({1'b0,x_i[78:64]})-16383));
                                red_rem<=0; red_q<=0; red_i<=8'd192; phase<=50;
                            end
                        end else if(op_i==2) phase<=20;
                        else begin result_o<=FP_INDEF; done_o<=1; end
                    end
                    3:begin
                        if(VARIANT==2) begin
                            // 80387 FPATAN: atan of the smaller over the
                            // larger magnitude, then octant and quadrant.
                            atan387<=1;
                            if(y_i[78:0]>x_i[78:0]) begin swap<=1; x<={1'b0,y_i[78:0]}; y<={1'b0,x_i[78:0]}; end
                            else begin x<={1'b0,x_i[78:0]}; y<={1'b0,y_i[78:0]}; end
                        end
                        phase<=30;
                    end
                    4:phase<=10;
                    default:begin result_o<=FP_INDEF; done_o<=1; end
                endcase
            end else case(phase)
                1:begin z<=value; term<=value; sum<=value; iteration<=2; phase<=2; end
                2:begin aux<=value; phase<=3; end
                3:begin term<=value; phase<=4; end
                4:begin
                    sum<=value;
                    if(iteration==26) begin result_o<=value; phase<=0; done_o<=1; end
                    else begin iteration<=iteration+1'b1; phase<=2; end
                end
                10:begin aux<=value; phase<=operation==4?12:11; end
                11:begin z<=value; phase<=12; end
                12:begin z<=value; term<=value; sum<=value; iteration<=1; phase<=13; end
                13:begin z2<=value; phase<=14; end
                14:begin term<=value; phase<=15; end
                15:begin aux<=value; phase<=16; end
                16:begin
                    sum<=value;
                    if(iteration==40) phase<=17;
                    else begin iteration<=iteration+1'b1; phase<=14; end
                end
                17:begin aux<=value; phase<=18; end
                18:begin sum<=value; phase<=19; end
                19:begin result_o<=value; phase<=0; done_o<=1; end
                20:begin z2<=value; term<=x; sum<=x; iteration<=1; phase<=21; end
                21:begin aux<={~value[79],value[78:0]}; phase<=22; end
                22:begin term<=value; phase<=23; end
                23:begin
                    sum<=value;
                    if(iteration==14) begin term<=ONE; z<=ONE; iteration<=1; phase<=24; end
                    else begin iteration<=iteration+1'b1; phase<=21; end
                end
                24:begin aux<={~value[79],value[78:0]}; phase<=25; end
                25:begin term<=value; phase<=26; end
                26:begin
                    z<=value;
                    if(iteration==14) phase<=27;
                    else begin iteration<=iteration+1'b1; phase<=24; end
                end
                27:begin
                    if(trig387) begin
                        // sum = sin(r), z = cos(r); quadrant k = q mod 4.
                        case(operation)
                            5:begin
                                result_o<=quad[0] ? z : sum;
                                result_o[79]<=(quad[0] ? z[79] : sum[79]) ^ quad[1] ^ xneg;
                                phase<=0; done_o<=1;
                            end
                            6:begin
                                result_o<=quad[0] ? sum : z;
                                result_o[79]<=(quad[0] ? sum[79] : z[79]) ^ (quad[1]^quad[0]);
                                phase<=0; done_o<=1;
                            end
                            7:begin
                                result_o<=quad[0] ? z : sum;
                                result_o[79]<=(quad[0] ? z[79] : sum[79]) ^ quad[1] ^ xneg;
                                result2_o<=quad[0] ? sum : z;
                                result2_o[79]<=(quad[0] ? sum[79] : z[79]) ^ (quad[1]^quad[0]);
                                phase<=0; done_o<=1;
                            end
                            default:phase<=43;
                        endcase
                    end else begin result_o<=value; phase<=0; done_o<=1; end
                end
                43:begin
                    // tan = sin/cos for even k, -cos/sin for odd k; odd in x.
                    result_o<={value[79]^quad[0]^xneg,value[78:0]};
                    phase<=0; done_o<=1;
                end
                50:begin
                    // Bit-serial restoring division of the 2^-128 fixed-point
                    // |x| by pi/2: 192 steps.
                    if(!red_trial[130]) begin red_rem<=red_trial[129:0]; red_q<={red_q[0],1'b1}; end
                    else begin red_rem<={red_rem[128:0],red_x[191]}; red_q<={red_q[0],1'b0}; end
                    red_x<={red_x[190:0],1'b0};
                    red_i<=red_i-8'd1;
                    if(red_i==8'd1) phase<=51;
                end
                51:begin
                    red_rem<=red_mag; rneg<=red_round_up;
                    quad<=red_q[1:0]+{1'b0,red_round_up};
                    phase<=52;
                end
                52:begin
                    // r = +/-|x - q*pi/2| in extended precision.
                    x<={rneg,red_packed[78:0]};
                    phase<=20;
                end
                30:begin z<=value; phase<=31; end
                31:begin aux<=value; phase<=32; end
                32:begin aux<=value; phase<=33; end
                33:begin aux<=value; phase<=34; end
                34:begin aux<=value; phase<=35; end
                35:begin z<=value; term<=value; sum<=value; iteration<=1; phase<=36; end
                36:begin z2<=value; phase<=37; end
                37:begin term<={~value[79],value[78:0]}; phase<=38; end
                38:begin aux<=value; phase<=39; end
                39:begin
                    sum<=value;
                    if(iteration==50) phase<=40;
                    else begin iteration<=iteration+1'b1; phase<=37; end
                end
                40:begin
                    result_o<=value;
                    if(atan387&&(swap||xneg)) phase<=swap ? 41:42;
                    else if(atan387) begin result_o<={yneg,value[78:0]}; phase<=0; done_o<=1; end
                    else begin phase<=0; done_o<=1; end
                end
                41:begin
                    result_o<=value;
                    if(xneg) phase<=42;
                    else begin result_o<={yneg,value[78:0]}; phase<=0; done_o<=1; end
                end
                42:begin result_o<={yneg,value[78:0]}; phase<=0; done_o<=1; end
                default:begin end
            endcase
        end
    end
endmodule
