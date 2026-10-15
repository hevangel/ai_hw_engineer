// ASSUMPTION: iterative transcendental reconstruction uses convergent series
// on Intel's reduced domains; see the spec's approximation ledger.
// original Intel microcode and bit-identical transcendental rounding are not
// claimed. One shared integer-significand ALU executes every micro-operation.
module intel_8087_trans (
    input logic clk, rst_n, start_i,
    input logic [2:0] op_i, // 0=2xm1, 1=yl2x, 2=tan, 3=atan, 4=yl2xp1
    input logic [79:0] x_i, y_i,
    output logic done_o,
    output logic [79:0] result_o
);
    localparam logic [79:0] ONE=80'h3fff8000000000000000;
    localparam logic [79:0] TWO=80'h40008000000000000000;
    localparam logic [79:0] LN2=80'h3ffeb17217f7d1cf79ac;
    localparam logic [79:0] TWO_LOG2E=80'h4000b8aa3b295c17f0bc;
`include "intel_8087_math.svh"
    logic [5:0] phase;
    logic [2:0] operation;
    logic [6:0] iteration;
    logic [79:0] x,y,z,z2,term,sum,aux,base_exp;
    logic [79:0] a,b,value;
    logic [3:0] alu_op;
    logic [5:0] unused_flags;
    logic unused_round;
    logic [3:0] unused_cc;
    intel_8087_alu alu(.a_i(a),.b_i(b),.op_i(alu_op),.control_i(16'h13ff),
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
            default:begin end
        endcase
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            phase<=0; done_o<=0; result_o<=0; operation<=0; iteration<=0;
            x<=0;y<=0;z<=0;z2<=0;term<=0;sum<=0;aux<=0;base_exp<=0;
        end else begin
            done_o<=0;
            if(start_i&&phase==0) begin
                operation<=op_i; x<=x_i; y<=y_i; iteration<=0; base_exp<=0;
                case(op_i)
                    0:phase<=1;
                    1:begin
                        x<={1'b0,15'h3fff,x_i[63:0]};
                        base_exp<=fp_integer(64'($signed({1'b0,x_i[78:64]})-17'sd16383));
                        phase<=10;
                    end
                    2:phase<=20;
                    3:phase<=30;
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
                27:begin result_o<=value; phase<=0; done_o<=1; end
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
                40:begin result_o<=value; phase<=0; done_o<=1; end
                default:begin end
            endcase
        end
    end
endmodule
