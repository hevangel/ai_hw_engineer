// ASSUMPTION: functional ESC transactions replace native queue snooping and
// RQ/GT arbitration; see spec/spec.md for the integration boundary.
// VARIANT selects the member of the x87 family that this shared controller
// implements: 0 = 8087 (this design), 1 = 80287 (design/intel_80287),
// 2 = 80387 (design/intel_80387). Each variant's differences are specified
// in its own design folder; VARIANT 0 keeps the 8087 contract unchanged.
module intel_8087 #(
    parameter int VARIANT = 0,
    parameter int AW = 20
) (
    input logic clk, rst_n,
    input logic cmd_valid_i,
    output logic cmd_ready_o,
    input logic [7:0] opcode_i, modrm_i,
    input logic [AW-1:0] address_i, instruction_i,
    input logic cpu_wait_i,
    // 80287/80387 pointer-image inputs and FSTSW AX output (unused by 8087).
    input logic [15:0] cs_sel_i, ds_sel_i,
    input logic protected_i, opsize32_i,
    output logic ax_write_o,
    output logic [15:0] ax_o,
    output logic mem_valid_o, mem_write_o,
    output logic [AW-1:0] mem_address_o,
    output logic [7:0] mem_wdata_o,
    input logic mem_ready_i,
    input logic [7:0] mem_rdata_i,
    output logic busy_o, int_o, done_o, unsupported_o,
    output logic [15:0] control_o, status_o, tags_o,
    output logic [639:0] registers_o
);
`ifdef FORMAL_CONTROL
`include "intel_8087_control_math.svh"
`else
`include "intel_8087_math.svh"
`endif
    localparam logic [79:0] ONE=80'h3fff8000000000000000;
    // FINIT control word: 03FFh for the 8087 and 80287 (286PRM table 3-1),
    // 037Fh for the 80387 (387PRM section 4.7).
    localparam logic [15:0] INIT_CW = VARIANT==2 ? 16'h037f : 16'h03ff;
    // Pointer-image formats: 0 = 16-bit real (8087 layout), 1 = 16-bit
    // protected, 2 = 32-bit real, 3 = 32-bit protected (387PRM fig. 2-5..2-8).
    logic [1:0] image_format;
    localparam logic [2:0] IDLE=0,READ=1,EXEC=2,TRANS_START=3,TRANS_WAIT=4,WRITE=5;
    logic [2:0] state;
    logic [7:0] opcode,modrm;
    logic [AW-1:0] address,inst_pointer,operand_pointer,command_inst;
    logic [15:0] cs_q,ds_q,inst_sel,operand_sel,next_inst_sel,next_operand_sel;
    logic pm_q,next_pm,prot_q,op32_q,ax_request;
    logic [15:0] status_image;
    logic [31:0] ip_wide,op_wide;
    logic stack_fault,stack_c1;
    logic [10:0] last_opcode;
    logic [6:0] count,length_q;
    logic [2:0] format_q;
    logic [863:0] buffer_q,write_buffer;
    logic [639:0] stack_q,next_stack;
    logic [15:0] tags_q,next_tags,cw_q,next_cw,sw_q,next_sw;
    logic [2:0] top_q,next_top,index_i,index_one,index_push;
    logic [79:0] st0,sti,st1,source,alu_a,alu_b,alu_result,value;
    logic [85:0] loaded;
    logic [86:0] converted;
    logic [3:0] alu_op,alu_cc;
    logic [5:0] alu_flags,flags;
    logic alu_round,write_command,bad_encoding,begin_trans,blocked;
    logic [2:0] trans_op;
    logic trans_done;
    logic [79:0] trans_result;
    logic pending;
    logic [2:0] group;
    logic memory_form;
    logic [13:0] descriptor;
    logic [AW-1:0] next_inst,next_operand;
    logic [10:0] next_opcode;
    integer exponent;
    logic unused_math;
    assign unused_math=^{converted[86],loaded[85:80],descriptor[13:11]};

    // {store, format, byte count}; invalid/reserved forms have length zero.
    /* verilator lint_off UNUSEDSIGNAL */
    function automatic logic [13:0] memory_descriptor(input logic [7:0] op,md,input logic wide);
        logic [6:0] env_len,save_len;
        logic [2:0] g;
        begin
            g=md[5:3]; memory_descriptor=0;
            // 80387 32-bit environment/save images: 28 and 108 bytes.
            env_len=(VARIANT==2&&wide) ? 7'd28:7'd14;
            save_len=(VARIANT==2&&wide) ? 7'd108:7'd94;
            if(md[7:6]!=3) case(op)
                8'hd8:memory_descriptor={3'd0,1'b0,3'd0,7'd4};
                8'hdc:memory_descriptor={3'd0,1'b0,3'd1,7'd8};
                8'hda:memory_descriptor={3'd0,1'b0,3'd4,7'd4};
                8'hde:memory_descriptor={3'd0,1'b0,3'd3,7'd2};
                8'hd9:case(g)
                    0:memory_descriptor={3'd0,1'b0,3'd0,7'd4};
                    2,3:memory_descriptor={3'd0,1'b1,3'd0,7'd4};
                    4:memory_descriptor={3'd0,1'b0,3'd0,env_len};
                    5:memory_descriptor={3'd0,1'b0,3'd0,7'd2};
                    6:memory_descriptor={3'd0,1'b1,3'd0,env_len};
                    7:memory_descriptor={3'd0,1'b1,3'd0,7'd2};
                    default:begin end
                endcase
                8'hdd:case(g)
                    0:memory_descriptor={3'd0,1'b0,3'd1,7'd8};
                    2,3:memory_descriptor={3'd0,1'b1,3'd1,7'd8};
                    4:memory_descriptor={3'd0,1'b0,3'd0,save_len};
                    6:memory_descriptor={3'd0,1'b1,3'd0,save_len};
                    7:memory_descriptor={3'd0,1'b1,3'd0,7'd2};
                    default:begin end
                endcase
                8'hdb:case(g)
                    0:memory_descriptor={3'd0,1'b0,3'd4,7'd4};
                    2,3:memory_descriptor={3'd0,1'b1,3'd4,7'd4};
                    5:memory_descriptor={3'd0,1'b0,3'd2,7'd10};
                    7:memory_descriptor={3'd0,1'b1,3'd2,7'd10};
                    default:begin end
                endcase
                8'hdf:case(g)
                    0:memory_descriptor={3'd0,1'b0,3'd3,7'd2};
                    2,3:memory_descriptor={3'd0,1'b1,3'd3,7'd2};
                    4:memory_descriptor={3'd0,1'b0,3'd6,7'd10};
                    5:memory_descriptor={3'd0,1'b0,3'd5,7'd8};
                    6:memory_descriptor={3'd0,1'b1,3'd6,7'd10};
                    7:memory_descriptor={3'd0,1'b1,3'd5,7'd8};
                    default:begin end
                endcase
                default:begin end
            endcase
        end
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */
    assign descriptor=memory_descriptor(opcode_i,modrm_i,opsize32_i);
    // FLDL2T/FLDL2E/FLDPI/FLDLG2/FLDLN2 (D9 E9..ED). The 8087 and 80287
    // load the significand truncated (chop) whatever the rounding control;
    // the 80387 rounds per RC (387PRM App. C.4, "FLD constant"). The chop
    // value and whether round-to-nearest rounds it up are tabulated.
    function automatic logic [79:0] fp_constant(input logic [2:0] sel,input logic [1:0] rc);
        logic [79:0] chop;
        logic nearest_up;
        begin
            case(sel)
                3'd1:begin chop=80'h4000d49a784bcd1b8afe; nearest_up=0; end // log2(10)
                3'd2:begin chop=80'h3fffb8aa3b295c17f0bb; nearest_up=1; end // log2(e)
                3'd3:begin chop=80'h4000c90fdaa22168c234; nearest_up=1; end // pi
                3'd4:begin chop=80'h3ffd9a209a84fbcff798; nearest_up=1; end // log10(2)
                default:begin chop=80'h3ffeb17217f7d1cf79ab; nearest_up=1; end // ln(2)
            endcase
            fp_constant=chop;
            if(VARIANT==2&&(rc==2||(rc==0&&nearest_up))) fp_constant[63:0]=chop[63:0]+64'd1;
        end
    endfunction
    assign pending=|(sw_q[5:0]&~cw_q[5:0]);
    // 8087: INT through the interrupt-enable mask (WAIT overrides it).
    // 80287/80387: ERROR# reflects any pending unmasked exception; IEM has
    // no effect (286PRM App. B item 1; 387PRM App. D item 1).
    assign int_o=VARIANT==0 ? pending&&(!cw_q[7]||cpu_wait_i) : pending;
    // Status word image; bit 6 is the 80387 stack-fault flag, reserved zero
    // on the 8087 and 80287.
    assign status_image={1'b0,sw_q[14],top_q,sw_q[10:8],pending,(VARIANT==2)&&sw_q[6],sw_q[5:0]};
    assign ax_o=status_image;
    assign busy_o=state!=IDLE||pending;
    assign cmd_ready_o=state==IDLE;
    assign control_o=cw_q;
    assign status_o={busy_o,status_image[14:0]};
    assign tags_o=tags_q;
    assign registers_o=stack_q;
    assign mem_valid_o=rst_n&&(state==READ||state==WRITE);
    assign mem_write_o=mem_valid_o&&state==WRITE;
    assign mem_address_o=address+AW'(count);
    assign mem_wdata_o=buffer_q[count*8+:8];
    assign group=modrm[5:3];
    assign image_format = VARIANT==0 ? 2'd0 :
                          VARIANT==1 ? (pm_q ? 2'd1 : 2'd0) : {op32_q, prot_q};
    assign ip_wide=32'(inst_pointer);
    assign op_wide=32'(operand_pointer);
    assign memory_form=modrm[7:6]!=3;
    assign index_i=top_q+modrm[2:0];
    assign index_one=top_q+3'd1;
    assign index_push=top_q-3'd1;
    assign st0=stack_q[top_q*80+:80];
    assign sti=stack_q[index_i*80+:80];
    assign st1=stack_q[index_one*80+:80];
    assign loaded=state==EXEC&&memory_form ? fp_load(buffer_q[79:0],format_q):86'd0;
    // 80387: a real32/real64 SNaN operand is quieted by the load (which
    // reports IE); the ALU still sees it as signalling so that NaN selection
    // treats two SNaNs alike.
    assign source=!memory_form ? sti :
        (VARIANT==2&&format_q<=1&&loaded[80]&&fp_nan(loaded[79:0])) ? {loaded[79:63],1'b0,loaded[61:0]} : loaded[79:0];
    intel_8087_alu #(.VARIANT(VARIANT)) alu(.enable_i(state==EXEC),.a_i(alu_a),.b_i(alu_b),.op_i(alu_op),.control_i(cw_q),
        .result_o(alu_result),.exceptions_o(alu_flags),.rounded_up_o(alu_round),.condition_o(alu_cc));
    intel_8087_trans #(.VARIANT(VARIANT)) trans(.clk(clk),.rst_n(rst_n),.start_i(state==TRANS_START),
        .op_i(trans_op),.x_i(st0),.y_i(st1),.done_o(trans_done),.result_o(trans_result));
    always_comb begin
        alu_a=st0; alu_b=source; alu_op=0;
        if(!memory_form&&(opcode==8'hdc||opcode==8'hde)) begin alu_a=sti; alu_b=st0; end
        case(group)
            0:alu_op=0;
            1:alu_op=1;
            4,5:begin
                alu_op=2;
                // Register DC/DE reverse encodings are swapped from D8.
                if(group==5 ? (memory_form||opcode==8'hd8):(!memory_form&&opcode!=8'hd8)) begin
                    alu_a=st0; alu_b=source;
                    if(memory_form||opcode==8'hd8) begin alu_a=source; alu_b=st0; end
                end
            end
            6,7:begin
                alu_op=3;
                if(group==7 ? (memory_form||opcode==8'hd8):(!memory_form&&opcode!=8'hd8)) begin
                    alu_a=st0; alu_b=source;
                    if(memory_form||opcode==8'hd8) begin alu_a=source; alu_b=st0; end
                end
            end
            default:begin end
        endcase
        if(opcode==8'hd9&&!memory_form) begin
            alu_a=st0; alu_b=st1;
            case(modrm)
                8'hfa:begin alu_op=4; alu_b=0; end
                8'hfc:begin alu_op=5; alu_b=0; end
                8'hfd:alu_op=6;
                8'hf8:alu_op=7;
                8'hf5:alu_op=8;
                default:begin end
            endcase
        end
        case(modrm)
            8'hf0:trans_op=0;
            8'hf1:trans_op=1;
            8'hf2:trans_op=2;
            8'hf3:trans_op=3;
            default:trans_op=4;
        endcase
    end

    task automatic put_value(input logic [2:0] index_value,input logic [79:0] data_value);
        begin next_stack[index_value*80+:80]=data_value; next_tags[index_value*2+:2]=fp_tag(data_value); end
    endtask
    // Stack underflow (empty operand) and overflow (push onto a full
    // register) raise IE; the 80387 also sets SF and reports the direction
    // in C1 (387PRM App. C.3).
    task automatic stack_underflow;
        begin flags[0]=1; stack_fault=1; stack_c1=0; end
    endtask
    task automatic stack_overflow;
        begin flags[0]=1; stack_fault=1; stack_c1=1; end
    endtask
    task automatic pop_value;
        begin next_tags[next_top*2+:2]=3; next_top=next_top+3'd1; end
    endtask
    task automatic push_value(input logic [79:0] data_value);
        begin
            next_top=next_top-3'd1;
            if(next_tags[next_top*2+:2]!=3) begin stack_overflow(); put_value(next_top,FP_INDEF); end
            else put_value(next_top,data_value);
        end
    endtask
    // Environment image header (FSTENV/FSAVE) in the selected format.
    task automatic store_image;
        begin
            case(image_format)
                2'd0:begin
                    write_buffer[15:0]=cw_q; write_buffer[31:16]=status_image; write_buffer[47:32]=tags_q;
                    write_buffer[63:48]=inst_pointer[15:0];
                    write_buffer[79:64]={inst_pointer[19:16],1'b0,last_opcode};
                    write_buffer[95:80]=operand_pointer[15:0]; write_buffer[111:96]={operand_pointer[19:16],12'd0};
                end
                2'd1:begin
                    write_buffer[15:0]=cw_q; write_buffer[31:16]=status_image; write_buffer[47:32]=tags_q;
                    write_buffer[63:48]=inst_pointer[15:0]; write_buffer[79:64]=inst_sel;
                    write_buffer[95:80]=operand_pointer[15:0]; write_buffer[111:96]=operand_sel;
                end
                2'd2:begin
                    // ASSUMPTION: reserved halves are stored as FFFFh (see
                    // the 80387 assumption ledger, A6).
                    write_buffer[31:0]={16'hffff,cw_q}; write_buffer[63:32]={16'hffff,status_image};
                    write_buffer[95:64]={16'hffff,tags_q};
                    write_buffer[127:96]={16'hffff,inst_pointer[15:0]};
                    write_buffer[159:128]={4'd0,ip_wide[31:16],1'b0,last_opcode};
                    write_buffer[191:160]={16'hffff,operand_pointer[15:0]};
                    write_buffer[223:192]={4'd0,op_wide[31:16],12'd0};
                end
                default:begin
                    write_buffer[31:0]={16'hffff,cw_q}; write_buffer[63:32]={16'hffff,status_image};
                    write_buffer[95:64]={16'hffff,tags_q};
                    write_buffer[127:96]=ip_wide;
                    write_buffer[159:128]={5'd0,last_opcode,inst_sel};
                    write_buffer[191:160]=op_wide;
                    write_buffer[223:192]={16'hffff,operand_sel};
                end
            endcase
        end
    endtask
    // Environment image header (FLDENV/FRSTOR) in the selected format.
    task automatic load_image;
        logic [15:0] loaded_sw;
        begin
            if(image_format[1]) begin
                next_cw=buffer_q[15:0]; loaded_sw=buffer_q[47:32]; next_tags=buffer_q[79:64];
            end else begin
                next_cw=buffer_q[15:0]; loaded_sw=buffer_q[31:16]; next_tags=buffer_q[47:32];
            end
            next_sw=loaded_sw; next_top=loaded_sw[13:11];
            case(image_format)
                2'd0:begin
                    next_inst=AW'({buffer_q[79:76],buffer_q[63:48]}); next_opcode=buffer_q[74:64];
                    next_operand=AW'({buffer_q[111:108],buffer_q[95:80]});
                end
                2'd1:begin
                    next_inst=AW'(buffer_q[63:48]); next_inst_sel=buffer_q[79:64];
                    next_operand=AW'(buffer_q[95:80]); next_operand_sel=buffer_q[111:96];
                end
                2'd2:begin
                    next_inst=AW'({buffer_q[155:140],buffer_q[111:96]}); next_opcode=buffer_q[138:128];
                    next_operand=AW'({buffer_q[219:204],buffer_q[175:160]});
                end
                default:begin
                    next_inst=AW'(buffer_q[127:96]); next_inst_sel=buffer_q[143:128];
                    next_opcode=buffer_q[154:144];
                    next_operand=AW'(buffer_q[191:160]); next_operand_sel=buffer_q[207:192];
                end
            endcase
        end
    endtask
    // Store-conversion exceptions. 80387 masked underflow requires loss of
    // accuracy as well as tininess (387PRM App. C.2).
    function automatic logic [5:0] store_flags(input logic [5:0] f);
        store_flags=f;
        if(VARIANT==2&&cw_q[4]&&!f[5]) store_flags[4]=0;
    endfunction
    task automatic need_top;
        if(tags_q[top_q*2+:2]==3) stack_underflow();
    endtask
    // FCOM-family compare. 8087/80287: any NaN, unnormal or (projective)
    // infinity is invalid. 80387: unsupported operands and SNaNs are
    // invalid; a QNaN is invalid for FCOM but not for FUCOM (387PRM C.2).
    task automatic compare_value(input logic [79:0] other,input logic empty_other,input logic unordered_ok);
        integer ea_cmp,eb_cmp;
        logic [63:0] ma_cmp,mb_cmp;
        logic unordered;
        begin
            ea_cmp=int'({1'b0,st0[78:64]});eb_cmp=int'({1'b0,other[78:64]});
            ma_cmp=st0[63:0];mb_cmp=other[63:0];
            if(ea_cmp==0) ea_cmp=1;
            if(eb_cmp==0) eb_cmp=1;
            for(integer k=0;k<63;k=k+1) begin
                if(ma_cmp!=0&&!ma_cmp[63]) begin ma_cmp=ma_cmp<<1;ea_cmp=ea_cmp-1; end
                if(mb_cmp!=0&&!mb_cmp[63]) begin mb_cmp=mb_cmp<<1;eb_cmp=eb_cmp-1; end
            end
            // A zero has the smallest magnitude; without this a zero would
            // order above a normalized denormal, whose exponent goes below 1
            // (failure_notes/2026-11-27-x87-zero-denormal-compare.md).
            if(ma_cmp==0) ea_cmp=-100000;
            if(mb_cmp==0) eb_cmp=-100000;
            need_top();
            if(empty_other) stack_underflow();
            next_sw[14]=0; next_sw[10:8]=0;
            unordered=0;
            if(VARIANT==2) begin
                if(!flags[0]) begin
                    if(fp_bad(st0)||fp_bad(other)) flags[0]=1;
                    else if(fp_nan(st0)||fp_nan(other)) begin
                        unordered=1;
                        if(!unordered_ok||fp_snan(st0)||fp_snan(other)) flags[0]=1;
                    end
                end
                if(!flags[0]&&!unordered&&((st0[78:64]==0&&st0[63:0]!=0)||(other[78:64]==0&&other[63:0]!=0))) flags[1]=1;
            end else begin
                if((st0[63:0]==0&&!fp_zero(st0))||(other[63:0]==0&&!fp_zero(other))||fp_nan(st0)||fp_nan(other)||
                    (!cw_q[12]&&(fp_inf(st0)||fp_inf(other)))) flags[0]=1;
                if((!st0[63]&&!fp_zero(st0))||(!other[63]&&!fp_zero(other))) flags[1]=1;
            end
            // 80387: an unordered or invalid compare does not report D.
            if(VARIANT==2&&(flags[0]||unordered)) flags[1]=0;
            if(flags[0]||unordered) begin next_sw[14]=1; next_sw[10]=1; next_sw[8]=1; end
            else if((fp_zero(st0)&&fp_zero(other))||
                (st0[79]==other[79]&&ea_cmp==eb_cmp&&ma_cmp==mb_cmp)) next_sw[14]=1;
            else if((st0[79]!=other[79]&&st0[79]) ||
                (st0[79]==other[79]&&(st0[79] ?
                    (ea_cmp>eb_cmp||(ea_cmp==eb_cmp&&ma_cmp>mb_cmp)):
                    (ea_cmp<eb_cmp||(ea_cmp==eb_cmp&&ma_cmp<mb_cmp))))) next_sw[8]=1;
        end
    endtask

    // Tool version 5.052 counts writes in automatic helper tasks as separate
    // processes. All next_* state has this one procedural driver.
    /* verilator lint_off MULTIDRIVEN */
    always_comb begin
        // ASSUMPTION: condition-code bits undefined by an instruction retain
        // their previous values. No silicon identity is claimed for them.
        next_stack=stack_q; next_tags=tags_q; next_top=top_q; next_cw=cw_q; next_sw=sw_q;
        next_inst=inst_pointer; next_operand=operand_pointer; next_opcode=last_opcode;
        next_inst_sel=inst_sel; next_operand_sel=operand_sel; next_pm=pm_q;
        stack_fault=0; stack_c1=0; ax_request=0;
        write_buffer=0; write_command=0; bad_encoding=0; begin_trans=0;
        flags=0; converted=0; value=0; exponent=0; blocked=0;
        if(state==EXEC||state==TRANS_WAIT||state==WRITE) begin
        if(opcode<8'hd8||opcode>8'hdf) bad_encoding=1;
        else if((opcode==8'hd8||opcode==8'hdc||opcode==8'hda||opcode==8'hde)&&
            (memory_form||opcode==8'hd8||opcode==8'hdc||opcode==8'hde)) begin
            if(!memory_form&&(group==2||group==3)&&!(opcode==8'hd8||(opcode==8'hde&&modrm==8'hd9))) bad_encoding=1;
            else if(group==2||group==3) begin
                if(memory_form) flags=loaded[85:80];
                compare_value(source,!memory_form&&tags_q[index_i*2+:2]==3,1'b0);
                if(group==3) begin pop_value(); if(opcode==8'hde) pop_value(); end
            end else begin
                need_top();
                if(memory_form) flags=flags|loaded[85:80];
                else if(tags_q[index_i*2+:2]==3) stack_underflow();
                // 80387: a memory SNaN's IE comes from the load, but the
                // result is the quieted NaN the ALU propagates; only an
                // empty-stack fault substitutes the indefinite.
                value=(VARIANT==2 ? stack_fault : flags[0])?FP_INDEF:alu_result;flags=flags|alu_flags;
                // 80387: a NaN or unsupported operand suppresses the
                // denormal flag of a converted memory operand (host oracle).
                if(VARIANT==2&&!stack_fault&&(fp_nan(st0)||fp_nan(source)||fp_bad(st0)||fp_bad(source))) flags[1]=0;
                // ...and a zero divide or invalid result suppresses it too.
                if(VARIANT==2&&!stack_fault&&(alu_flags[2]||alu_flags[0])) flags[1]=0;
                put_value(!memory_form&&opcode!=8'hd8 ? index_i:top_q,value);
                next_sw[9]=alu_round;
                if(opcode==8'hde&&!memory_form) pop_value();
            end
        end else if(memory_form) begin
            case(opcode)
                8'hd9,8'hdd:case(group)
                    0:begin flags=loaded[85:80]; push_value(loaded[79:0]); end
                    2,3:begin
                        need_top(); converted=fp_store(flags[0]?FP_INDEF:st0,format_q,cw_q[11:10]);
                        flags=flags|store_flags(converted[85:80]); write_buffer[79:0]=converted[79:0];
                        write_command=1; next_sw[9]=converted[86]; if(group==3) pop_value();
                    end
                    4:begin
                        load_image();
                        if(opcode==8'hdd) for(integer k=0;k<8;k=k+1)
                            next_stack[((int'(next_top)+k)%8)*80+:80]=buffer_q[(image_format[1]?224:112)+k*80+:80];
                        // 80387: only the empty/non-empty meaning of a
                        // loaded tag is used; non-empty tags are recomputed
                        // from the register contents (387PRM App. C.3).
                        if(VARIANT==2) for(integer k=0;k<8;k=k+1)
                            if(next_tags[k*2+:2]!=3) next_tags[k*2+:2]=fp_tag(next_stack[k*80+:80]);
                    end
                    5:if(opcode==8'hd9) next_cw=buffer_q[15:0]; else bad_encoding=1;
                    6:begin
                        write_command=1;
                        store_image();
                        if(opcode==8'hdd) begin
                            for(integer k=0;k<8;k=k+1)
                                write_buffer[(image_format[1]?224:112)+k*80+:80]=stack_q[((int'(top_q)+k)%8)*80+:80];
                            next_cw=INIT_CW;next_sw=0;next_top=0;next_tags=16'hffff;
                        end else next_cw[5:0]=6'h3f;
                    end
                    7:begin write_command=1; write_buffer[15:0]=opcode==8'hd9 ? cw_q:status_image; end
                    default:bad_encoding=1;
                endcase
                8'hdb,8'hdf:case(group)
                    0:begin flags=loaded[85:80]; push_value(loaded[79:0]); end
                    4,5:if(opcode==8'hdf||group==5) begin flags=loaded[85:80]; push_value(loaded[79:0]); end else bad_encoding=1;
                    2,3,6,7:begin
                        if(opcode==8'hdb&&group==6) bad_encoding=1;
                        else begin
                            need_top(); converted=fp_store(flags[0]?FP_INDEF:st0,format_q,cw_q[11:10]);
                            flags=flags|store_flags(converted[85:80]); write_buffer[79:0]=converted[79:0];
                            write_command=1; next_sw[9]=converted[86]; if(group!=2) pop_value();
                        end
                    end
                    default:bad_encoding=1;
                endcase
                default:bad_encoding=1;
            endcase
        end else case(opcode)
            8'hd9:begin
                if(modrm>=8'hc0&&modrm<=8'hc7) begin
                    if(tags_q[index_i*2+:2]==3) stack_underflow();
                    push_value(flags[0]?FP_INDEF:sti);
                end else if(modrm>=8'hc8&&modrm<=8'hcf) begin
                    if(tags_q[top_q*2+:2]==3||tags_q[index_i*2+:2]==3) stack_underflow();
                    put_value(top_q,tags_q[index_i*2+:2]==3?FP_INDEF:sti);
                    put_value(index_i,tags_q[top_q*2+:2]==3?FP_INDEF:st0);
                end else case(modrm)
                    8'hd0:begin end
                    8'he0,8'he1:begin need_top(); value=st0; value[79]=modrm==8'he0 ? !st0[79]:1'b0; put_value(top_q,flags[0]?FP_INDEF:value); end
                    8'he4:compare_value(80'd0,1'b0,1'b0);
                    8'he5:begin
                        next_sw[9]=st0[79];
                        if(tags_q[top_q*2+:2]==3) begin next_sw[14]=1;next_sw[10]=0;next_sw[8]=1; end
                        else if(VARIANT==2&&fp_bad(st0)) begin next_sw[14]=0;next_sw[10]=0;next_sw[8]=0; end
                        else if(fp_zero(st0)) begin next_sw[14]=1;next_sw[10]=0;next_sw[8]=0; end
                        else if(st0[78:64]==0) begin next_sw[14]=1;next_sw[10]=1;next_sw[8]=0; end
                        else if(fp_inf(st0)) begin next_sw[14]=0;next_sw[10]=1;next_sw[8]=1; end
                        else if(fp_nan(st0)) begin next_sw[14]=0;next_sw[10]=0;next_sw[8]=1; end
                        else begin next_sw[14]=0;next_sw[10]=st0[63];next_sw[8]=0; end
                    end
                    8'he8:push_value(ONE);
                    8'he9,8'hea,8'heb,8'hec,8'hed:push_value(fp_constant(modrm[2:0],cw_q[11:10]));
                    8'hee:push_value(80'd0);
                    8'hf0,8'hf1,8'hf2,8'hf3,8'hf9:begin
                        need_top();
                        if(modrm==8'hf1||modrm==8'hf3||modrm==8'hf9) if(tags_q[index_one*2+:2]==3) stack_underflow();
                        if(modrm==8'hf2&&tags_q[index_push*2+:2]!=3) stack_overflow();
                        if(flags[0]) begin
                            put_value(top_q,FP_INDEF);
                            if(modrm==8'hf2) push_value(FP_INDEF);
                            else if(modrm!=8'hf0) begin pop_value(); put_value(next_top,FP_INDEF); end
                        end else begin
                            begin_trans=1;
                            if(state==TRANS_WAIT&&trans_done) begin
                                if(modrm==8'hf0) put_value(top_q,trans_result);
                                else if(modrm==8'hf2) begin put_value(top_q,trans_result); push_value(ONE); end
                                else begin pop_value(); put_value(next_top,trans_result); end
                                flags[5]=1;
                            end
                        end
                    end
                    8'hf4:begin
                        need_top();
                        if(VARIANT==2&&!flags[0]) begin
                            // 80387 FXTRACT (387PRM App. C.4): zero gives
                            // ZE and an exponent of -infinity; infinity gives
                            // +infinity without an exception; denormals are
                            // normalized and report D.
                            if(fp_bad(st0)) begin flags[0]=1; put_value(top_q,FP_INDEF); push_value(FP_INDEF); end
                            else if(fp_nan(st0)) begin
                                if(fp_snan(st0)) flags[0]=1;
                                value=st0; value[62]=1; put_value(top_q,value); push_value(value);
                            end else if(fp_zero(st0)) begin
                                flags[2]=1; put_value(top_q,80'hffff8000000000000000); push_value(st0);
                            end else if(fp_inf(st0)) begin
                                put_value(top_q,80'h7fff8000000000000000); push_value(st0);
                            end else begin
                                value=st0; exponent=int'({1'b0,st0[78:64]})-16383;
                                if(st0[78:64]==0) begin
                                    flags[1]=1; exponent=-16382;
                                    for(integer k=0;k<63;k=k+1)
                                        if(!value[63]) begin value[63:0]=value[63:0]<<1; exponent=exponent-1; end
                                end
                                put_value(top_q,fp_integer(64'(exponent)));
                                push_value({st0[79],15'h3fff,value[63:0]});
                            end
                        end else if(fp_zero(st0)) begin put_value(top_q,st0);push_value(st0); end
                        else begin
                            exponent=int'({1'b0,st0[78:64]})-16383;
                            put_value(top_q,fp_integer(64'(exponent)));
                            push_value({st0[79],15'h3fff,st0[63:0]});
                        end
                    end
                    8'hf6:begin next_top=top_q-3'd1;next_sw[9]=0; end
                    8'hf7:begin next_top=top_q+3'd1;next_sw[9]=0; end
                    8'hf8,8'hfa,8'hfc,8'hfd,8'hf5:if(modrm==8'hf5&&VARIANT!=2) bad_encoding=1; else begin
                        need_top();
                        if((modrm==8'hf8||modrm==8'hfd||(VARIANT==2&&modrm==8'hf5))&&tags_q[index_one*2+:2]==3) stack_underflow();
                        // An empty-stack fault substitutes the indefinite;
                        // otherwise the ALU result (an 80387 quiet NaN or
                        // indefinite) is retained.
                        if(VARIANT==2) begin value=flags[0]?FP_INDEF:alu_result; flags=flags|alu_flags; end
                        else begin flags=flags|alu_flags; value=flags[0]?FP_INDEF:alu_result; end
                        put_value(top_q,value);
                        if(modrm==8'hf8||modrm==8'hf5) begin next_sw[14]=alu_cc[3];next_sw[10:8]=alu_cc[2:0]; end
                        else next_sw[9]=alu_round;
                    end
                    default:bad_encoding=1;
                endcase
            end
            8'hdb:case(modrm)
                // FENI/FDISI: the 80287 and 80387 ignore them (286PRM App. B
                // item 2; 387PRM App. D item 2).
                8'he0:if(VARIANT==0) next_cw[7]=0;
                8'he1:if(VARIANT==0) next_cw[7]=1;
                8'he2:next_sw[7:0]=0;
                8'he3:begin next_cw=INIT_CW; next_sw=0; next_top=0; next_tags=16'hffff; end
                // FSETPM: 80287 enters protected mode; FNOP on the 80387.
                8'he4:if(VARIANT==1) next_pm=1; else if(VARIANT==0) bad_encoding=1;
                default:bad_encoding=1;
            endcase
            // FUCOMPP (80387).
            8'hda:if(VARIANT==2&&modrm==8'he9) begin
                compare_value(st1,tags_q[index_one*2+:2]==3,1'b1); pop_value(); pop_value();
            end else bad_encoding=1;
            // FSTSW AX / FNSTSW AX (80287, 80387).
            8'hdf:if(VARIANT>=1&&modrm==8'he0) ax_request=1; else bad_encoding=1;
            8'hdd:case(group)
                0:next_tags[index_i*2+:2]=3;
                2,3:begin need_top(); put_value(index_i,flags[0]?FP_INDEF:st0); if(group==3) pop_value(); end
                // FUCOM / FUCOMP (80387).
                4,5:if(VARIANT==2) begin
                    compare_value(sti,tags_q[index_i*2+:2]==3,1'b1); if(group==5) pop_value();
                end else bad_encoding=1;
                default:bad_encoding=1;
            endcase
            default:bad_encoding=1;
        endcase
        // Processor-control instructions do not overwrite exception pointers.
        if(!bad_encoding && !(opcode==8'hdb&&!memory_form) && !ax_request &&
            !(memory_form&&(opcode==8'hd9||opcode==8'hdd)&&group>=4)) begin
            next_inst=command_inst; next_opcode={opcode[2:0],modrm}; next_inst_sel=cs_q;
            if(memory_form) begin next_operand=address; next_operand_sel=ds_q; end
        end
        // Before exceptions suppress all effects. Precision traps retire the
        // rounded result. Range traps retire wrapped register results but
        // preserve memory and stack for FST/FSTP (Intel S-19--S-20).
        end
        blocked=|(flags[2:0]&~cw_q[2:0]) ||
            (write_command&&|(flags[4:3]&~cw_q[4:3]));
        if(blocked||bad_encoding) begin
            next_stack=stack_q;next_tags=tags_q;next_top=top_q;write_command=0;begin_trans=0;
        end
        next_sw[5:0]=next_sw[5:0]|flags;
        if(VARIANT==2) begin
            if(stack_fault) begin next_sw[6]=1; next_sw[9]=stack_c1; end
        end else next_sw[6]=0;
    end
    /* verilator lint_on MULTIDRIVEN */

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;cw_q<=INIT_CW;sw_q<=0;tags_q<=16'hffff;top_q<=0;
            pm_q<=0;prot_q<=0;op32_q<=0;cs_q<=0;ds_q<=0;ax_write_o<=0;
            opcode<=0;modrm<=0;address<=0;command_inst<=0;count<=0;length_q<=0;format_q<=0;
            buffer_q<=0;done_o<=0;unsupported_o<=0;
            // ASSUMPTION: hardware reset retains register and pointer data,
            // as required for software initialization by Intel table S-7.
        end else begin
            done_o<=0;unsupported_o<=0;ax_write_o<=0;
            case(state)
                IDLE:if(cmd_valid_i) begin
                    opcode<=opcode_i;modrm<=modrm_i;address<=address_i;
                    command_inst<=instruction_i;
                    cs_q<=cs_sel_i;ds_q<=ds_sel_i;prot_q<=protected_i;op32_q<=opsize32_i;
                    count<=0; length_q<=descriptor[6:0]; format_q<=descriptor[9:7];buffer_q<=0;
                    if(modrm_i[7:6]!=3&&descriptor[6:0]!=0&&!descriptor[10]) state<=READ;
                    else state<=EXEC;
                end
                READ:if(mem_ready_i) begin
                    buffer_q[count*8+:8]<=mem_rdata_i;
                    if(count+1'b1==length_q) begin state<=EXEC;count<=0; end
                    else count<=count+1'b1;
                end
                EXEC:begin
                    if(begin_trans) state<=TRANS_START;
                    else if(write_command) begin buffer_q<=write_buffer;count<=0;state<=WRITE; end
                    else begin
                        stack_q<=next_stack;tags_q<=next_tags;top_q<=next_top;cw_q<=next_cw;sw_q<=next_sw;
                        inst_pointer<=next_inst;operand_pointer<=next_operand;last_opcode<=next_opcode;
                        inst_sel<=next_inst_sel;operand_sel<=next_operand_sel;pm_q<=next_pm;
                        ax_write_o<=ax_request&&!bad_encoding;
                        state<=IDLE;done_o<=1;unsupported_o<=bad_encoding;
                    end
                end
                TRANS_START:state<=TRANS_WAIT;
                TRANS_WAIT:if(trans_done) begin
                    stack_q<=next_stack;tags_q<=next_tags;top_q<=next_top;sw_q<=next_sw;
                    inst_pointer<=next_inst;operand_pointer<=next_operand;last_opcode<=next_opcode;
                    inst_sel<=next_inst_sel;operand_sel<=next_operand_sel;
                    state<=IDLE;done_o<=1;
                end
                WRITE:if(mem_ready_i) begin
                    if(count+1'b1==length_q) begin
                        // Store/pop and FSAVE initialization retire only
                        // after the final byte has reached memory.
                        stack_q<=next_stack;tags_q<=next_tags;top_q<=next_top;cw_q<=next_cw;sw_q<=next_sw;
                        inst_pointer<=next_inst;operand_pointer<=next_operand;last_opcode<=next_opcode;
                        inst_sel<=next_inst_sel;operand_sel<=next_operand_sel;
                        state<=IDLE;done_o<=1;
                    end
                    else count<=count+1'b1;
                end
                default:state<=IDLE;
            endcase
        end
    end
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if(!past_valid) assume(!rst_n);
        if(past_valid&&$past(rst_n)&&rst_n) begin
            if($past(mem_valid_o&&!mem_ready_i)) begin
                assert(mem_valid_o);assert($stable(mem_address_o));assert($stable(mem_write_o));
                if(mem_write_o) assert($stable(mem_wdata_o));
            end
            if(VARIANT!=2) assert(status_o[6]==0);
            assert(cmd_ready_o==(state==IDLE));
            assert(!mem_write_o||mem_valid_o);
            if($past(state==EXEC&&opcode==8'hdb&&modrm==8'he3)) begin
                assert(control_o==INIT_CW); assert(tags_o==16'hffff); assert(top_q==0);
            end
            if($past(state==EXEC&&opcode==8'hd9&&(modrm==8'hf6||modrm==8'hf7))) begin
                assert($stable(tags_o));assert($stable(registers_o));
                if($past(modrm)==8'hf6) assert(top_q==3'($past(top_q)-1));
                else assert(top_q==3'($past(top_q)+1));
            end
            if($past(!cmd_valid_i&&state==IDLE)&&state==IDLE) begin
                assert($stable(tags_o));assert($stable(control_o));
            end
`ifdef COVER_STACK
            cover(done_o&&opcode==8'hd9&&modrm==8'he8&&top_q==0&&tags_q==0);
`elsif COVER_BUS
            cover(mem_valid_o&&mem_write_o&&!mem_ready_i);
            cover(done_o&&opcode==8'hd9&&modrm==8'h38);
`endif
        end
    end
`endif
endmodule
