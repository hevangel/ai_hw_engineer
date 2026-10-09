`timescale 1ns / 1ps
// First functional 8086 milestone; encoding boundary is in spec/spec.md.
// ASSUMPTION: A5. FAULT is a verification stop, not a native #UD exception.
module intel_8086 (
    input logic clk,
    rst_n,
    input logic bus_ready_i,
    input logic [15:0] bus_rdata_i,
    output logic bus_req_o,
    bus_write_o,
    bus_fetch_o,
    output logic [19:0] bus_addr_o,
    output logic [1:0] bus_be_o,
    output logic [15:0] bus_wdata_o,
    output logic halted_o,
    fault_o,
    retire_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [15:0] ip_o,
    flags_o
);
  typedef enum logic [4:0] {
    BOUNDARY,
    FETCH,
    FETCH_DONE,
    DECODE,
    BUS,
    IMM_FETCH,
    IMM_BYTE,
    IMM_DONE,
    MODRM_FETCH,
    MODRM_DONE,
    DISP_DONE,
    PREPARE,
    READ_LOW,
    READ_HIGH,
    EXECUTE,
    WRITE_LOW,
    WRITE_HIGH,
    POP_LOW,
    POP_HIGH,
    POP_DONE,
    HALTED,
    FAULT,
    WRITEBACK
  } state_t;
  state_t state, continuation, immediate_continuation, memory_continuation;
  logic [15:0] gpr[0:7];
  logic [15:0] seg[0:3];
  logic [15:0] ip, flags;
  logic [7:0] opcode, modrm, read_byte;
  logic wide, override_valid;
  logic [1:0] override_seg, ea_seg;
  logic [15:0] ea, rm_value, reg_value, write_value;
  logic [19:0] transfer_addr, memory_addr, memory_next_addr;
  logic transfer_write, transfer_fetch;
  logic [ 7:0] transfer_data;
  logic [31:0] immediate;
  logic [2:0] immediate_count, immediate_pos;
  logic [2:0] alu_kind;
  logic [15:0] alu_lhs, alu_rhs, alu_value, alu_flags;
  logic alu_wide;
  logic [15:0] effective_base;
  logic [1:0] default_seg;
  integer index;

  function automatic logic [19:0] physical(input logic [15:0] segment_value,
                                           input logic [15:0] offset_value);
    physical = {segment_value, 4'b0} + {4'b0, offset_value};
  endfunction
  function automatic logic [15:0] get_register(input logic [2:0] number, input logic word_size);
    if (word_size) get_register = gpr[number];
    else if (number[2]) get_register = {8'b0, gpr[{1'b0, number[1:0]}][15:8]};
    else get_register = {8'b0, gpr[number][7:0]};
  endfunction
  function automatic logic [15:0] merged_register(input logic [15:0] current_value,
                                                  input logic high_byte, input logic word_size,
                                                  input logic [15:0] value);
    if (word_size) merged_register = value;
    else if (high_byte) merged_register = {value[7:0], current_value[7:0]};
    else merged_register = {current_value[15:8], value[7:0]};
  endfunction
  function automatic logic condition(input logic [3:0] cc);
    case (cc)
      0:  condition = flags[11];
      1:  condition = !flags[11];
      2:  condition = flags[0];
      3:  condition = !flags[0];
      4:  condition = flags[6];
      5:  condition = !flags[6];
      6:  condition = flags[0] || flags[6];
      7:  condition = !flags[0] && !flags[6];
      8:  condition = flags[7];
      9:  condition = !flags[7];
      10: condition = flags[2];
      11: condition = !flags[2];
      12: condition = flags[7] != flags[11];
      13: condition = flags[7] == flags[11];
      14: condition = flags[6] || (flags[7] != flags[11]);
      15: condition = !flags[6] && (flags[7] == flags[11]);
    endcase
  endfunction

  // ASSUMPTION: A2. Unbuffered fetch; each word uses two byte transfers.
  assign bus_req_o = rst_n && state == BUS;
  assign bus_addr_o = {transfer_addr[19:1], 1'b0};
  assign bus_be_o = transfer_addr[0] ? 2'b10 : 2'b01;
  assign bus_write_o = transfer_write;
  assign bus_fetch_o = transfer_fetch;
  assign bus_wdata_o = transfer_addr[0] ? {transfer_data, 8'b0} : {8'b0, transfer_data};
  assign halted_o = state == HALTED;
  assign fault_o = state == FAULT;
  assign ip_o = ip;
  assign flags_o = (flags & 16'h0fd5) | 16'hf002;
  for (genvar r = 0; r < 8; r = r + 1) begin : observe_gpr
    assign regs_o[r*16+:16] = gpr[r];
  end
  for (genvar s = 0; s < 4; s = s + 1) begin : observe_seg
    assign segs_o[s*16+:16] = seg[s];
  end

  always_comb begin
    case (read_byte[2:0])
      0: effective_base = gpr[3] + gpr[6];
      1: effective_base = gpr[3] + gpr[7];
      2: effective_base = gpr[5] + gpr[6];
      3: effective_base = gpr[5] + gpr[7];
      4: effective_base = gpr[6];
      5: effective_base = gpr[7];
      6: effective_base = read_byte[7:6] == 0 ? 16'b0 : gpr[5];
      7: effective_base = gpr[3];
    endcase
    default_seg = ((read_byte[2:0] == 2 || read_byte[2:0] == 3) ||
        (read_byte[2:0] == 6 && read_byte[7:6] != 0)) ? 2'd2 : 2'd3;
    alu_kind = opcode[5:3];
    alu_lhs = rm_value;
    alu_rhs = reg_value;
    alu_wide = wide;
    if (opcode <= 8'h3d) begin
      if (opcode[2]) begin
        alu_lhs = get_register(0, wide);
        alu_rhs = immediate[15:0];
      end else if (opcode[1]) begin
        alu_lhs = reg_value;
        alu_rhs = rm_value;
      end
    end else if (opcode >= 8'h40 && opcode <= 8'h4f) begin
      alu_kind = opcode[3] ? 3'd5 : 3'd0;
      alu_lhs  = gpr[opcode[2:0]];
      alu_rhs  = 1;
      alu_wide = 1;
    end else if (opcode == 8'h80 || opcode == 8'h81 || opcode == 8'h83) begin
      alu_kind = modrm[5:3];
      alu_rhs  = opcode == 8'h83 ? {{8{immediate[7]}}, immediate[7:0]} : immediate[15:0];
    end else if (opcode == 8'ha8 || opcode == 8'ha9) begin
      alu_kind = 4;
      alu_lhs  = get_register(0, wide);
      alu_rhs  = immediate[15:0];
    end else if (opcode == 8'h84 || opcode == 8'h85) alu_kind = 4;
  end
  intel_8086_alu alu (
      .wide_i (alu_wide),
      .kind_i (alu_kind),
      .lhs_i  (alu_lhs),
      .rhs_i  (alu_rhs),
      .flags_i(flags_o),
      .value_o(alu_value),
      .flags_o(alu_flags)
  );

  always_ff @(posedge clk) begin
    retire_o <= 0;
    if (!rst_n) begin
      state <= BOUNDARY;
      continuation <= BOUNDARY;
      immediate_continuation <= BOUNDARY;
      memory_continuation <= BOUNDARY;
      // ASSUMPTION: A1. Deterministic unspecified general-register reset values.
      for (index = 0; index < 8; index = index + 1) gpr[index] <= 0;
      seg[0] <= 0;
      seg[1] <= 16'hffff;
      seg[2] <= 0;
      seg[3] <= 0;
      ip <= 0;
      flags <= 16'hf002;
      opcode <= 0;
      modrm <= 0;
      read_byte <= 0;
      wide <= 0;
      override_valid <= 0;
      override_seg <= 0;
      ea_seg <= 0;
      ea <= 0;
      rm_value <= 0;
      reg_value <= 0;
      write_value <= 0;
      transfer_addr <= 0;
      memory_addr <= 0;
      memory_next_addr <= 0;
      transfer_write <= 0;
      transfer_fetch <= 0;
      transfer_data <= 0;
      immediate <= 0;
      immediate_count <= 0;
      immediate_pos <= 0;
    end else
      case (state)
        BOUNDARY: begin
          override_valid <= 0;
          state <= FETCH;
        end
        FETCH: begin
          transfer_addr <= (physical(seg[1], ip));
          transfer_write <= (0);
          transfer_fetch <= (1);
          transfer_data <= (0);
          continuation <= (FETCH_DONE);
          state <= BUS;
        end
        BUS:
        if (bus_ready_i) begin
          read_byte <= transfer_addr[0] ? bus_rdata_i[15:8] : bus_rdata_i[7:0];
          state <= continuation;
        end
        FETCH_DONE: begin
          opcode <= read_byte;
          ip <= ip + 16'd1;
          state <= DECODE;
        end
        DECODE: begin
          wide <= opcode[0];
          if (opcode == 8'h26 || opcode == 8'h2e || opcode == 8'h36 || opcode == 8'h3e) begin
            override_valid <= 1;
            override_seg <= opcode[4:3];
            state <= FETCH;
          end else if (opcode <= 8'h3d && opcode[2:0] <= 5) begin
            if (opcode[2]) begin
              immediate <= 0;
              immediate_pos <= 0;
              immediate_count <= (opcode[0] ? 3'd2 : 3'd1);
              immediate_continuation <= (EXECUTE);
              state <= IMM_FETCH;
            end else state <= MODRM_FETCH;
          end else if (opcode >= 8'h40 && opcode <= 8'h4f) state <= EXECUTE;
          else if ((opcode >= 8'h50 && opcode <= 8'h57) || opcode == 8'h06 ||
                 opcode == 8'h0e || opcode == 8'h16 || opcode == 8'h1e || opcode == 8'h9c) begin
            gpr[4] <= gpr[4] - 16'd2;
            memory_addr <= physical(seg[2], gpr[4] - 16'd2);
            memory_next_addr <= physical(seg[2], gpr[4] - 16'd1);
            if (opcode == 8'h9c) write_value <= flags_o;
            else if (opcode[6]) write_value <= opcode == 8'h54 ? gpr[4] - 16'd2 : gpr[opcode[2:0]];
            else write_value <= seg[opcode[4:3]];
            wide  <= 1;
            state <= WRITE_LOW;
          end else if ((opcode >= 8'h58 && opcode <= 8'h5f) || opcode == 8'h07 ||
                     opcode == 8'h17 || opcode == 8'h1f || opcode == 8'h9d) begin
            memory_addr <= physical(seg[2], gpr[4]);
            memory_next_addr <= physical(seg[2], gpr[4] + 16'd1);
            state <= POP_LOW;
          end else if (opcode >= 8'h70 && opcode <= 8'h7f) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (1);
            immediate_continuation <= (EXECUTE);
            state <= IMM_FETCH;
          end
        else if (opcode == 8'h80 || opcode == 8'h81 || opcode == 8'h83 ||
                 (opcode >= 8'h84 && opcode <= 8'h8e)) begin
            if (opcode == 8'h8c || opcode == 8'h8d || opcode == 8'h8e) wide <= 1;
            state <= MODRM_FETCH;
          end else if (opcode >= 8'h90 && opcode <= 8'h99) state <= EXECUTE;
          else if (opcode == 8'h9e || opcode == 8'h9f) state <= EXECUTE;
          else if (opcode >= 8'ha0 && opcode <= 8'ha3) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (2);
            immediate_continuation <= (IMM_DONE);
            state <= IMM_FETCH;
          end else if (opcode == 8'ha8 || opcode == 8'ha9) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (opcode[0] ? 3'd2 : 3'd1);
            immediate_continuation <= (EXECUTE);
            state <= IMM_FETCH;
          end else if (opcode >= 8'hb0 && opcode <= 8'hbf) begin
            wide <= opcode[3];
            begin
              immediate <= 0;
              immediate_pos <= 0;
              immediate_count <= (opcode[3] ? 3'd2 : 3'd1);
              immediate_continuation <= (EXECUTE);
              state <= IMM_FETCH;
            end
          end else
            case (opcode)
              8'he9: begin
                immediate <= 0;
                immediate_pos <= 0;
                immediate_count <= (2);
                immediate_continuation <= (EXECUTE);
                state <= IMM_FETCH;
              end
              8'hea: begin
                immediate <= 0;
                immediate_pos <= 0;
                immediate_count <= (4);
                immediate_continuation <= (EXECUTE);
                state <= IMM_FETCH;
              end
              8'heb: begin
                immediate <= 0;
                immediate_pos <= 0;
                immediate_count <= (1);
                immediate_continuation <= (EXECUTE);
                state <= IMM_FETCH;
              end
              8'hf4: begin
                retire_o <= 1;
                state <= HALTED;
              end
              8'hf5, 8'hf8, 8'hf9, 8'hfc, 8'hfd: state <= EXECUTE;
              default: begin
                state <= FAULT;
              end
            endcase
        end
        IMM_FETCH: begin
          transfer_addr <= (physical(seg[1], ip));
          transfer_write <= (0);
          transfer_fetch <= (1);
          transfer_data <= (0);
          continuation <= (IMM_BYTE);
          state <= BUS;
        end
        IMM_BYTE: begin
          immediate[immediate_pos*8+:8] <= read_byte;
          ip <= ip + 16'd1;
          if (immediate_pos + 3'd1 == immediate_count) state <= immediate_continuation;
          else begin
            immediate_pos <= immediate_pos + 3'd1;
            state <= IMM_FETCH;
          end
        end
        MODRM_FETCH: begin
          transfer_addr <= (physical(seg[1], ip));
          transfer_write <= (0);
          transfer_fetch <= (1);
          transfer_data <= (0);
          continuation <= (MODRM_DONE);
          state <= BUS;
        end
        MODRM_DONE: begin
          modrm <= read_byte;
          ip <= ip + 16'd1;
          ea <= effective_base;
          ea_seg <= override_valid ? override_seg : default_seg;
          if ((opcode == 8'h8c || opcode == 8'h8e) &&
            (read_byte[5] || (opcode == 8'h8e && read_byte[5:3] == 1))) begin
            state <= FAULT;
          end else if (opcode == 8'h8d && read_byte[7:6] == 3) begin
            state <= FAULT;
          end else if (read_byte[7:6] == 3) state <= PREPARE;
          else if (read_byte[7:6] == 1) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (1);
            immediate_continuation <= (DISP_DONE);
            state <= IMM_FETCH;
          end else if (read_byte[7:6] == 2 || read_byte[2:0] == 6) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (2);
            immediate_continuation <= (DISP_DONE);
            state <= IMM_FETCH;
          end else state <= PREPARE;
        end
        DISP_DONE: begin
          ea <= ea + (modrm[7:6] == 1 ? {{8{immediate[7]}}, immediate[7:0]} : immediate[15:0]);
          state <= PREPARE;
        end
        PREPARE: begin
          reg_value <= get_register(modrm[5:3], wide);
          if (modrm[7:6] == 3) begin
            rm_value <= get_register(modrm[2:0], wide);
            if (opcode == 8'h80 || opcode == 8'h81 || opcode == 8'h83) begin
              immediate <= 0;
              immediate_pos <= 0;
              immediate_count <= (opcode == 8'h81 ? 3'd2 : 3'd1);
              immediate_continuation <= (EXECUTE);
              state <= IMM_FETCH;
            end else state <= EXECUTE;
          end else if (opcode == 8'h88 || opcode == 8'h89 || opcode == 8'h8c || opcode == 8'h8d)
            state <= EXECUTE;
          else begin
            memory_addr <= physical(seg[ea_seg], ea);
            memory_next_addr <= physical(seg[ea_seg], ea + 16'd1);
            memory_continuation <= EXECUTE;
            state <= READ_LOW;
          end
        end
        IMM_DONE: begin
          memory_addr <= physical(seg[override_valid ? override_seg : 2'd3], immediate[15:0]);
          memory_next_addr <= physical(
              seg[override_valid ? override_seg : 2'd3], immediate[15:0] + 16'd1
          );
          if (opcode[1]) begin
            write_value <= get_register(0, wide);
            state <= WRITE_LOW;
          end else begin
            memory_continuation <= EXECUTE;
            state <= READ_LOW;
          end
        end
        READ_LOW: begin
          transfer_addr <= (memory_addr);
          transfer_write <= (0);
          transfer_fetch <= (0);
          transfer_data <= (0);
          continuation <= (READ_HIGH);
          state <= BUS;
        end
        READ_HIGH: begin
          rm_value <= {8'b0, read_byte};
          if (wide) begin
            // ASSUMPTION: A3. The word offset wraps at 16 bits within its segment.
            begin
              transfer_addr <= (memory_next_addr);
              transfer_write <= (0);
              transfer_fetch <= (0);
              transfer_data <= (0);
              continuation <= (POP_DONE);
              state <= BUS;
            end
          end else if (opcode == 8'h80 || opcode == 8'h83) begin
            immediate <= 0;
            immediate_pos <= 0;
            immediate_count <= (1);
            immediate_continuation <= (EXECUTE);
            state <= IMM_FETCH;
          end else state <= memory_continuation;
        end
        POP_DONE: begin
          if (opcode >= 8'h58 && opcode <= 8'h5f || opcode == 8'h07 ||
            opcode == 8'h17 || opcode == 8'h1f || opcode == 8'h9d) begin
            gpr[4] <= gpr[4] + 16'd2;
            if (opcode >= 8'h58 && opcode <= 8'h5f) gpr[opcode[2:0]] <= {read_byte, rm_value[7:0]};
            else if (opcode == 8'h9d) flags <= ({read_byte, rm_value[7:0]} & 16'h0fd5) | 16'hf002;
            else seg[opcode[4:3]] <= {read_byte, rm_value[7:0]};
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else begin
            rm_value[15:8] <= read_byte;
            if (opcode == 8'h81 || opcode == 8'h83) begin
              immediate <= 0;
              immediate_pos <= 0;
              immediate_count <= (opcode == 8'h81 ? 3'd2 : 3'd1);
              immediate_continuation <= (EXECUTE);
              state <= IMM_FETCH;
            end else state <= memory_continuation;
          end
        end
        POP_LOW: begin
          transfer_addr <= (memory_addr);
          transfer_write <= (0);
          transfer_fetch <= (0);
          transfer_data <= (0);
          continuation <= (POP_HIGH);
          state <= BUS;
        end
        POP_HIGH: begin
          rm_value[7:0] <= read_byte;
          begin
            transfer_addr <= (memory_next_addr);
            transfer_write <= (0);
            transfer_fetch <= (0);
            transfer_data <= (0);
            continuation <= (POP_DONE);
            state <= BUS;
          end
        end
        EXECUTE: begin
          if (opcode <= 8'h3d && opcode[2:0] <= 5) begin
            flags <= alu_flags;
            if (opcode[5:3] == 7) begin
              state <= BOUNDARY;
              retire_o <= 1;
            end else if (opcode[2]) begin
              begin
                gpr[(wide ? (0) : ((0) & 3'd3))] <=
                    merged_register(gpr[(wide ? (0) : ((0) & 3'd3))], (0 >= 3'd4), wide, alu_value);
              end
              begin
                state <= BOUNDARY;
                retire_o <= 1;
              end
            end else if (opcode[1]) begin
              begin
                gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))] <= merged_register(
                    gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))],
                    (modrm[5:3] >= 3'd4),
                    wide,
                    alu_value
                );
              end
              begin
                state <= BOUNDARY;
                retire_o <= 1;
              end
            end else begin
              write_value <= alu_value;
              state <= WRITEBACK;
            end
          end else if (opcode >= 8'h40 && opcode <= 8'h4f) begin
            gpr[opcode[2:0]] <= alu_value;
            flags <= {alu_flags[15:1], flags[0]};
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode >= 8'h70 && opcode <= 8'h7f) begin
            if (condition(opcode[3:0])) ip <= ip + {{8{immediate[7]}}, immediate[7:0]};
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h80 || opcode == 8'h81 || opcode == 8'h83) begin
            flags <= alu_flags;
            if (modrm[5:3] == 7) begin
              state <= BOUNDARY;
              retire_o <= 1;
            end else begin
              write_value <= alu_value;
              state <= WRITEBACK;
            end
          end else if (opcode == 8'h84 || opcode == 8'h85 || opcode == 8'ha8 || opcode == 8'ha9) begin
            flags <= alu_flags;
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h86 || opcode == 8'h87) begin
            begin
              gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))] <= merged_register(
                  gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))],
                  (modrm[5:3] >= 3'd4),
                  wide,
                  rm_value
              );
            end
            write_value <= reg_value;
            state <= WRITEBACK;
          end else if (opcode == 8'h88 || opcode == 8'h89) begin
            write_value <= reg_value;
            state <= WRITEBACK;
          end else if (opcode == 8'h8a || opcode == 8'h8b) begin
            begin
              gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))] <= merged_register(
                  gpr[(wide ? (modrm[5:3]) : ((modrm[5:3]) & 3'd3))],
                  (modrm[5:3] >= 3'd4),
                  wide,
                  rm_value
              );
            end
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h8c) begin
            write_value <= seg[modrm[4:3]];
            state <= WRITEBACK;
          end else if (opcode == 8'h8d) begin
            gpr[modrm[5:3]] <= ea;
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h8e) begin
            seg[modrm[4:3]] <= rm_value;
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode >= 8'h90 && opcode <= 8'h97) begin
            gpr[0] <= gpr[opcode[2:0]];
            gpr[opcode[2:0]] <= gpr[0];
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h98) begin
            gpr[0][15:8] <= {8{gpr[0][7]}};
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h99) begin
            gpr[2] <= {16{gpr[0][15]}};
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h9e) begin
            flags[7:0] <= (gpr[0][15:8] & 8'hd5) | 8'h02;
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'h9f) begin
            gpr[0][15:8] <= flags_o[7:0];
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode == 8'ha0 || opcode == 8'ha1) begin
            begin
              gpr[(wide ? (0) : ((0) & 3'd3))] <=
                  merged_register(gpr[(wide ? (0) : ((0) & 3'd3))], (0 >= 3'd4), wide, rm_value);
            end
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else if (opcode >= 8'hb0 && opcode <= 8'hbf) begin
            begin
              gpr[(wide ? (opcode[2:0]) : ((opcode[2:0]) & 3'd3))] <= merged_register(
                  gpr[(wide ? (opcode[2:0]) : ((opcode[2:0]) & 3'd3))],
                  (opcode[2:0] >= 3'd4),
                  wide,
                  immediate[15:0]
              );
            end
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else
            case (opcode)
              8'he9: begin
                ip <= ip + immediate[15:0];
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'heb: begin
                ip <= ip + {{8{immediate[7]}}, immediate[7:0]};
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hea: begin
                ip <= immediate[15:0];
                seg[1] <= immediate[31:16];
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hf5: begin
                flags[0] <= !flags[0];
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hf8: begin
                flags[0] <= 0;
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hf9: begin
                flags[0] <= 1;
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hfc: begin
                flags[10] <= 0;
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              8'hfd: begin
                flags[10] <= 1;
                begin
                  state <= BOUNDARY;
                  retire_o <= 1;
                end
              end
              default: begin
                state <= FAULT;
              end
            endcase
        end
        WRITEBACK: begin
          if (modrm[7:6] == 3) begin
            begin
              gpr[(wide ? (modrm[2:0]) : ((modrm[2:0]) & 3'd3))] <= merged_register(
                  gpr[(wide ? (modrm[2:0]) : ((modrm[2:0]) & 3'd3))],
                  (modrm[2:0] >= 3'd4),
                  wide,
                  write_value
              );
            end
            begin
              state <= BOUNDARY;
              retire_o <= 1;
            end
          end else begin
            memory_addr <= physical(seg[ea_seg], ea);
            memory_next_addr <= physical(seg[ea_seg], ea + 16'd1);
            state <= WRITE_LOW;
          end
        end
        WRITE_LOW: begin
          transfer_addr <= (memory_addr);
          transfer_write <= (1);
          transfer_fetch <= (0);
          transfer_data <= (write_value[7:0]);
          continuation <= (wide ? WRITE_HIGH : BOUNDARY);
          state <= BUS;
        end
        WRITE_HIGH: begin
          transfer_addr <= (memory_next_addr);
          transfer_write <= (1);
          transfer_fetch <= (0);
          transfer_data <= (write_value[15:8]);
          continuation <= (BOUNDARY);
          state <= BUS;
        end
        HALTED, FAULT: ;
        default: begin
          state <= FAULT;
        end
      endcase
    // A store retires only after its final byte has been accepted.
    if (rst_n && state == BUS && bus_ready_i && transfer_write && continuation == BOUNDARY)
      retire_o <= 1;
  end

`ifdef FORMAL
  logic past_valid = 0;
  always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid && rst_n && $past(rst_n)) begin
      if ($past(bus_req_o && !bus_ready_i)) begin
        assert (bus_req_o);
        assert ($stable({bus_addr_o, bus_be_o, bus_write_o, bus_wdata_o, bus_fetch_o}));
      end
      if ($past(halted_o)) assert (halted_o && !bus_req_o && !retire_o);
      if ($past(fault_o)) assert (fault_o && !bus_req_o && !retire_o);
    end
    if (past_valid && !$past(rst_n)) begin
      assert (ip_o == 0 && seg[1] == 16'hffff && flags_o == 16'hf002);
      assert (!halted_o && !fault_o);
    end
    if (bus_req_o) begin
      assert (bus_addr_o[0] == 0);
      assert (bus_be_o == 1 || bus_be_o == 2);
      assert (!(bus_fetch_o && bus_write_o));
    end
    cover (past_valid && bus_req_o && bus_fetch_o && bus_addr_o == 20'hffff0);
    cover (past_valid && retire_o);
    cover (past_valid && bus_req_o && bus_write_o);
    cover (past_valid && halted_o);
    cover (past_valid && fault_o);
  end
`endif
endmodule
