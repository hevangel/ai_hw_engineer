`timescale 1ns/1ps
// Original 8086 execution unit. Native pins/prefetch are in intel_8086_chip.
// ASSUMPTION: A2. EU scheduling differs from original silicon clock counts.
// Local scheduling macros expand into this module's single sequential process.
`define I86_DONE begin state<=BOUNDARY; retire_o<=1; trap_pending<=tf_start; lock_prefix<=0; end
`define I86_SET(N,W,V) begin \
  gpr[(W) ? (N) : ((N)&3'd3)] <= merged_register( \
      gpr[(W) ? (N) : ((N)&3'd3)], ((N)>=3'd4), (W), (V)); end
`define I86_IMM(N,S) begin immediate<=0; immediate_pos<=0; \
  immediate_count<=(N); immediate_continuation<=(S); state<=IMM_FETCH; end
// SID 0..3 selects ES/CS/SS/DS; SID 4 selects absolute memory or an I/O port.
`define I86_MEM(SID,OFF,WR,WORD,VAL,NEXT,IO) begin \
  memory_addr<=physical(segment_base(3'(SID)),16'(OFF)); \
  memory_next_addr<=physical(segment_base(3'(SID)),16'((OFF)+16'd1)); \
  memory_segment<=memory_status(3'(SID)); \
  memory_write<=(WR); memory_wide<=(WORD); memory_data<=(VAL); \
  memory_io<=(IO); memory_pair_active<=(WORD) && ((16'(OFF)&16'd1)!=0); \
  memory_continuation<=(NEXT); state<=MEM_REQUEST; end
`define I86_PUSH(V,S) begin \
  `I86_MEM(2,gpr[4]-16'd2,1,1,V,S,0) gpr[4]<=gpr[4]-16'd2; end
`define I86_POP(S) begin \
  `I86_MEM(2,gpr[4],0,1,0,POP_ADVANCE,0) pop_continuation<=(S); end
`define I86_WRITE(V) begin write_value<=(V); state<=WRITEBACK; end
`define I86_INTERRUPT(V,RET,INSN) begin vector_number<=(V); \
  interrupt_return_ip<=(RET); interrupt_instruction<=(INSN); state<=INT_START; end
`define I86_REDIRECT begin redirect_o<=1; end

