`timescale 1ns/1ps
// Functional Intel 8080. Transaction timing boundary is explicit in spec/spec.md.
module intel_8080 (
    input logic clk, rst_n,
    input logic bus_ready_i,
    input logic [7:0] bus_rdata_i,
    input logic int_i, hold_i,
    output logic bus_req_o, bus_write_o, bus_io_o, bus_intack_o,
    output logic [15:0] bus_addr_o,
    output logic [7:0] bus_wdata_o, bus_status_o,
    output logic inte_o, hlda_o, halted_o, retire_o, fault_o,
    output logic [15:0] pc_o, sp_o,
    output logic [55:0] regs_o,
    output logic [7:0] flags_o
);
  typedef enum logic [4:0] {BOUNDARY, FETCH, DECODE, OP_LO, OP_HI,
      MEM_RD, MEM_WR, POP_LO, POP_HI, PUSH_HI, PUSH_LO,
      X_RLO, X_RHI, X_WLO, X_WHI, IO_RD, IO_WR, IRQ_FETCH, FAULT} state_t;
  state_t state;
  logic [7:0] a, b, c, d, e, h, l, flags, op, operand_lo, saved_lo, write_data;
  logic [15:0] pc, sp, effective_address, push_value, jump_target, exchange_value;
  logic injected, push_jump, pop_return, ei_delay, irq_from_halt;
  logic [3:0] alu_kind;
  logic [7:0] alu_lhs, alu_rhs, alu_value, alu_flags;
  logic [16:0] pair_sum;
  logic [15:0] immediate_word;
  logic unused_reserved;
  assign unused_reserved = flags[5] ^ flags[3] ^ flags[1];

  assign pc_o = pc;
  assign sp_o = sp;
  assign regs_o = {a,b,c,d,e,h,l};
  assign flags_o = {flags[7:6],1'b0,flags[4],1'b0,flags[2],1'b1,flags[0]};
  assign immediate_word = {bus_rdata_i,operand_lo};
  assign pair_sum = {1'b0,h,l} + {1'b0,get_pair(op[5:4])};
  intel_8080_alu alu (.kind_i(alu_kind), .lhs_i(alu_lhs), .rhs_i(alu_rhs),
      .flags_i(flags_o), .value_o(alu_value), .flags_o(alu_flags));

  function automatic logic [7:0] get_reg(input logic [2:0] index);
    case (index)
      0: get_reg=b; 1: get_reg=c; 2: get_reg=d; 3: get_reg=e;
      4: get_reg=h; 5: get_reg=l; 7: get_reg=a; default: get_reg=0;
    endcase
  endfunction
  task automatic set_reg(input logic [2:0] index, input logic [7:0] value);
    case (index)
      0: b<=value; 1: c<=value; 2: d<=value; 3: e<=value;
      4: h<=value; 5: l<=value; 7: a<=value; default: ;
    endcase
  endtask
  function automatic logic [15:0] get_pair(input logic [1:0] index);
    case (index)
      0: get_pair={b,c}; 1: get_pair={d,e}; 2: get_pair={h,l}; default: get_pair=sp;
    endcase
  endfunction
  task automatic set_pair(input logic [1:0] index, input logic [15:0] value);
    case (index)
      0: begin b<=value[15:8]; c<=value[7:0]; end
      1: begin d<=value[15:8]; e<=value[7:0]; end
      2: begin h<=value[15:8]; l<=value[7:0]; end
      3: sp<=value;
    endcase
  endtask
  function automatic logic condition(input logic [2:0] index);
    case (index)
      0: condition=!flags[6]; 1: condition=flags[6];
      2: condition=!flags[0]; 3: condition=flags[0];
      4: condition=!flags[2]; 5: condition=flags[2];
      6: condition=!flags[7]; 7: condition=flags[7];
    endcase
  endfunction
  function automatic logic word_operand(input logic [7:0] instruction);
    word_operand = ((instruction & 8'hcf)==8'h01) ||
        instruction==8'h22 || instruction==8'h2a || instruction==8'h32 || instruction==8'h3a ||
        (instruction & 8'hc7)==8'hc2 || (instruction & 8'hc7)==8'hc4 ||
        instruction==8'hc3 || instruction==8'hcd;
  endfunction
  function automatic logic undefined_opcode(input logic [7:0] instruction);
    case (instruction)
      8'h08,8'h10,8'h18,8'h20,8'h28,8'h30,8'h38,8'hcb,8'hd9,8'hdd,8'hed,8'hfd:
        undefined_opcode=1;
      default: undefined_opcode=0;
    endcase
  endfunction
  task automatic finish_instruction;
    retire_o <= 1;
    state <= BOUNDARY;
    if (ei_delay) ei_delay <= 0;
  endtask

  always_comb begin
    alu_kind = {1'b0,op[5:3]};
    alu_lhs = a;
    alu_rhs = get_reg(op[2:0]);
    if (state == MEM_RD || state == OP_LO) alu_rhs = bus_rdata_i;
    if ((op & 8'hc7)==8'h04 || (op & 8'hc7)==8'h05) begin
      alu_kind = op[0] ? 4'd9 : 4'd8;
      alu_lhs = state == MEM_RD ? bus_rdata_i : get_reg(op[5:3]);
    end
    case (op)
      8'h27: alu_kind=10; 8'h07: alu_kind=11; 8'h0f: alu_kind=12;
      8'h17: alu_kind=13; 8'h1f: alu_kind=14; 8'h2f: alu_kind=15;
      default: ;
    endcase
  end

  always_comb begin
    bus_req_o = 1;
    bus_write_o = 0;
    bus_io_o = 0;
    bus_intack_o = 0;
    bus_addr_o = pc;
    bus_wdata_o = 0;
    bus_status_o = 8'h82; // Memory read, manufacturer table 2-1.
    case (state)
      FETCH: bus_status_o=8'ha2;
      IRQ_FETCH: begin bus_intack_o=1; bus_status_o=irq_from_halt ? 8'h2b : 8'h23; end
      OP_LO, OP_HI: begin
        if (injected) begin bus_intack_o=1; bus_status_o=8'h02; end
      end
      MEM_RD: bus_addr_o=effective_address;
      MEM_WR: begin
        bus_addr_o=effective_address; bus_write_o=1; bus_wdata_o=write_data; bus_status_o=0;
      end
      POP_LO, POP_HI, X_RLO: begin bus_addr_o=sp; bus_status_o=8'h86; end
      X_RHI: begin bus_addr_o=sp+16'd1; bus_status_o=8'h86; end
      PUSH_HI, PUSH_LO: begin
        bus_addr_o=sp; bus_write_o=1; bus_status_o=8'h04;
        bus_wdata_o=state==PUSH_HI ? push_value[15:8] : push_value[7:0];
      end
      X_WLO, X_WHI: begin
        bus_addr_o=state==X_WLO ? sp : sp+16'd1;
        bus_write_o=1; bus_status_o=8'h04;
        bus_wdata_o=state==X_WLO ? push_value[7:0] : push_value[15:8];
      end
      IO_RD, IO_WR: begin
        bus_addr_o={operand_lo,operand_lo}; bus_io_o=1;
        bus_write_o=state==IO_WR; bus_wdata_o=a;
        bus_status_o=state==IO_WR ? 8'h10 : 8'h42;
      end
      default: begin bus_req_o=0; bus_status_o=8'h02; end
    endcase
    if (hlda_o || !rst_n || fault_o) bus_req_o=0;
  end

  always_ff @(posedge clk) begin
    retire_o <= 0;
    if (!rst_n) begin
      state <= BOUNDARY;
      pc <= 0;
      op <= 0;
      injected <= 0;
      inte_o <= 0;
      hlda_o <= 0;
      halted_o <= 0;
      fault_o <= 0;
      ei_delay <= 0;
      irq_from_halt <= 0;
      // Intel systems manual 2-14: general registers, SP and flags retain state.
    end else if (hlda_o) begin
      if (!hold_i) hlda_o <= 0;
    end else if (bus_req_o && !bus_ready_i) begin
      // Wait preserves every transaction field and architectural register.
    end else begin
      if (bus_req_o && hold_i) hlda_o <= 1;
      case (state)
        BOUNDARY: begin
          if (hold_i) hlda_o <= 1;
          else if (int_i && inte_o && !ei_delay) begin
            state<=IRQ_FETCH; inte_o<=0; irq_from_halt<=halted_o; halted_o<=0; injected<=1;
          end else if (!halted_o) begin state<=FETCH; injected<=0; end
        end
        FETCH: begin op<=bus_rdata_i; pc<=pc+16'd1; state<=DECODE; end
        IRQ_FETCH: begin op<=bus_rdata_i; state<=DECODE; end
        DECODE: begin
          // Injected XTHL is a model limitation, not an Intel silicon claim.
          if (undefined_opcode(op) || (injected && op==8'he3)) begin fault_o<=1; state<=FAULT; end
          else if (word_operand(op) || (op & 8'hc7)==8'h06 || (op & 8'hc7)==8'hc6 ||
                   op==8'hd3 || op==8'hdb) state<=OP_LO;
          else if (op[7:6]==2'b01) begin
            if (op==8'h76) begin halted_o<=1; finish_instruction(); end
            else if (op[2:0]==6) begin effective_address<={h,l}; state<=MEM_RD; end
            else if (op[5:3]==6) begin
              effective_address<={h,l}; write_data<=get_reg(op[2:0]); state<=MEM_WR;
            end else begin set_reg(op[5:3],get_reg(op[2:0])); finish_instruction(); end
          end else if (op[7:6]==2'b10) begin
            if (op[2:0]==6) begin effective_address<={h,l}; state<=MEM_RD; end
            else begin a<=alu_value; flags<=alu_flags; finish_instruction(); end
          end else if ((op & 8'hc7)==8'h04 || (op & 8'hc7)==8'h05) begin
            if (op[5:3]==6) begin effective_address<={h,l}; state<=MEM_RD; end
            else begin set_reg(op[5:3],alu_value); flags<=alu_flags; finish_instruction(); end
          end else if ((op & 8'hcf)==8'h03 || (op & 8'hcf)==8'h0b) begin
            set_pair(op[5:4],op[3] ? get_pair(op[5:4])-16'd1 : get_pair(op[5:4])+16'd1);
            finish_instruction();
          end else if ((op & 8'hcf)==8'h09) begin
            h<=pair_sum[15:8]; l<=pair_sum[7:0]; flags[0]<=pair_sum[16]; finish_instruction();
          end else if (op==8'h0a || op==8'h1a || op==8'h02 || op==8'h12) begin
            effective_address<=op[4] ? {d,e} : {b,c};
            write_data<=a; state<=op[3] ? MEM_RD : MEM_WR;
          end else if (op==8'hc9 || (op & 8'hc7)==8'hc0) begin
            if (op==8'hc9 || condition(op[5:3])) begin pop_return<=1; state<=POP_LO; end
            else finish_instruction();
          end else if ((op & 8'hcf)==8'hc1) begin pop_return<=0; state<=POP_LO; end
          else if ((op & 8'hcf)==8'hc5) begin
            push_value<=op[5:4]==3 ? {a,flags_o} : get_pair(op[5:4]);
            push_jump<=0; sp<=sp-16'd1; state<=PUSH_HI;
          end else if ((op & 8'hc7)==8'hc7) begin
            push_value<=pc; jump_target<={10'b0,op[5:3],3'b0};
            push_jump<=1; sp<=sp-16'd1; state<=PUSH_HI;
          end else case (op)
            8'h00: finish_instruction();
            8'h07,8'h0f,8'h17,8'h1f,8'h27,8'h2f: begin a<=alu_value; flags<=alu_flags; finish_instruction(); end
            8'h37: begin flags[0]<=1; finish_instruction(); end
            8'h3f: begin flags[0]<=!flags[0]; finish_instruction(); end
            8'he9: begin pc<={h,l}; finish_instruction(); end
            8'hf9: begin sp<={h,l}; finish_instruction(); end
            8'heb: begin h<=d; l<=e; d<=h; e<=l; finish_instruction(); end
            8'he3: begin push_value<={h,l}; state<=X_RLO; end
            8'hf3: begin inte_o<=0; ei_delay<=0; finish_instruction(); end
            8'hfb: begin
              finish_instruction(); inte_o<=1;
              // Intel systems manual EI: recognize after the following instruction.
              ei_delay<=1;
            end
            default: begin fault_o<=1; state<=FAULT; end
          endcase
        end
        OP_LO: begin
          operand_lo<=bus_rdata_i;
          // ASSUMPTION: injected multi-byte operands do not advance PC; spec ledger.
          if (!injected) pc<=pc+16'd1;
          if (word_operand(op)) state<=OP_HI;
          else if ((op & 8'hc7)==8'h06) begin
            if (op[5:3]==6) begin effective_address<={h,l}; write_data<=bus_rdata_i; state<=MEM_WR; end
            else begin set_reg(op[5:3],bus_rdata_i); finish_instruction(); end
          end else if ((op & 8'hc7)==8'hc6) begin a<=alu_value; flags<=alu_flags; finish_instruction(); end
          else state<=op==8'hd3 ? IO_WR : IO_RD;
        end
        OP_HI: begin
          // ASSUMPTION: injected multi-byte operands do not advance PC; spec ledger.
          if (!injected) pc<=pc+16'd1;
          if ((op & 8'hcf)==8'h01) begin set_pair(op[5:4],immediate_word); finish_instruction(); end
          else if (op==8'hc3 || (op & 8'hc7)==8'hc2) begin
            if (op==8'hc3 || condition(op[5:3])) pc<=immediate_word;
            finish_instruction();
          end else if (op==8'hcd || (op & 8'hc7)==8'hc4) begin
            if (op==8'hcd || condition(op[5:3])) begin
              push_value<=injected ? pc : pc+16'd1; jump_target<=immediate_word;
              push_jump<=1; sp<=sp-16'd1; state<=PUSH_HI;
            end else finish_instruction();
          end else begin
            effective_address<=immediate_word;
            write_data<=op==8'h22 ? l : a;
            state<=op[3] ? MEM_RD : MEM_WR;
          end
        end
        MEM_RD: begin
          if (op==8'h2a) begin
            l<=bus_rdata_i; effective_address<=effective_address+16'd1; op<=8'h2b; state<=MEM_RD;
          end else if (op==8'h2b) begin h<=bus_rdata_i; finish_instruction(); end
          else if (op[7:6]==2'b01) begin set_reg(op[5:3],bus_rdata_i); finish_instruction(); end
          else if (op[7:6]==2'b10) begin a<=alu_value; flags<=alu_flags; finish_instruction(); end
          else if ((op & 8'hc7)==8'h04 || (op & 8'hc7)==8'h05) begin
            write_data<=alu_value; flags<=alu_flags; state<=MEM_WR;
          end else begin a<=bus_rdata_i; finish_instruction(); end
        end
        MEM_WR: begin
          if (op==8'h22) begin
            effective_address<=effective_address+16'd1; write_data<=h; op<=8'h23;
          end else finish_instruction();
        end
        POP_LO: begin saved_lo<=bus_rdata_i; sp<=sp+16'd1; state<=POP_HI; end
        POP_HI: begin
          sp<=sp+16'd1;
          if (pop_return) pc<={bus_rdata_i,saved_lo};
          else if (op[5:4]==3) begin
            a<=bus_rdata_i;
            // ASSUMPTION: POP PSW ignores reserved bits, external pop_psw; spec ledger.
            flags<={saved_lo[7:6],1'b0,saved_lo[4],1'b0,saved_lo[2],1'b1,saved_lo[0]};
          end else set_pair(op[5:4],{bus_rdata_i,saved_lo});
          finish_instruction();
        end
        PUSH_HI: begin sp<=sp-16'd1; state<=PUSH_LO; end
        PUSH_LO: begin if (push_jump) pc<=jump_target; finish_instruction(); end
        X_RLO: begin saved_lo<=bus_rdata_i; state<=X_RHI; end
        X_RHI: begin exchange_value<={bus_rdata_i,saved_lo}; state<=X_WLO; end
        X_WLO: state<=X_WHI;
        X_WHI: begin h<=exchange_value[15:8]; l<=exchange_value[7:0]; finish_instruction(); end
        IO_RD: begin a<=bus_rdata_i; finish_instruction(); end
        IO_WR: finish_instruction();
        default: ;
      endcase
    end
  end
`ifdef FORMAL
  `include "intel_8080_props.sv"
`endif
endmodule