module intel_8086 (
    input logic clk, rst_n,
    input logic bus_ready_i,
    input logic [15:0] bus_rdata_i,
    input logic intr_i, nmi_i, hold_i, test_n_i,
    output logic bus_req_o, bus_write_o, bus_fetch_o, bus_first_o, bus_io_o, bus_intack_o,
    output logic [19:0] bus_addr_o,
    output logic [1:0] bus_be_o, bus_segment_o,
    output logic [15:0] bus_wdata_o,
    output logic halted_o, fault_o, retire_o, lock_o, hlda_o, redirect_o, prefetch_suspend_o, arbitration_inhibit_o,
    output logic esc_valid_o,
    output logic [5:0] esc_opcode_o,
    output logic [19:0] esc_address_o,
    output logic [7:0] esc_modrm_o,
    output logic [19:0] esc_instruction_o,
    output logic waiting_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [15:0] ip_o, flags_o
);
  typedef enum logic [5:0] {
    BOUNDARY,FETCH,FETCH_DONE,DECODE,BUS,IMM_FETCH,IMM_BYTE,MODRM_FETCH,
    MODRM_DONE,DISP_DONE,PREPARE,OPERAND_DONE,EXECUTE,WRITEBACK,
    MEM_REQUEST,MEM_FIRST_DONE,MEM_SECOND_REQUEST,MEM_SECOND_DONE,
    POP_ADVANCE,POP_DONE,MOFFS,IO_DONE,FAR_POINTER,FAR_POINTER_DONE,
    CALL_PUSH_IP,TRANSFER,RET_IP,RET_CS,RET_FLAGS,
    INT_START,INT_PUSH_CS,INT_PUSH_IP,INT_READ_IP,INT_READ_CS,INT_SAVE_FLAGS,INT_DONE,
    IRQ_FIRST,IRQ_SECOND,IRQ_VECTOR,SHIFT_STEP,
    STRING_START,STRING_SOURCE,STRING_COMPARE,STRING_UPDATE,WAITING,HALTED,FAULT
  } state_t;
  state_t state, continuation, immediate_continuation, memory_continuation, pop_continuation;
  logic [15:0] gpr[0:7], seg[0:3];
  logic [15:0] ip, flags, instruction_ip;
  logic [7:0] opcode, modrm, read_byte;
  logic [15:0] read_word;
  logic wide, override_valid;
  logic [1:0] override_seg, ea_seg;
  logic [15:0] ea, rm_value, reg_value, write_value;
  logic [31:0] immediate;
  logic [2:0] immediate_count, immediate_pos;
  logic [19:0] transfer_addr;
  logic [1:0] transfer_be, transfer_segment;
  logic transfer_write, transfer_fetch, transfer_first, transfer_io, transfer_intack;
  logic [15:0] transfer_data;
  logic [19:0] memory_addr, memory_next_addr;
  logic memory_write, memory_wide, memory_io;
  logic memory_pair_active;
  logic [1:0] memory_segment;
  logic [15:0] memory_data, memory_result;
  logic [15:0] effective_base;
  logic [1:0] default_seg;
  logic [2:0] alu_kind;
  logic [15:0] alu_lhs, alu_rhs, alu_value, alu_flags;
  logic alu_wide;
  logic [15:0] shift_value, shift_flags, shifted_value, shifted_flags;
  logic [7:0] shift_count;
  logic [15:0] mul_ax, mul_dx;
  logic mul_carry, divide_error;
  logic [15:0] decimal_ax, decimal_flags;
  logic [7:0] adjusted_al;
  logic decimal_error;
  logic [15:0] target_ip, target_cs, string_source;
  logic [7:0] vector_number;
  logic [15:0] interrupt_return_ip;
  logic interrupt_instruction;
  logic [1:0] repeat_kind;
  logic lock_prefix, acknowledge_lock;
  logic nmi_previous, nmi_pending, tf_start, trap_pending;
  logic mask_shadow, all_shadow;
  logic [2:0] wait_count;
  logic string_more;
  integer index;

  function automatic logic [19:0] physical(input logic [15:0] base, offset_value);
    physical={base,4'b0}+{4'b0,offset_value};
  endfunction
  function automatic logic [1:0] segment_status(input logic [1:0] sid);
    case(sid) 0: segment_status=0; 1: segment_status=2;
      2: segment_status=1; 3: segment_status=3; endcase
  endfunction
  function automatic logic [15:0] segment_base(input logic [2:0] sid);
    segment_base=sid[2] ? 16'b0:seg[sid[1:0]];
  endfunction
  function automatic logic [1:0] memory_status(input logic [2:0] sid);
    memory_status=sid[2] ? 2'd2:segment_status(sid[1:0]);
  endfunction
  logic unused_transfer_lsb;
  assign unused_transfer_lsb=transfer_addr[0];
  function automatic logic [15:0] get_register(input logic [2:0] number, input logic word_size);
    if(word_size) get_register=gpr[number];
    else if(number[2]) get_register={8'b0,gpr[{1'b0,number[1:0]}][15:8]};
    else get_register={8'b0,gpr[number][7:0]};
  endfunction
  function automatic logic [15:0] merged_register(input logic [15:0] old_value,
      input logic high_byte, word_size, input logic [15:0] value);
    if(word_size) merged_register=value;
    else if(high_byte) merged_register={value[7:0],old_value[7:0]};
    else merged_register={old_value[15:8],value[7:0]};
  endfunction
  function automatic logic condition(input logic [3:0] cc);
    case(cc)
      0:condition=flags[11]; 1:condition=!flags[11];
      2:condition=flags[0]; 3:condition=!flags[0];
      4:condition=flags[6]; 5:condition=!flags[6];
      6:condition=flags[0]||flags[6]; 7:condition=!flags[0]&&!flags[6];
      8:condition=flags[7]; 9:condition=!flags[7];
      10:condition=flags[2]; 11:condition=!flags[2];
      12:condition=flags[7]!=flags[11]; 13:condition=flags[7]==flags[11];
      14:condition=flags[6]||(flags[7]!=flags[11]);
      15:condition=!flags[6]&&(flags[7]==flags[11]);
    endcase
  endfunction
  assign regs_o={gpr[7],gpr[6],gpr[5],gpr[4],gpr[3],gpr[2],gpr[1],gpr[0]};
  assign segs_o={seg[3],seg[2],seg[1],seg[0]};
  assign ip_o=ip;
  assign flags_o=(flags & 16'h0fd5) | 16'hf002;
  assign bus_req_o=rst_n && !hlda_o && state==BUS;
  assign bus_addr_o={transfer_addr[19:1],1'b0};
  assign bus_be_o=transfer_be;
  assign bus_write_o=transfer_write;
  assign bus_fetch_o=transfer_fetch;
  assign bus_first_o=transfer_first;
  assign bus_io_o=transfer_io;
  assign bus_intack_o=transfer_intack;
  assign bus_segment_o=transfer_segment;
  assign bus_wdata_o=transfer_data;
  assign halted_o=state==HALTED;
  // ASSUMPTION: A5. FAULT is an implementation diagnostic, not native #UD.
  assign fault_o=state==FAULT;
  assign lock_o=lock_prefix || acknowledge_lock;
  // Interrupt microcode executes SUSP before vector/stack activity. Keep
  // CODE fetches out of the two-cycle interrupt-acknowledge sequence.
  assign prefetch_suspend_o=state>=INT_START && state<=IRQ_VECTOR;
  // Datasheet RQ/GT rule 2: an odd-address word's low byte cannot yield
  // ownership before its high byte. This is separate from the LOCK pin.
  assign arbitration_inhibit_o=memory_pair_active;
  assign esc_opcode_o={opcode[2:0],modrm[5:3]};
  assign esc_address_o=physical(seg[ea_seg],ea);
  assign esc_modrm_o=modrm;
  assign esc_instruction_o=physical(seg[1],instruction_ip);
  assign waiting_o=state==WAITING;
  assign string_more=repeat_kind!=0 && gpr[1]!=1 &&
      (!(opcode==8'ha6 || opcode==8'ha7 || opcode==8'hae || opcode==8'haf) ||
       (flags[6] == (repeat_kind==2)));

  always_comb begin
    case(read_byte[2:0])
      0:effective_base=gpr[3]+gpr[6]; 1:effective_base=gpr[3]+gpr[7];
      2:effective_base=gpr[5]+gpr[6]; 3:effective_base=gpr[5]+gpr[7];
      4:effective_base=gpr[6]; 5:effective_base=gpr[7];
      6:effective_base=read_byte[7:6]==0 ? 16'b0:gpr[5]; 7:effective_base=gpr[3];
    endcase
    default_seg=(read_byte[2:0]==2 || read_byte[2:0]==3 ||
        (read_byte[2:0]==6 && read_byte[7:6]!=0)) ? 2'd2:2'd3;
    alu_kind=opcode[5:3]; alu_lhs=rm_value; alu_rhs=reg_value; alu_wide=wide;
    if(opcode<=8'h3d) begin
      if(opcode[2]) begin alu_lhs=get_register(0,wide); alu_rhs=immediate[15:0]; end
      else if(opcode[1]) begin alu_lhs=reg_value; alu_rhs=rm_value; end
    end else if(opcode>=8'h40 && opcode<=8'h4f) begin
      alu_kind=opcode[3] ? 3'd5:3'd0; alu_lhs=gpr[opcode[2:0]]; alu_rhs=1; alu_wide=1;
    end else if(opcode>=8'h80 && opcode<=8'h83) begin
      alu_kind=modrm[5:3];
      alu_rhs=opcode==8'h83 ? {{8{immediate[7]}},immediate[7:0]}:immediate[15:0];
    end else if(opcode==8'ha8 || opcode==8'ha9) begin
      alu_kind=4; alu_lhs=get_register(0,wide); alu_rhs=immediate[15:0];
    end else if(opcode==8'h84 || opcode==8'h85) alu_kind=4;
    else if(opcode==8'hf6 || opcode==8'hf7) begin
      alu_kind=modrm[5:3]==3 ? 3'd5:3'd4;
      alu_lhs=modrm[5:3]==3 ? 16'b0:rm_value;
      alu_rhs=modrm[5:3]==3 ? rm_value:immediate[15:0];
    end else if(opcode==8'hfe || opcode==8'hff) begin
      alu_kind=modrm[3] ? 3'd5:3'd0; alu_lhs=rm_value; alu_rhs=1;
    end
    if(state==STRING_COMPARE) begin
      alu_kind=5;
      alu_lhs=opcode[3] ? get_register(0,wide):string_source;
      alu_rhs=memory_result;
    end
  end
  intel_8086_alu alu(.wide_i(alu_wide),.kind_i(alu_kind),.lhs_i(alu_lhs),.rhs_i(alu_rhs),
      .flags_i(flags_o),.value_o(alu_value),.flags_o(alu_flags));
  intel_8086_shift shifter(.wide_i(wide),.kind_i(modrm[5:3]),.value_i(shift_value),
      .flags_i(shift_flags),.value_o(shifted_value),.flags_o(shifted_flags));
  intel_8086_muldiv muldiv(.wide_i(wide),.kind_i(modrm[4:3]),.operand_i(rm_value),
      .ax_i(gpr[0]),.dx_i(gpr[2]),.ax_o(mul_ax),.dx_o(mul_dx),
      .carry_o(mul_carry),.divide_error_o(divide_error));

  always_comb begin
    decimal_ax=gpr[0]; decimal_flags=flags_o; adjusted_al=gpr[0][7:0]; decimal_error=0;
    case(opcode)
      8'h27: begin
        decimal_flags[4]=gpr[0][3:0]>9 || flags[4];
        if(decimal_flags[4]) adjusted_al=adjusted_al+8'd6;
        // ASSUMPTION: A6. Invalid-BCD inputs follow P80C86 hardware
        // vectors (27:117): incoming AF changes the high-adjust threshold.
        decimal_flags[0]=gpr[0][7:0]>(flags[4] ? 8'h9f:8'h99) || flags[0];
        if(decimal_flags[0]) adjusted_al=adjusted_al+8'h60;
        decimal_ax[7:0]=adjusted_al;
      end
      8'h2f: begin
        decimal_flags[4]=gpr[0][3:0]>9 || flags[4];
        // Original hardware does not retain a borrow from the low adjustment.
        decimal_flags[0]=flags[0];
        if(decimal_flags[4]) adjusted_al=adjusted_al-8'd6;
        if(gpr[0][7:0]>(flags[4] ? 8'h9f:8'h99) || flags[0]) begin
          adjusted_al=adjusted_al-8'h60; decimal_flags[0]=1;
        end
        decimal_ax[7:0]=adjusted_al;
      end
      8'h37,8'h3f: begin
        decimal_flags[4]=gpr[0][3:0]>9 || flags[4]; decimal_flags[0]=decimal_flags[4];
        if(decimal_flags[4]) begin
          adjusted_al=opcode==8'h37 ? adjusted_al+8'd6:adjusted_al-8'd6;
          decimal_ax[15:8]=opcode==8'h37 ? gpr[0][15:8]+8'd1:gpr[0][15:8]-8'd1;
        end
        decimal_ax[7:0]=adjusted_al & 8'h0f;
      end
      8'hd4: begin
        // Physical P80C86 D4:460 sets SZP from zero before the type-0 entry.
        if(immediate[7:0]==0) begin decimal_error=1; adjusted_al=0; end
        else begin
          decimal_ax[15:8]=gpr[0][7:0]/immediate[7:0];
          adjusted_al=gpr[0][7:0]%immediate[7:0]; decimal_ax[7:0]=adjusted_al;
        end
      end
      8'hd5: begin
        adjusted_al=gpr[0][7:0]+gpr[0][15:8]*immediate[7:0]; decimal_ax={8'b0,adjusted_al};
      end
      default: ;
    endcase
    if(opcode==8'h27 || opcode==8'h2f || opcode==8'hd4 || opcode==8'hd5) begin
      decimal_flags[2]=~^adjusted_al;
      decimal_flags[6]=adjusted_al==0;
      decimal_flags[7]=adjusted_al[7];
    end
  end

  always_ff @(posedge clk) begin
    retire_o<=0; redirect_o<=0; esc_valid_o<=0;
    nmi_previous<=nmi_i;
    if(nmi_i && !nmi_previous) nmi_pending<=1;
    if(!rst_n) begin
      state<=BOUNDARY; continuation<=BOUNDARY; immediate_continuation<=BOUNDARY;
      memory_continuation<=BOUNDARY; pop_continuation<=BOUNDARY;
      // ASSUMPTION: A1. Original-silicon GPR reset values are unspecified.
      for(index=0;index<8;index=index+1) gpr[index]<=0;
      seg[0]<=0; seg[1]<=16'hffff; seg[2]<=0; seg[3]<=0;
      ip<=0; flags<=16'hf002; instruction_ip<=0;
      opcode<=0; modrm<=0; read_byte<=0; read_word<=0; wide<=0;
      override_valid<=0; override_seg<=0; ea_seg<=0; ea<=0;
      rm_value<=0; reg_value<=0; write_value<=0;
      immediate<=0; immediate_count<=0; immediate_pos<=0;
      transfer_addr<=0; transfer_be<=1; transfer_segment<=2;
      transfer_write<=0; transfer_fetch<=0; transfer_first<=0; transfer_io<=0;
      transfer_intack<=0; transfer_data<=0;
      memory_addr<=0; memory_next_addr<=0; memory_write<=0; memory_wide<=0;
      memory_io<=0; memory_pair_active<=0; memory_segment<=0; memory_data<=0; memory_result<=0;
      shift_value<=0; shift_flags<=0; shift_count<=0;
      target_ip<=0; target_cs<=0; string_source<=0;
      vector_number<=0; interrupt_return_ip<=0; interrupt_instruction<=0;
      repeat_kind<=0; lock_prefix<=0; acknowledge_lock<=0;
      nmi_previous<=0; nmi_pending<=0; tf_start<=0; trap_pending<=0;
      mask_shadow<=0; all_shadow<=0; wait_count<=0; hlda_o<=0;
    end else begin
      if(hlda_o) begin if(!hold_i) hlda_o<=0; end
      else if(hold_i && !lock_o && !arbitration_inhibit_o && state!=BUS) hlda_o<=1;
      else case(state)
        BOUNDARY: begin
          if(nmi_pending && !all_shadow) begin
            nmi_pending<=0; `I86_INTERRUPT(8'd2,ip,0)
          end else if(intr_i && flags[9] && !mask_shadow && !all_shadow) begin
            acknowledge_lock<=1; interrupt_return_ip<=ip; interrupt_instruction<=0; state<=IRQ_FIRST;
          end else if(trap_pending && !all_shadow) begin
            trap_pending<=0; `I86_INTERRUPT(8'd1,ip,0)
          end else begin
            instruction_ip<=ip; tf_start<=flags[8]; trap_pending<=0;
            mask_shadow<=0; all_shadow<=0; override_valid<=0; repeat_kind<=0;
            lock_prefix<=0; state<=FETCH;
          end
        end
        FETCH: begin
          transfer_addr<=physical(seg[1],ip); transfer_be<=ip[0] ? 2'b10:2'b01;
          transfer_segment<=2; transfer_write<=0; transfer_fetch<=1; transfer_first<=1;
          transfer_io<=0; transfer_intack<=0; transfer_data<=0;
          continuation<=FETCH_DONE; state<=BUS;
        end
        BUS: if(bus_ready_i) begin
          read_word<=bus_rdata_i;
          read_byte<=transfer_be==2 ? bus_rdata_i[15:8]:bus_rdata_i[7:0]; state<=continuation;
        end
        FETCH_DONE: begin opcode<=read_byte; ip<=ip+16'd1; state<=DECODE; end
        DECODE: begin
          wide<=opcode[0];
          if(opcode==8'h26 || opcode==8'h2e || opcode==8'h36 || opcode==8'h3e) begin
            override_valid<=1; override_seg<=opcode[4:3]; state<=FETCH;
          end else if(opcode==8'hf0) begin lock_prefix<=1; state<=FETCH; end
          else if(opcode==8'hf2 || opcode==8'hf3) begin
            repeat_kind<=opcode[0] ? 2'd2:2'd1; state<=FETCH;
          end else if(opcode<=8'h3d && opcode[2:0]<=5) begin
            if(opcode[2]) `I86_IMM(opcode[0] ? 3'd2:3'd1,EXECUTE)
            else state<=MODRM_FETCH;
          end else if(opcode>=8'h40 && opcode<=8'h4f) state<=EXECUTE;
          else if((opcode>=8'h50 && opcode<=8'h57) || opcode==8'h06 || opcode==8'h0e ||
              opcode==8'h16 || opcode==8'h1e || opcode==8'h9c) begin
            if(opcode==8'h9c) `I86_PUSH(flags_o,BOUNDARY)
            else if(opcode[6]) `I86_PUSH(opcode==8'h54 ? gpr[4]-16'd2:gpr[opcode[2:0]],BOUNDARY)
            else `I86_PUSH(seg[opcode[4:3]],BOUNDARY)
          end else if((opcode>=8'h58 && opcode<=8'h5f) || opcode==8'h07 ||
              opcode==8'h17 || opcode==8'h1f || opcode==8'h9d) `I86_POP(POP_DONE)
          else if(opcode>=8'h70 && opcode<=8'h7f) `I86_IMM(1,EXECUTE)
          else if((opcode>=8'h80 && opcode<=8'h8f) || opcode==8'hc4 || opcode==8'hc5 ||
              opcode==8'hc6 || opcode==8'hc7 || (opcode>=8'hd0 && opcode<=8'hd3) ||
              (opcode>=8'hd8 && opcode<=8'hdf) || opcode==8'hf6 || opcode==8'hf7 ||
              opcode==8'hfe || opcode==8'hff) begin
            if(opcode==8'h8c || opcode==8'h8d || opcode==8'h8e || opcode==8'h8f ||
               opcode==8'hc4 || opcode==8'hc5 || opcode>=8'hd8 && opcode<=8'hdf) wide<=1;
            if(opcode==8'h82) wide<=0;
            state<=MODRM_FETCH;
          end else if((opcode>=8'h90 && opcode<=8'h99) || opcode==8'h9e || opcode==8'h9f) state<=EXECUTE;
          else if(opcode==8'h9a) `I86_IMM(4,EXECUTE)
          else if(opcode>=8'ha0 && opcode<=8'ha3) `I86_IMM(2,MOFFS)
          else if(opcode>=8'ha4 && opcode<=8'haf && opcode!=8'ha8 && opcode!=8'ha9) state<=STRING_START;
          else if(opcode==8'ha8 || opcode==8'ha9) `I86_IMM(opcode[0] ? 3'd2:3'd1,EXECUTE)
          else if(opcode>=8'hb0 && opcode<=8'hbf) begin wide<=opcode[3]; `I86_IMM(opcode[3] ? 3'd2:3'd1,EXECUTE) end
          else if(opcode==8'hc2 || opcode==8'hca || opcode==8'he8 || opcode==8'he9) `I86_IMM(2,EXECUTE)
          else if(opcode==8'hea) `I86_IMM(4,EXECUTE)
          else if(opcode==8'hcd || opcode==8'hd4 || opcode==8'hd5 || opcode>=8'he0 && opcode<=8'he7 || opcode==8'heb)
            `I86_IMM(1,EXECUTE)
          else if(opcode==8'hc3 || opcode==8'hcb || opcode==8'hcc || opcode==8'hce || opcode==8'hcf ||
              opcode==8'h27 || opcode==8'h2f || opcode==8'h37 || opcode==8'h3f || opcode==8'hd7 ||
              opcode>=8'hec && opcode<=8'hef || opcode==8'hf5 || opcode>=8'hf8 && opcode<=8'hfd)
            state<=EXECUTE;
          else if(opcode==8'h9b) begin wait_count<=0; state<=WAITING; end
          else if(opcode==8'hf4) begin retire_o<=1; trap_pending<=tf_start; lock_prefix<=0; state<=HALTED; end
          else state<=FAULT;
        end
        IMM_FETCH: begin
          transfer_addr<=physical(seg[1],ip); transfer_be<=ip[0] ? 2'b10:2'b01;
          transfer_segment<=2; transfer_write<=0; transfer_fetch<=1; transfer_first<=0;
          transfer_io<=0; transfer_intack<=0; transfer_data<=0; continuation<=IMM_BYTE; state<=BUS;
        end
        IMM_BYTE: begin
          immediate[immediate_pos*8+:8]<=read_byte; ip<=ip+16'd1;
          if(immediate_pos+3'd1==immediate_count) state<=immediate_continuation;
          else begin immediate_pos<=immediate_pos+3'd1; state<=IMM_FETCH; end
        end
        MODRM_FETCH: begin
          transfer_addr<=physical(seg[1],ip); transfer_be<=ip[0] ? 2'b10:2'b01;
          transfer_segment<=2; transfer_write<=0; transfer_fetch<=1; transfer_first<=0;
          transfer_io<=0; transfer_intack<=0; transfer_data<=0; continuation<=MODRM_DONE; state<=BUS;
        end
        MODRM_DONE: begin
          modrm<=read_byte; ip<=ip+16'd1; ea<=effective_base;
          ea_seg<=override_valid ? override_seg:default_seg;
          if((opcode==8'h8c || opcode==8'h8e) && (read_byte[5] || opcode==8'h8e && read_byte[5:3]==1) ||
             (opcode==8'h8d || opcode==8'hc4 || opcode==8'hc5) && read_byte[7:6]==3 ||
             (opcode==8'h8f || opcode==8'hc6 || opcode==8'hc7) && read_byte[5:3]!=0 ||
             opcode==8'hfe && read_byte[5:3]>1 || opcode==8'hff &&
             (read_byte[5:3]==7 || (read_byte[5:3]==3 || read_byte[5:3]==5) && read_byte[7:6]==3)) state<=FAULT;
          else begin
            // Intel 1979 manual section 2.5 requires LOCK for atomic XCHG.
            if(read_byte[7:6]==3) state<=PREPARE;
            else if(read_byte[7:6]==1) `I86_IMM(1,DISP_DONE)
            else if(read_byte[7:6]==2 || read_byte[2:0]==6) `I86_IMM(2,DISP_DONE)
            else state<=PREPARE;
          end
        end
        DISP_DONE: begin
          ea<=ea+(modrm[7:6]==1 ? {{8{immediate[7]}},immediate[7:0]}:immediate[15:0]); state<=PREPARE;
        end
        PREPARE: begin
          reg_value<=get_register(modrm[5:3],wide);
          if(opcode==8'h8f) `I86_POP(POP_DONE)
          else if(opcode==8'h88 || opcode==8'h89 || opcode==8'h8c || opcode==8'h8d ||
                  opcode==8'hc6 || opcode==8'hc7) state<=OPERAND_DONE;
          else if(modrm[7:6]==3) begin rm_value<=get_register(modrm[2:0],wide); state<=OPERAND_DONE; end
          else `I86_MEM(ea_seg,ea,0,wide,0,OPERAND_DONE,0)
        end
        OPERAND_DONE: begin
          if(modrm[7:6]!=3 && opcode!=8'h88 && opcode!=8'h89 && opcode!=8'h8c &&
             opcode!=8'h8d && opcode!=8'hc6 && opcode!=8'hc7) rm_value<=memory_result;
          if(opcode>=8'h80 && opcode<=8'h83 || opcode==8'hc6 || opcode==8'hc7 ||
             (opcode==8'hf6 || opcode==8'hf7) && modrm[5:3]<=1)
            `I86_IMM(opcode==8'h81 || opcode==8'hc7 || opcode==8'hf7 ? 3'd2:3'd1,EXECUTE)
          else state<=EXECUTE;
        end
        MEM_REQUEST: begin
          transfer_addr<=memory_addr;
          transfer_be<=memory_wide && !memory_addr[0] ? 2'b11 : (memory_addr[0] ? 2'b10:2'b01);
          transfer_data<=memory_addr[0] ? {memory_data[7:0],8'b0}:memory_data;
          transfer_write<=memory_write; transfer_fetch<=0; transfer_first<=0;
          transfer_io<=memory_io; transfer_intack<=0; transfer_segment<=memory_segment;
          continuation<=MEM_FIRST_DONE; state<=BUS;
        end
        MEM_FIRST_DONE: begin
          if(memory_wide && !memory_addr[0]) begin memory_result<=read_word; state<=memory_continuation; end
          else begin
            memory_result<={8'b0,read_byte};
            if(memory_wide) state<=MEM_SECOND_REQUEST; else state<=memory_continuation;
          end
          if((!memory_wide || !memory_addr[0]) && memory_continuation==BOUNDARY) begin
            retire_o<=1; trap_pending<=tf_start; lock_prefix<=0;
          end
        end
        MEM_SECOND_REQUEST: begin
          // ASSUMPTION: A3. Offset FFFFh wraps within the segment (physical oracle).
          transfer_addr<=memory_next_addr; transfer_be<=memory_next_addr[0] ? 2'b10:2'b01;
          transfer_data<=memory_next_addr[0] ? {memory_data[15:8],8'b0}:{8'b0,memory_data[15:8]};
          transfer_write<=memory_write; transfer_fetch<=0; transfer_first<=0;
          transfer_io<=memory_io; transfer_intack<=0; transfer_segment<=memory_segment;
          continuation<=MEM_SECOND_DONE; state<=BUS;
        end
        MEM_SECOND_DONE: begin
          memory_result[15:8]<=read_byte; memory_pair_active<=0; state<=memory_continuation;
          if(memory_continuation==BOUNDARY) begin retire_o<=1; trap_pending<=tf_start; lock_prefix<=0; end
        end
        WRITEBACK: begin
          if(modrm[7:6]==3) begin `I86_SET(modrm[2:0],wide,write_value) `I86_DONE end
          else `I86_MEM(ea_seg,ea,1,wide,write_value,BOUNDARY,0)
        end
        POP_ADVANCE: begin gpr[4]<=gpr[4]+16'd2; state<=pop_continuation; end
        POP_DONE: begin
          if(opcode==8'h8f) `I86_WRITE(memory_result)
          else begin
            if(opcode>=8'h58 && opcode<=8'h5f) gpr[opcode[2:0]]<=memory_result;
            else if(opcode==8'h9d) flags<=(memory_result & 16'h0fd5) | 16'hf002;
            else begin seg[opcode[4:3]]<=memory_result; all_shadow<=1; end
            `I86_DONE
            if(opcode==8'h07 || opcode==8'h17 || opcode==8'h1f) trap_pending<=0;
          end
        end
        MOFFS: begin
          if(opcode[1]) `I86_MEM(override_valid ? override_seg:2'd3,immediate[15:0],1,wide,get_register(0,wide),BOUNDARY,0)
          else `I86_MEM(override_valid ? override_seg:2'd3,immediate[15:0],0,wide,0,IO_DONE,0)
        end
        IO_DONE: begin
          if(opcode==8'ha0 || opcode==8'ha1 || opcode==8'hd7 || !opcode[1]) `I86_SET(0,wide,memory_result)
          `I86_DONE
        end
        EXECUTE: begin
          if(opcode<=8'h3d && opcode[2:0]<=5) begin
            flags<=alu_flags;
            if(opcode[5:3]==7) `I86_DONE
            else if(opcode[2]) begin `I86_SET(0,wide,alu_value) `I86_DONE end
            else if(opcode[1]) begin `I86_SET(modrm[5:3],wide,alu_value) `I86_DONE end
            else `I86_WRITE(alu_value)
          end else if(opcode>=8'h40 && opcode<=8'h4f) begin
            gpr[opcode[2:0]]<=alu_value; flags<={alu_flags[15:1],flags[0]}; `I86_DONE
          end else if(opcode>=8'h70 && opcode<=8'h7f) begin
            if(condition(opcode[3:0])) begin ip<=ip+{{8{immediate[7]}},immediate[7:0]}; `I86_REDIRECT end
            `I86_DONE
          end else if(opcode>=8'h80 && opcode<=8'h83) begin
            flags<=alu_flags; if(modrm[5:3]==7) `I86_DONE else `I86_WRITE(alu_value)
          end else if(opcode==8'h84 || opcode==8'h85 || opcode==8'ha8 || opcode==8'ha9) begin flags<=alu_flags; `I86_DONE end
          else if(opcode==8'h86 || opcode==8'h87) begin `I86_SET(modrm[5:3],wide,rm_value) `I86_WRITE(reg_value) end
          else if(opcode==8'h88 || opcode==8'h89) `I86_WRITE(reg_value)
          else if(opcode==8'h8a || opcode==8'h8b) begin `I86_SET(modrm[5:3],wide,rm_value) `I86_DONE end
          else if(opcode==8'h8c) `I86_WRITE(seg[modrm[4:3]])
          else if(opcode==8'h8d) begin gpr[modrm[5:3]]<=ea; `I86_DONE end
          else if(opcode==8'h8e) begin seg[modrm[4:3]]<=rm_value; all_shadow<=1; `I86_DONE trap_pending<=0; end
          else if(opcode>=8'h90 && opcode<=8'h97) begin
            gpr[0]<=gpr[opcode[2:0]]; gpr[opcode[2:0]]<=gpr[0]; `I86_DONE
          end else if(opcode==8'h98) begin gpr[0][15:8]<={8{gpr[0][7]}}; `I86_DONE end
          else if(opcode==8'h99) begin gpr[2]<={16{gpr[0][15]}}; `I86_DONE end
          else if(opcode==8'h9e) begin flags[7:0]<=(gpr[0][15:8] & 8'hd5) | 8'h02; `I86_DONE end
          else if(opcode==8'h9f) begin gpr[0][15:8]<=flags_o[7:0]; `I86_DONE end
          else if(opcode>=8'hb0 && opcode<=8'hbf) begin `I86_SET(opcode[2:0],wide,immediate[15:0]) `I86_DONE end
          else if(opcode==8'hc6 || opcode==8'hc7) `I86_WRITE(immediate[15:0])
          else if(opcode==8'hc4 || opcode==8'hc5) begin target_ip<=rm_value; state<=FAR_POINTER; end
          else if(opcode>=8'hd0 && opcode<=8'hd3) begin
            shift_value<=rm_value; shift_flags<=flags_o;
            shift_count<=opcode[1] ? gpr[1][7:0]:8'd1; state<=SHIFT_STEP;
          end else if(opcode>=8'hd8 && opcode<=8'hdf) begin esc_valid_o<=1; `I86_DONE end
          else if(opcode==8'hf6 || opcode==8'hf7) begin
            case(modrm[5:3])
              0,1: begin flags<=alu_flags; `I86_DONE end
              2: `I86_WRITE(~rm_value)
              3: begin flags<=alu_flags; `I86_WRITE(alu_value) end
              default: begin
                if(modrm[5:3]>=6 && divide_error) `I86_INTERRUPT(0,ip,1)
                else begin
                  if(repeat_kind!=0 && modrm[5:3]==7) begin
                    gpr[0]<=wide ? 16'd0-mul_ax:{mul_ax[15:8],8'(0-mul_ax[7:0])};
                  end else gpr[0]<=mul_ax;
                  if(wide) gpr[2]<=mul_dx;
                  if(modrm[5:3]<6) begin flags[0]<=mul_carry; flags[11]<=mul_carry; end
                  `I86_DONE
                end
              end
            endcase
          end else if(opcode==8'hfe || opcode==8'hff) begin
            case(modrm[5:3])
              0,1: begin flags<={alu_flags[15:1],flags[0]}; `I86_WRITE(alu_value) end
              2: begin target_ip<=rm_value; target_cs<=seg[1]; `I86_PUSH(ip,TRANSFER) end
              3,5: begin target_ip<=rm_value; state<=FAR_POINTER; end
              4: begin ip<=rm_value; `I86_REDIRECT `I86_DONE end
              6: `I86_PUSH(modrm[7:6]==3 && modrm[2:0]==4 ? gpr[4]-16'd2:rm_value,BOUNDARY)
              default: state<=FAULT;
            endcase
          end else if(opcode>=8'he0 && opcode<=8'he3) begin
            if(opcode==8'he3 ? gpr[1]==0 : gpr[1]!=1 &&
               (opcode==8'he2 || flags[6]==opcode[0])) begin
              ip<=ip+{{8{immediate[7]}},immediate[7:0]}; `I86_REDIRECT
            end
            if(opcode!=8'he3) gpr[1]<=gpr[1]-16'd1;
            `I86_DONE
          end else if(opcode>=8'he4 && opcode<=8'he7 || opcode>=8'hec && opcode<=8'hef)
            `I86_MEM(4,opcode[3] ? gpr[2]:{8'b0,immediate[7:0]},opcode[1],wide,get_register(0,wide),IO_DONE,1)
          else case(opcode)
            8'h27,8'h2f,8'h37,8'h3f,8'hd4,8'hd5: begin
              if(decimal_error) begin flags<=decimal_flags; `I86_INTERRUPT(0,ip,1) end
              else begin gpr[0]<=decimal_ax; flags<=decimal_flags; `I86_DONE end
            end
            8'h9a: begin target_ip<=immediate[15:0]; target_cs<=immediate[31:16]; `I86_PUSH(seg[1],CALL_PUSH_IP) end
            8'he8: begin target_ip<=ip+immediate[15:0]; target_cs<=seg[1]; `I86_PUSH(ip,TRANSFER) end
            8'he9: begin ip<=ip+immediate[15:0]; `I86_REDIRECT `I86_DONE end
            8'heb: begin ip<=ip+{{8{immediate[7]}},immediate[7:0]}; `I86_REDIRECT `I86_DONE end
            8'hea: begin ip<=immediate[15:0]; seg[1]<=immediate[31:16]; `I86_REDIRECT `I86_DONE end
            8'hc2,8'hc3,8'hca,8'hcb,8'hcf: `I86_POP(RET_IP)
            8'hcc: `I86_INTERRUPT(3,ip,1)
            8'hcd: `I86_INTERRUPT(immediate[7:0],ip,1)
            8'hce: if(flags[11]) `I86_INTERRUPT(4,ip,1) else `I86_DONE
            8'hd7: begin wide<=0; `I86_MEM(override_valid ? override_seg:2'd3,gpr[3]+{8'b0,gpr[0][7:0]},0,0,0,IO_DONE,0) end
            8'hf5: begin flags[0]<=!flags[0]; `I86_DONE end
            8'hf8: begin flags[0]<=0; `I86_DONE end
            8'hf9: begin flags[0]<=1; `I86_DONE end
            8'hfa: begin flags[9]<=0; `I86_DONE end
            8'hfb: begin flags[9]<=1; mask_shadow<=1; `I86_DONE end
            8'hfc: begin flags[10]<=0; `I86_DONE end
            8'hfd: begin flags[10]<=1; `I86_DONE end
            default: state<=FAULT;
          endcase
        end
        SHIFT_STEP: begin
          if(shift_count==0) begin flags<=shift_flags; `I86_WRITE(shift_value) end
          else begin shift_value<=shifted_value; shift_flags<=shifted_flags; shift_count<=shift_count-8'd1; end
        end
        FAR_POINTER: `I86_MEM(ea_seg,ea+16'd2,0,1,0,FAR_POINTER_DONE,0)
        FAR_POINTER_DONE: begin
          if(opcode==8'hc4 || opcode==8'hc5) begin
            gpr[modrm[5:3]]<=target_ip; seg[opcode[0] ? 3:0]<=memory_result; `I86_DONE
          end else begin
            target_cs<=memory_result;
            if(modrm[5:3]==3) `I86_PUSH(seg[1],CALL_PUSH_IP) else state<=TRANSFER;
          end
        end
        CALL_PUSH_IP: `I86_PUSH(ip,TRANSFER)
        TRANSFER: begin ip<=target_ip; seg[1]<=target_cs; `I86_REDIRECT `I86_DONE end
        RET_IP: begin
          target_ip<=memory_result;
          if(opcode==8'hca || opcode==8'hcb || opcode==8'hcf) `I86_POP(RET_CS)
          else begin
            ip<=memory_result;
            if(opcode==8'hc2) gpr[4]<=gpr[4]+immediate[15:0];
            `I86_REDIRECT `I86_DONE
          end
        end
        RET_CS: begin
          seg[1]<=memory_result;
          if(opcode==8'hcf) `I86_POP(RET_FLAGS)
          else begin
            ip<=target_ip; if(opcode==8'hca) gpr[4]<=gpr[4]+immediate[15:0];
            `I86_REDIRECT `I86_DONE
          end
        end
        RET_FLAGS: begin
          flags<=(memory_result & 16'h0fd5) | 16'hf002; ip<=target_ip; mask_shadow<=1;
          `I86_REDIRECT `I86_DONE
        end
        IRQ_FIRST: begin
          transfer_addr<=0; transfer_be<=3; transfer_data<=0; transfer_write<=0;
          transfer_fetch<=0; transfer_first<=0; transfer_io<=0; transfer_intack<=1; transfer_segment<=2;
          continuation<=IRQ_SECOND; state<=BUS;
        end
        IRQ_SECOND: begin
          transfer_addr<=0; transfer_be<=1; transfer_data<=0; transfer_write<=0;
          transfer_fetch<=0; transfer_first<=0; transfer_io<=0; transfer_intack<=1; transfer_segment<=2;
          continuation<=IRQ_VECTOR; state<=BUS;
        end
        IRQ_VECTOR: begin vector_number<=read_byte; acknowledge_lock<=0; state<=INT_START; end
        // Original interrupt microcode 19d..1a6 reads the vector before
        // writing the stack. This ordering matters when SS:SP aliases the IVT.
        INT_START: state<=INT_READ_IP;
        INT_SAVE_FLAGS: begin target_cs<=memory_result; `I86_PUSH(flags_o,INT_PUSH_CS) flags[9:8]<=0; end
        INT_PUSH_CS: `I86_PUSH(seg[1],INT_PUSH_IP)
        INT_PUSH_IP: `I86_PUSH(interrupt_return_ip,INT_DONE)
        INT_READ_IP: `I86_MEM(4,{6'b0,vector_number,2'b0},0,1,0,INT_READ_CS,0)
        INT_READ_CS: begin target_ip<=memory_result; `I86_MEM(4,{6'b0,vector_number,2'b0}+16'd2,0,1,0,INT_SAVE_FLAGS,0) end
        INT_DONE: begin
          ip<=target_ip; seg[1]<=target_cs; mask_shadow<=0; all_shadow<=0;
          lock_prefix<=0; state<=BOUNDARY; `I86_REDIRECT
          if(interrupt_instruction) begin retire_o<=1; trap_pending<=tf_start; end
        end
        STRING_START: begin
          if(repeat_kind!=0 && gpr[1]==0) `I86_DONE
          else case(opcode)
            8'ha4,8'ha5,8'ha6,8'ha7,8'hac,8'had:
              `I86_MEM(override_valid ? override_seg:2'd3,gpr[6],0,wide,0,STRING_SOURCE,0)
            8'haa,8'hab: `I86_MEM(0,gpr[7],1,wide,get_register(0,wide),STRING_UPDATE,0)
            8'hae,8'haf: `I86_MEM(0,gpr[7],0,wide,0,STRING_COMPARE,0)
            default: state<=FAULT;
          endcase
        end
        STRING_SOURCE: begin
          case(opcode)
            8'ha4,8'ha5: `I86_MEM(0,gpr[7],1,wide,memory_result,STRING_UPDATE,0)
            8'ha6,8'ha7: begin string_source<=memory_result; `I86_MEM(0,gpr[7],0,wide,0,STRING_COMPARE,0) end
            8'hac,8'had: begin `I86_SET(0,wide,memory_result) state<=STRING_UPDATE; end
            default: state<=FAULT;
          endcase
        end
        STRING_COMPARE: begin flags<=alu_flags; state<=STRING_UPDATE; end
        STRING_UPDATE: begin
          if(opcode==8'ha4 || opcode==8'ha5 || opcode==8'ha6 || opcode==8'ha7 || opcode==8'hac || opcode==8'had)
            gpr[6]<=flags[10] ? gpr[6]-(wide ? 16'd2:16'd1):gpr[6]+(wide ? 16'd2:16'd1);
          if(opcode!=8'hac && opcode!=8'had)
            gpr[7]<=flags[10] ? gpr[7]-(wide ? 16'd2:16'd1):gpr[7]+(wide ? 16'd2:16'd1);
          if(repeat_kind!=0) gpr[1]<=gpr[1]-16'd1;
          if(string_more) begin
            if((nmi_pending || intr_i && flags[9] && !mask_shadow || tf_start) && !all_shadow) begin
              // Original RPTI microcode decrements the corrected PC by two;
              // earlier prefixes are lost on an interrupted multi-prefix REP.
              ip<=ip-16'd2; trap_pending<=tf_start; state<=BOUNDARY; `I86_REDIRECT
            end else state<=STRING_START;
          end else `I86_DONE
        end
        WAITING: begin
          if(!test_n_i) `I86_DONE
          else if(wait_count==4) begin
            wait_count<=0;
            if((nmi_pending || intr_i && flags[9] && !mask_shadow) && !all_shadow) begin
              ip<=instruction_ip; state<=BOUNDARY; `I86_REDIRECT
            end
          end else wait_count<=wait_count+3'd1;
        end
        HALTED: if(nmi_pending || intr_i && flags[9] || trap_pending) state<=BOUNDARY;
        FAULT: ;
        default: state<=FAULT;
      endcase
    end
  end

`ifdef FORMAL
  logic past_valid=0;
  always_ff @(posedge clk) begin
    past_valid<=1;
    if(!past_valid) assume(!rst_n);
    if(past_valid && rst_n && $past(rst_n)) begin
      if($past(bus_req_o && !bus_ready_i)) begin
        assert(bus_req_o);
        assert($stable({bus_addr_o,bus_be_o,bus_write_o,bus_wdata_o,bus_fetch_o,bus_io_o,bus_intack_o}));
      end
      if($past(fault_o)) assert(fault_o && !bus_req_o && !retire_o);
      if(hlda_o) assert(!bus_req_o);
    end
    if(past_valid && !$past(rst_n)) begin
      assert(ip_o==0 && seg[1]==16'hffff && flags_o==16'hf002);
      assert(!halted_o && !fault_o);
    end
    if(bus_req_o) begin
      assert(bus_addr_o[0]==0 && bus_be_o!=0);
      assert(!(bus_fetch_o && (bus_write_o || bus_io_o || bus_intack_o)));
      assert(!(bus_intack_o && (bus_write_o || bus_io_o)));
    end
    cover(past_valid && bus_req_o && bus_fetch_o && bus_addr_o==20'hffff0);
    cover(past_valid && retire_o);
    cover(past_valid && bus_req_o && bus_write_o);
    cover(past_valid && halted_o);
    cover(past_valid && fault_o);
    cover(past_valid && bus_intack_o);
    cover(past_valid && hlda_o);
  end
`endif
endmodule
`undef I86_DONE
`undef I86_SET
`undef I86_IMM
`undef I86_MEM
`undef I86_PUSH
`undef I86_POP
`undef I86_WRITE
`undef I86_INTERRUPT
`undef I86_REDIRECT
