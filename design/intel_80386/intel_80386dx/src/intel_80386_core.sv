// Intel 80386 execution core (shared by the 386DX and 386SX profiles).
//
// Milestone M1 scope: real-address mode with 16- and 32-bit operand and
// address sizes, the complete real-mode general instruction set, precise
// faults and real-mode interrupt delivery. Protected mode, paging,
// virtual-8086 mode, debug-register breakpoints and the native DX/SX bus
// units are later milestones (see ../plans/implementation_plan.md).
//
// The core drives a transaction port, not the 386 pins: each request moves
// one to four bytes at an arbitrary byte address and completes when ack_i
// is high at a rising edge. The DX and SX bus units split requests into
// their native 32- and 16-bit cycles.
//
// ASSUMPTION: A1. Instruction bytes are fetched one per transaction from
// CS:EIP until the decoded length is reached; the prefetch queue and its
// bus ordering are not modelled.
// ASSUMPTION: A2. Clock counts differ from the original microcode.
`define C_SIZE(s) ((s) == 2'd0 ? 3'd1 : (s) == 2'd1 ? 3'd2 : 3'd4)
`define C_MEM(LIN,SZ,WE,WD,IO,NEXT) begin \
  mem_addr <= (LIN); mem_size <= (SZ); mem_we <= (WE); mem_wdata <= (WD); \
  mem_io <= (IO); mem_fetch <= 1'b0; ret_state <= state; ret_step <= (NEXT); \
  state <= S_MEM; end
`define C_FAULT(V) begin \
  if (state == S_INT) state <= S_SHUTDOWN; \
  else begin int_vec <= 8'(V); int_eip <= eip; state <= S_INT; istep <= 4'd0; end end
// Segmented data access: S_CHK performs the limit check and adds the base
// once for every call site.
`define C_DMEM(SEG,OFF,SZ,WE,WD,NEXT) begin \
  chk_seg <= 3'(SEG); chk_off <= (OFF); mem_size <= (SZ); mem_we <= (WE); \
  mem_wdata <= (WD); mem_io <= 1'b0; mem_fetch <= 1'b0; ret_state <= state; \
  ret_step <= (NEXT); state <= S_CHK; end
`define C_PUSH(V,SZ,NEXT) begin \
  `C_DMEM(3'd2, stack_off(stack_merge(tsp - 32'(SZ))), (SZ), 1'b1, (V), (NEXT)) \
  tsp <= stack_merge(tsp - 32'(SZ)); end
`define C_POP(SZ,NEXT) begin \
  `C_DMEM(3'd2, stack_off(tsp), (SZ), 1'b0, 32'b0, (NEXT)) \
  tsp <= stack_merge(tsp + 32'(SZ)); end
`define C_DONE(NEXT_EIP) begin eip <= (NEXT_EIP); state <= S_FETCH; fpos <= 5'd0; \
  ibuf <= '0; ibad <= '0; retire_o <= 1'b1; end
`define C_UD `C_FAULT(6)
`define C_SETR(N,SZ,V) begin \
  gpr[ridx((N), (SZ))] <= merge_reg(gpr[ridx((N), (SZ))], rhigh((N), (SZ)), (SZ), (V)); end
`define SET_RM(SZ,V) `C_SETR(rm,SZ,V)
`define RD_RM(N) if (is_mem) `C_DMEM(seg, ea, (N), 1'b0, 32'b0, 5'd1) else step <= 5'd1;
// Real-address-mode segment load: the selector and base change; the cached
// limit and attributes are kept (230985-001 section 14.1).
`define C_LOADSEG(S,V) begin sel[S] <= 16'(V); sbase[S] <= {12'b0, 16'(V), 4'b0}; end
`define C_JUMP(T) begin if ((T) > slimit[1]) `C_FAULT(13) else `C_DONE(T) end
`define C_TRAP(V) begin int_vec <= 8'(V); int_eip <= next_eip; state <= S_INT; istep <= 4'd0; end

module intel_80386_core (
    input  logic        clk,
    input  logic        rst_n,
    // Transaction port
    output logic        req_o,
    output logic        we_o,
    output logic        io_o,
    output logic        fetch_o,
    output logic [31:0] addr_o,
    output logic [2:0]  size_o,
    output logic [31:0] wdata_o,
    input  logic        ack_i,
    input  logic [31:0] rdata_i,
    // State load port (test harness / LOADALL-style initialisation). The
    // index order is the SingleStepTests RG32 order: CR0 CR3 EAX EBX ECX
    // EDX ESI EDI EBP ESP CS DS ES FS GS SS EIP EFLAGS DR6 DR7.
    input  logic        load_i,
    input  logic [4:0]  load_idx_i,
    input  logic [31:0] load_data_i,
    output logic [639:0] state_o,
    output logic        retire_o,
    output logic        halted_o,
    output logic        shutdown_o
);
  typedef enum logic [3:0] {
    S_FETCH, S_DECODE, S_EXEC, S_CHK, S_MEM, S_INT, S_DIV, S_HALT, S_SHUTDOWN
  } state_t;
  state_t state, ret_state;
  logic [4:0] step, ret_step;
  logic [3:0] istep;

  // Architectural state.
  logic [31:0] gpr [0:7];
  logic [15:0] sel [0:5];
  logic [31:0] sbase [0:5];
  logic [31:0] slimit [0:5];
  logic        sbig [0:5];
  logic [31:0] eip, eflags, cr0, cr2, cr3, dr6, dr7;
  logic [31:0] gdt_base, idt_base;
  logic [15:0] gdt_limit, idt_limit;

  // Fetch window.
  logic [127:0] ibuf;
  logic [15:0] ibad;
  logic [4:0] fpos;

  // Transaction registers.
  logic [31:0] mem_addr, mem_wdata, mdata;
  logic [2:0] mem_size;
  logic mem_we, mem_io, mem_fetch;
  logic [2:0] chk_seg;
  logic [31:0] chk_off;

  // Shared multiplier operands and product.
  logic [31:0] mul_a, mul_b;
  logic mul_sgn;
  logic [1:0] mul_sz;
  logic [63:0] mul_p;

  // Decoder outputs (combinational) and their latched copies.
  /* verilator lint_off UNUSEDSIGNAL */
  logic [3:0] dc_prefix_len;   // kept on the decoder interface for tracing
  /* verilator lint_on UNUSEDSIGNAL */
  logic dc_seg_override, dc_o32, dc_a32, dc_lock, dc_two_byte, dc_has_modrm;
  logic dc_base_valid, dc_index_valid, dc_default_ss, dc_too_long;
  logic [2:0] dc_seg, dc_reg, dc_rm, dc_base, dc_index;
  logic [1:0] dc_rep, dc_mod, dc_scale;
  logic [7:0] dc_opcode;
  logic [31:0] dc_disp, dc_imm1;
  logic [15:0] dc_imm2;
  logic [4:0] dc_length;

  logic o32, a32, lock, is_mem, base_valid, too_long;
  logic [1:0] rep;
  logic [2:0] rg, rm, seg, base_reg;
  logic [8:0] opx;
  logic [31:0] imm1, ea, next_eip;
  logic [15:0] imm2;

  // Execution temporaries.
  logic [31:0] t0, t1, t2, tsp, tbp;
  logic [7:0] int_vec;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] int_eip;   // the real-mode frame stores [15:0]; M2 uses all bits
  /* verilator lint_on UNUSEDSIGNAL */
  logic [4:0] count;

  // Divider.
  logic div_start, div_done;
  /* verilator lint_off UNUSEDSIGNAL */
  logic div_busy;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [63:0] div_dividend, div_quotient;
  logic [31:0] div_divisor, div_remainder;
  logic div_signed, div_neg_q, div_neg_r;

  intel_80386_decode u_decode (
      .window_i(ibuf), .code32_i(sbig[1]),
      .prefix_len_o(dc_prefix_len), .seg_override_o(dc_seg_override), .seg_o(dc_seg),
      .opsize32_o(dc_o32), .addrsize32_o(dc_a32), .lock_o(dc_lock), .rep_o(dc_rep),
      .two_byte_o(dc_two_byte), .opcode_o(dc_opcode), .has_modrm_o(dc_has_modrm),
      .mod_o(dc_mod), .reg_o(dc_reg), .rm_o(dc_rm), .base_valid_o(dc_base_valid),
      .base_o(dc_base), .index_valid_o(dc_index_valid), .index_o(dc_index),
      .scale_o(dc_scale), .disp_o(dc_disp), .default_ss_o(dc_default_ss),
      .imm1_o(dc_imm1), .imm2_o(dc_imm2), .length_o(dc_length), .too_long_o(dc_too_long));

  intel_80386_divider #(.W(32)) u_divider (
      .clk(clk), .rst_n(rst_n), .start_i(div_start), .dividend_i(div_dividend),
      .divisor_i(div_divisor), .busy_o(div_busy), .done_o(div_done),
      .quotient_o(div_quotient), .remainder_o(div_remainder));

  assign req_o = (state == S_MEM);
  assign we_o = mem_we;
  assign io_o = mem_io;
  assign fetch_o = mem_fetch;
  assign addr_o = mem_addr;
  assign size_o = mem_size;
  assign wdata_o = mem_wdata;
  assign halted_o = (state == S_HALT);
  assign shutdown_o = (state == S_SHUTDOWN);

  always_comb begin
    state_o = '0;
    state_o[0*32 +: 32] = cr0;
    state_o[1*32 +: 32] = cr3;
    state_o[2*32 +: 32] = gpr[0];
    state_o[3*32 +: 32] = gpr[3];
    state_o[4*32 +: 32] = gpr[1];
    state_o[5*32 +: 32] = gpr[2];
    state_o[6*32 +: 32] = gpr[6];
    state_o[7*32 +: 32] = gpr[7];
    state_o[8*32 +: 32] = gpr[5];
    state_o[9*32 +: 32] = gpr[4];
    state_o[10*32 +: 32] = {16'b0, sel[1]};
    state_o[11*32 +: 32] = {16'b0, sel[3]};
    state_o[12*32 +: 32] = {16'b0, sel[0]};
    state_o[13*32 +: 32] = {16'b0, sel[4]};
    state_o[14*32 +: 32] = {16'b0, sel[5]};
    state_o[15*32 +: 32] = {16'b0, sel[2]};
    state_o[16*32 +: 32] = eip;
    state_o[17*32 +: 32] = eflags;
    state_o[18*32 +: 32] = dr6;
    state_o[19*32 +: 32] = dr7;
  end

  // ---------------------------------------------------------------- helpers
  function automatic logic [31:0] getr(input logic [2:0] n, input logic [1:0] size);
    case (size)
      2'd0: getr = n[2] ? {24'b0, gpr[{1'b0, n[1:0]}][15:8]} : {24'b0, gpr[n][7:0]};
      2'd1: getr = {16'b0, gpr[n][15:0]};
      default: getr = gpr[n];
    endcase
  endfunction

  function automatic logic [2:0] ridx(input logic [2:0] n, input logic [1:0] size);
    ridx = (size == 2'd0) ? {1'b0, n[1:0]} : n;
  endfunction

  /* verilator lint_off UNUSEDSIGNAL */
  function automatic logic rhigh(input logic [2:0] n, input logic [1:0] size);
    rhigh = (size == 2'd0) && n[2];
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  function automatic logic [31:0] merge_reg(input logic [31:0] old, input logic high,
                                            input logic [1:0] size, input logic [31:0] v);
    case (size)
      2'd0: merge_reg = high ? {old[31:16], v[7:0], old[7:0]} : {old[31:8], v[7:0]};
      2'd1: merge_reg = {old[31:16], v[15:0]};
      default: merge_reg = v;
    endcase
  endfunction

  function automatic logic limit_fault(input logic [2:0] s, input logic [31:0] off,
                                       input logic [2:0] nbytes);
    logic [32:0] last;
    last = {1'b0, off} + {30'b0, nbytes} - 33'd1;
    limit_fault = last > {1'b0, slimit[s]};
  endfunction

  function automatic logic [31:0] stack_off(input logic [31:0] v);
    stack_off = sbig[2] ? v : {16'b0, v[15:0]};
  endfunction

  function automatic logic [31:0] stack_merge(input logic [31:0] v);
    stack_merge = sbig[2] ? v : {gpr[4][31:16], v[15:0]};
  endfunction

  function automatic logic [31:0] addr_mask(input logic [31:0] v);
    addr_mask = a32 ? v : {16'b0, v[15:0]};
  endfunction

  // Merge flag bits selected by mask.
  function automatic logic [31:0] fmerge(input logic [31:0] mask, input logic [31:0] f);
    fmerge = (eflags & ~mask) | (f & mask);
  endfunction

  function automatic logic [31:0] scaled(input logic [31:0] v, input logic [1:0] s);
    scaled = v << s;
  endfunction

  // Effective-address offset of the current decoder outputs. Evaluated at
  // DECODE with the register values that the instruction observes.
  function automatic logic [31:0] decode_ea();
    logic [31:0] v;
    logic sib_no_index;
    v = dc_disp;
    // A SIB byte without an index (index field 100b) and a nonzero scale
    // scales the base register; observed on the pinned 386EX captures and
    // noted by their README (Intel 230985-001 lists these rows without
    // comment).
    sib_no_index = dc_a32 && dc_has_modrm && dc_mod != 2'b11 && dc_rm == 3'd4 && !dc_index_valid;
    if (dc_base_valid) v = v + scaled(gpr[dc_base], sib_no_index ? dc_scale : 2'd0);
    if (dc_index_valid) v = v + scaled(gpr[dc_index], dc_a32 ? dc_scale : 2'd0);
    decode_ea = dc_a32 ? v : {16'b0, v[15:0]};
  endfunction

  // Operand size code of the current instruction: byte when the opcode's w
  // bit is clear for byte/word pairs, otherwise word or doubleword.
  logic [1:0] osz;
  logic [2:0] nbytes;
  always_comb begin
    osz = o32 ? 2'd2 : 2'd1;
    nbytes = o32 ? 3'd4 : 3'd2;
  end

  // r/m operand after step 0 has read it. getr() is inlined because Yosys
  // cannot elaborate a function that calls a state-reading function.
  function automatic logic [31:0] rm_value(input logic [1:0] size);
    if (is_mem) rm_value = mdata & intel_80386_pkg::size_mask(size);
    else case (size)
      2'd0: rm_value = rm[2] ? {24'b0, gpr[{1'b0, rm[1:0]}][15:8]} : {24'b0, gpr[rm][7:0]};
      2'd1: rm_value = {16'b0, gpr[rm][15:0]};
      default: rm_value = gpr[rm];
    endcase
  endfunction

  // Signed product helpers.
  function automatic logic [63:0] mul_signed(input logic [31:0] a, input logic [31:0] b,
                                             input logic [1:0] size);
    logic [31:0] ea_, eb_;
    logic signed [63:0] sa, sb;
    ea_ = intel_80386_pkg::sign_extend(a, size);
    eb_ = intel_80386_pkg::sign_extend(b, size);
    sa = $signed({{32{ea_[31]}}, ea_});
    sb = $signed({{32{eb_[31]}}, eb_});
    mul_signed = 64'(sa * sb);
  endfunction

  always_comb mul_p = mul_sgn ? mul_signed(mul_a, mul_b, mul_sz)
                             : {32'b0, mul_a & intel_80386_pkg::size_mask(mul_sz)} *
                               {32'b0, mul_b & intel_80386_pkg::size_mask(mul_sz)};

  // ---------------------------------------------------------------- engine
  // Blocking scratch values used inside the sequential process.
  logic [2:0] xs;
  logic [31:0] xv, xa, xb, xc, xsi, xdi, xcnt, xdelta, xbit;
  logic [63:0] xw;
  logic [7:0] xcount;
  logic [1:0] xop;
  logic xcont, xneg_a, xneg_b, xbig;
  logic [1:0] sz;
  logic [31:0] lhs, rhs, res, fl;
  integer lk;
  logic [63:0] alu_out;
  logic [95:0] sh_out;
  logic [63:0] product;
  logic [31:0] lin_fetch;
  logic [31:0] fetch_off;

  always_comb begin
    fetch_off = eip + {27'b0, fpos};
    lin_fetch = sbase[1] + fetch_off;
  end

  // The sequential process uses blocking assignments only for the scratch
  // values declared above (sz, xa, alu_out, ...), which are recomputed
  // before every use within a cycle and never carry state between cycles.
  /* verilator lint_off BLKSEQ */
  always_ff @(posedge clk) begin
    retire_o <= 1'b0;
    div_start <= 1'b0;
    if (!rst_n) begin
      // ASSUMPTION: A6. Reset values follow the 386 DX datasheet reset
      // table: CS=F000h with base FFFF0000h, EIP=FFF0h, EFLAGS=2, CR0 with
      // PE/MP/EM/TS/PG clear. DX holds the component identifier 0303h.
      for (lk = 0; lk < 8; lk = lk + 1) gpr[lk] <= 32'b0;
      gpr[2] <= 32'h0000_0303;
      for (lk = 0; lk < 6; lk = lk + 1) begin
        sel[lk] <= 16'b0; sbase[lk] <= 32'b0; slimit[lk] <= 32'h0000_FFFF; sbig[lk] <= 1'b0;
      end
      sel[1] <= 16'hF000;
      sbase[1] <= 32'hFFFF_0000;
      eip <= 32'h0000_FFF0;
      eflags <= 32'h0000_0002;
      cr0 <= 32'h0000_0000;
      cr2 <= 32'b0; cr3 <= 32'b0; dr6 <= 32'b0; dr7 <= 32'b0;
      gdt_base <= 32'b0; gdt_limit <= 16'hFFFF;
      idt_base <= 32'b0; idt_limit <= 16'h03FF;
      state <= S_FETCH;
      ret_state <= S_FETCH;
      step <= 5'd0; ret_step <= 5'd0; istep <= 4'd0;
      fpos <= 5'd0; ibuf <= '0; ibad <= '0;
      mem_addr <= 32'b0; mem_size <= 3'd1; mem_we <= 1'b0; mem_wdata <= 32'b0;
      mem_io <= 1'b0; mem_fetch <= 1'b0; mdata <= 32'b0;
      chk_seg <= 3'd0; chk_off <= 32'b0;
      mul_a <= 32'b0; mul_b <= 32'b0; mul_sgn <= 1'b0; mul_sz <= 2'd0;
      t0 <= 32'b0; t1 <= 32'b0; t2 <= 32'b0; tsp <= 32'b0; tbp <= 32'b0;
      int_vec <= 8'b0; int_eip <= 32'b0; count <= 5'b0;
      div_signed <= 1'b0; div_neg_q <= 1'b0; div_neg_r <= 1'b0;
      div_dividend <= 64'b0; div_divisor <= 32'b1;
      o32 <= 1'b0; a32 <= 1'b0; lock <= 1'b0; is_mem <= 1'b0; rep <= 2'd0; too_long <= 1'b0;
      rg <= 3'd0; rm <= 3'd0; seg <= 3'd3;
      base_valid <= 1'b0; base_reg <= 3'd0;
      opx <= 9'd0; imm1 <= 32'b0; imm2 <= 16'b0; ea <= 32'b0;
      next_eip <= 32'b0;
    end else if (load_i) begin
      case (load_idx_i)
        5'd0: cr0 <= load_data_i;
        5'd1: cr3 <= load_data_i;
        5'd2: gpr[0] <= load_data_i;
        5'd3: gpr[3] <= load_data_i;
        5'd4: gpr[1] <= load_data_i;
        5'd5: gpr[2] <= load_data_i;
        5'd6: gpr[6] <= load_data_i;
        5'd7: gpr[7] <= load_data_i;
        5'd8: gpr[5] <= load_data_i;
        5'd9: gpr[4] <= load_data_i;
        5'd10: begin sel[1] <= load_data_i[15:0]; sbase[1] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd11: begin sel[3] <= load_data_i[15:0]; sbase[3] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd12: begin sel[0] <= load_data_i[15:0]; sbase[0] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd13: begin sel[4] <= load_data_i[15:0]; sbase[4] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd14: begin sel[5] <= load_data_i[15:0]; sbase[5] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd15: begin sel[2] <= load_data_i[15:0]; sbase[2] <= {12'b0, load_data_i[15:0], 4'b0}; end
        5'd16: eip <= load_data_i;
        5'd17: eflags <= load_data_i;
        5'd18: dr6 <= load_data_i;
        5'd19: dr7 <= load_data_i;
        default: ;
      endcase
      state <= S_FETCH;
      fpos <= 5'd0; ibuf <= '0; ibad <= '0;
    end else begin
      case (state)
        // ------------------------------------------------------------ fetch
        S_FETCH: begin
          if (fpos != 5'd0 && (fpos >= dc_length || fpos == 5'd16)) begin
            state <= S_DECODE;
          end else if (fetch_off > slimit[1] || fetch_off < eip) begin
            ibad[fpos[3:0]] <= 1'b1;
            fpos <= fpos + 5'd1;
          end else begin
            mem_addr <= lin_fetch; mem_size <= 3'd1; mem_we <= 1'b0; mem_io <= 1'b0;
            mem_fetch <= 1'b1; ret_state <= S_FETCH; state <= S_MEM;
          end
        end

        S_CHK: begin
          if (limit_fault(chk_seg, chk_off, mem_size)) begin
            if (ret_state == S_INT) state <= S_SHUTDOWN;
            else begin
              int_vec <= (chk_seg == 3'd2) ? 8'd12 : 8'd13;
              int_eip <= eip;
              state <= S_INT;
              istep <= 4'd0;
            end
          end else begin
            mem_addr <= sbase[chk_seg] + chk_off;
            state <= S_MEM;
          end
        end

        S_MEM: begin
          if (ack_i) begin
            if (mem_fetch) begin
              ibuf[8*fpos[3:0] +: 8] <= rdata_i[7:0];
              fpos <= fpos + 5'd1;
              mem_fetch <= 1'b0;
            end else begin
              mdata <= rdata_i & intel_80386_pkg::size_mask(mem_size == 3'd1 ? 2'd0 :
                                                           mem_size == 3'd2 ? 2'd1 : 2'd2);
            end
            state <= ret_state;
            step <= ret_step;
            if (ret_state == S_INT) istep <= ret_step[3:0];
          end
        end

        // ----------------------------------------------------------- decode
        S_DECODE: begin
          o32 <= dc_o32; a32 <= dc_a32; lock <= dc_lock; rep <= dc_rep;
          rg <= dc_reg; rm <= dc_rm;
          is_mem <= dc_has_modrm && dc_mod != 2'b11;
          base_valid <= dc_base_valid;
          base_reg <= dc_base;
          seg <= dc_seg_override ? dc_seg : (dc_default_ss ? 3'd2 : 3'd3);
          opx <= {dc_two_byte, dc_opcode};
          imm1 <= dc_imm1; imm2 <= dc_imm2;
          ea <= decode_ea();
          next_eip <= eip + {27'b0, dc_length};
          tsp <= gpr[4];
          step <= 5'd0;
          // An instruction longer than 15 bytes raises #GP(0), except that an
          // invalid LOCK prefix raises #UD first (pinned captures 67 66 69,
          // 67 66 81 /7, 67 66 C7 with 16- and 17-byte LOCK forms).
          too_long <= dc_too_long || dc_length > 5'd15;
          if (!dc_lock && (dc_too_long || dc_length > 5'd15)) `C_FAULT(13)
          else if ((ibad & ((16'd1 << dc_length) - 16'd1)) != 16'd0 &&
                   !(dc_too_long || dc_length > 5'd15)) `C_FAULT(13)
          else state <= S_EXEC;
        end

        S_DIV: begin
          if (div_done) begin
            state <= S_EXEC;
            step <= 5'd2;
          end
        end

        // ---------------------------------------------- interrupt delivery
        // Real-address mode: push FLAGS, CS, IP; load CS:IP from the IVT at
        // IDTR.base + 4 * vector; clear IF and TF. 230985-001 section 9.
        // The vector is read before the frame is pushed (pinned captures
        // 62 #1752, F6.6 #1403, F7.6 #701: a frame overlapping the IVT entry
        // does not change the handler address).
        S_INT: begin
          case (istep)
            4'd0: begin
              tsp <= gpr[4];
              t2 <= eflags;
              if ({12'b0, int_vec, 2'b11} > {6'b0, idt_limit}) state <= S_SHUTDOWN;
              else `C_MEM(idt_base + {22'b0, int_vec, 2'b00}, 3'd4, 1'b0, 32'b0, 1'b0, 5'd1)
            end
            4'd1: begin
              t1 <= mdata;
              `C_DMEM(3'd2, stack_off(stack_merge(tsp - 32'd2)), 3'd2, 1'b1, {16'b0, t2[15:0]}, 5'd2)
              tsp <= stack_merge(tsp - 32'd2);
            end
            4'd2: begin
              `C_DMEM(3'd2, stack_off(stack_merge(tsp - 32'd2)), 3'd2, 1'b1, {16'b0, sel[1]}, 5'd3)
              tsp <= stack_merge(tsp - 32'd2);
            end
            4'd3: begin
              `C_DMEM(3'd2, stack_off(stack_merge(tsp - 32'd2)), 3'd2, 1'b1, {16'b0, int_eip[15:0]}, 5'd4)
              tsp <= stack_merge(tsp - 32'd2);
            end
            4'd4: begin
              gpr[4] <= tsp;
              sel[1] <= t1[31:16];
              sbase[1] <= {12'b0, t1[31:16], 4'b0};
              eflags[intel_80386_pkg::FLAG_IF] <= 1'b0;
              eflags[intel_80386_pkg::FLAG_TF] <= 1'b0;
              `C_DONE({16'b0, t1[15:0]})
            end
            default: state <= S_SHUTDOWN;
          endcase
        end

        S_HALT, S_SHUTDOWN: ;

        // ---------------------------------------------------------- execute
        S_EXEC: begin
          if (lock && !lockable()) `C_UD
          else if (too_long) `C_FAULT(13)
          else begin
          casez (opx)
            // ALU r/m,reg / reg,r/m / acc,imm (00-3F, low three bits 0..5)
            9'b0_00???0??, 9'b0_00???10?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin
                if (opx[2] == 1'b0 && is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b0, 32'b0, 5'd1)
                else step <= 5'd1;
              end else if (step == 5'd1) begin
                if (opx[2]) begin lhs = getr(3'd0, sz); rhs = imm1; end
                else if (opx[1]) begin lhs = getr(rg, sz); rhs = rm_value(sz); end
                else begin lhs = rm_value(sz); rhs = getr(rg, sz); end
                alu_out = intel_80386_pkg::alu({1'b0, opx[5:3]}, sz, lhs, rhs,
                                               eflags[intel_80386_pkg::FLAG_CF]);
                res = alu_out[31:0]; fl = alu_out[63:32];
                t0 <= res;
                if (opx[5:3] == 3'd7) begin
                  eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, fl);
                  `C_DONE(next_eip)
                end else if (opx[2] || opx[1] || !is_mem) begin
                  if (opx[2]) `C_SETR(3'd0, sz, res)
                  else if (opx[1]) `C_SETR(rg, sz, res)
                  else `SET_RM(sz, res)
                  eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, fl);
                  `C_DONE(next_eip)
                end else begin
                  t1 <= fl;
                  `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, res, 5'd2)
                end
              end else begin
                eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, t1);
                `C_DONE(next_eip)
              end
            end

            // Group 1: ALU r/m, imm (80, 81, 82, 83)
            9'b0_100000??: begin
              sz = opx[0] ? osz : 2'd0;
              rhs = (opx[1:0] == 2'b11) ? intel_80386_pkg::sign_extend(imm1, 2'd0) : imm1;
              if (step == 5'd0) begin
                if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b0, 32'b0, 5'd1)
                else step <= 5'd1;
              end else if (step == 5'd1) begin
                alu_out = intel_80386_pkg::alu({1'b0, rg}, sz, rm_value(sz), rhs,
                                               eflags[intel_80386_pkg::FLAG_CF]);
                if (rg == 3'd7) begin
                  eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                  `C_DONE(next_eip)
                end else if (!is_mem) begin
                  `SET_RM(sz, alu_out[31:0])
                  eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                  `C_DONE(next_eip)
                end else begin
                  t1 <= alu_out[63:32];
                  `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, alu_out[31:0], 5'd2)
                end
              end else begin
                eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, t1);
                `C_DONE(next_eip)
              end
            end

            // INC/DEC r16/r32 (40-4F)
            9'b0_0100????: begin
              alu_out = intel_80386_pkg::alu(opx[3] ? intel_80386_pkg::ALU_DEC : intel_80386_pkg::ALU_INC,
                                             osz, gpr[opx[2:0]], 32'b0, eflags[intel_80386_pkg::FLAG_CF]);
              `C_SETR(opx[2:0], osz, alu_out[31:0])
              eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
              `C_DONE(next_eip)
            end

            // PUSH r (50-57): PUSH SP stores the value before the decrement.
            9'b0_01010???: begin
              if (step == 5'd0) `C_PUSH(getr(opx[2:0], osz), nbytes, 5'd1)
              else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // POP r (58-5F)
            9'b0_01011???: begin
              if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else begin
                gpr[4] <= tsp;
                `C_SETR(opx[2:0], osz, mdata)
                `C_DONE(next_eip)
              end
            end

            // PUSH ES/CS/SS/DS (06 0E 16 1E), PUSH FS/GS (0F A0, 0F A8)
            // ASSUMPTION: A4. A 32-bit push writes the zero-extended selector
            // as a doubleword; the captures (66 06 ...) do not show whether
            // the upper word is written or left unchanged.
            9'b0_000??110, 9'b1_10100000, 9'b1_10101000: begin
              if (step == 5'd0) begin
                xs = opx[8] ? (opx[3] ? 3'd5 : 3'd4) : {1'b0, opx[4:3]};
                `C_PUSH({16'b0, sel[xs]}, nbytes, 5'd1)
              end else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // POP ES/SS/DS (07 17 1F), POP FS/GS (0F A1, 0F A9)
            9'b0_000??111, 9'b1_10100001, 9'b1_10101001: begin
              xs = opx[8] ? (opx[3] ? 3'd5 : 3'd4) : {1'b0, opx[4:3]};
              // A 32-bit POP Sreg reads only the selector word and releases
              // four bytes (pinned captures 66 07/17/1F, 66 0F A1/A9).
              if (!opx[8] && opx[4:3] == 2'd1) `C_UD
              else if (step == 5'd0) begin
                `C_DMEM(3'd2, stack_off(tsp), 3'd2, 1'b0, 32'b0, 5'd1)
                tsp <= stack_merge(tsp + 32'(nbytes));
              end
              else begin
                gpr[4] <= tsp;
                `C_LOADSEG(xs, mdata[15:0])
                `C_DONE(next_eip)
              end
            end

            // PUSHA (60): AX CX DX BX original-SP BP SI DI. The 386 writes the
            // frame from its lowest address up (DI first); a stack fault
            // part-way leaves the lower slots written (pinned capture 66 60).
            9'b0_01100000: begin
              if (step == 5'd0) begin
                t0 <= gpr[4];
                tsp <= stack_merge(gpr[4] - {26'b0, nbytes, 3'b000});
                step <= 5'd1;
              end else if (step <= 5'd8) begin
                xs = 3'd7 - (step[2:0] - 3'd1);
                xv = (xs == 3'd4) ? t0 : gpr[xs];
                `C_DMEM(3'd2, stack_off(stack_merge(tsp + ({27'b0, step - 5'd1} << (o32 ? 2 : 1)))), nbytes, 1'b1,
                        xv & intel_80386_pkg::size_mask(osz), step + 5'd1)
              end else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // POPA (61): DI SI BP (skip) BX DX CX AX. Each register is written
            // as it is popped, so a stack fault part-way leaves the earlier
            // registers loaded (pinned capture 61 #681); ESP commits at the end.
            // With a 16-bit stack, POPAD loads ESP[31:16] from the skipped
            // ESP image (pinned capture 66 61).
            9'b0_01100001: begin
              if (step >= 5'd2 && step <= 5'd9) begin
                xs = 3'd7 - (step[2:0] - 3'd2);
                if (xs != 3'd4) `C_SETR(xs, osz, mdata)
                else t0 <= mdata;
              end
              if (step == 5'd0) step <= 5'd1;
              else if (step <= 5'd8) `C_POP(nbytes, step + 5'd1)
              else begin
                gpr[4] <= (o32 && !sbig[2]) ? {t0[31:16], tsp[15:0]} : tsp;
                `C_DONE(next_eip)
              end
            end

            // BOUND r, m (62)
            9'b0_01100010: begin
              if (!is_mem) `C_UD
              else if (step == 5'd0) `C_DMEM(seg, ea, nbytes, 1'b0, 32'b0, 5'd1)
              else if (step == 5'd1) begin
                t0 <= mdata;
                `C_DMEM(seg, addr_mask(ea + 32'(nbytes)), nbytes, 1'b0, 32'b0, 5'd2)
              end else begin
                xa = intel_80386_pkg::sign_extend(getr(rg, osz), osz);
                xb = intel_80386_pkg::sign_extend(t0, osz);
                xc = intel_80386_pkg::sign_extend(mdata, osz);
                if ($signed(xa) < $signed(xb) || $signed(xa) > $signed(xc)) `C_FAULT(5)
                else `C_DONE(next_eip)
              end
            end

            // PUSH imm (68), PUSH imm8 (6A)
            9'b0_01101000, 9'b0_01101010: begin
              if (step == 5'd0)
                `C_PUSH((opx[1] ? intel_80386_pkg::sign_extend(imm1, 2'd0) : imm1) &
                        intel_80386_pkg::size_mask(osz), nbytes, 5'd1)
              else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // IMUL r, r/m, imm (69, 6B); IMUL r, r/m (0F AF)
            9'b0_01101001, 9'b0_01101011, 9'b1_10101111: begin
              if (step == 5'd0) begin `RD_RM(nbytes) end
              else if (step == 5'd1) begin
                mul_a <= rm_value(osz);
                mul_b <= opx[8] ? getr(rg, osz) : opx[1] ? intel_80386_pkg::sign_extend(imm1, 2'd0) : imm1;
                mul_sgn <= 1'b1;
                mul_sz <= osz;
                step <= 5'd2;
              end else begin
                product = mul_p;
                xv = product[31:0] & intel_80386_pkg::size_mask(osz);
                fl = intel_80386_pkg::result_flags(xv, osz);
                fl[intel_80386_pkg::FLAG_CF] = {{32{intel_80386_pkg::sign_bit(xv, osz)}},
                                                intel_80386_pkg::sign_extend(xv, osz)} != product;
                fl[intel_80386_pkg::FLAG_OF] = fl[intel_80386_pkg::FLAG_CF];
                `C_SETR(rg, osz, xv)
                eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, fl);
                `C_DONE(next_eip)
              end
            end

            // Jcc rel8 (70-7F), Jcc rel16/32 (0F 80-8F)
            9'b0_0111????, 9'b1_1000????: begin
              xv = opx[8] ? (o32 ? imm1 : intel_80386_pkg::sign_extend(imm1, 2'd1))
                          : intel_80386_pkg::sign_extend(imm1, 2'd0);
              if (intel_80386_pkg::condition(opx[3:0], eflags)) `C_JUMP(ip_mask(next_eip + xv))
              else `C_DONE(next_eip)
            end

            // TEST r/m, r (84, 85)
            9'b0_1000010?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else begin
                alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_AND, sz, rm_value(sz), getr(rg, sz), 1'b0);
                eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                `C_DONE(next_eip)
              end
            end

            // XCHG r/m, r (86, 87)
            9'b0_1000011?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else if (step == 5'd1) begin
                t0 <= rm_value(sz);
                if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, getr(rg, sz), 5'd2)
                else begin `SET_RM(sz, getr(rg, sz)) step <= 5'd2; end
              end else begin
                `C_SETR(rg, sz, t0)
                `C_DONE(next_eip)
              end
            end

            // MOV r/m, r (88, 89)
            9'b0_1000100?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin
                if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, getr(rg, sz), 5'd1)
                else begin `SET_RM(sz, getr(rg, sz)) `C_DONE(next_eip) end
              end else `C_DONE(next_eip)
            end

            // MOV r, r/m (8A, 8B)
            9'b0_1000101?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else begin `C_SETR(rg, sz, rm_value(sz)) `C_DONE(next_eip) end
            end

            // MOV r/m, Sreg (8C)
            9'b0_10001100: begin
              if (rg > 3'd5) `C_UD
              else if (step == 5'd0) begin
                if (is_mem) `C_DMEM(seg, ea, 3'd2, 1'b1, {16'b0, sel[rg]}, 5'd1)
                else begin
                  // ASSUMPTION: A7. A 32-bit register destination receives the
                  // zero-extended selector.
                  `SET_RM(osz, {16'b0, sel[rg]})
                  `C_DONE(next_eip)
                end
              end else `C_DONE(next_eip)
            end

            // LEA (8D)
            9'b0_10001101: begin
              if (!is_mem) `C_UD
              else begin `C_SETR(rg, osz, ea) `C_DONE(next_eip) end
            end

            // MOV Sreg, r/m16 (8E): MOV CS is invalid on the 386.
            9'b0_10001110: begin
              if (rg == 3'd1 || rg > 3'd5) `C_UD
              else if (step == 5'd0) begin `RD_RM(3'd2) end
              else begin `C_LOADSEG(rg, rm_value(2'd1)) `C_DONE(next_eip) end
            end

            // POP r/m (8F /0): an ESP base addresses with the incremented ESP.
            9'b0_10001111: begin
              if (rg != 3'd0) `C_UD
              else if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else if (step == 5'd1) begin
                if (is_mem) begin
                  xv = (a32 && base_valid && base_reg == 3'd4) ? addr_mask(ea + 32'(nbytes)) : ea;
                  `C_DMEM(seg, xv, nbytes, 1'b1, mdata, 5'd2)
                end else begin
                  gpr[4] <= tsp;
                  `SET_RM(osz, mdata)
                  `C_DONE(next_eip)
                end
              end else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // XCHG eAX, r (90-97)
            9'b0_10010???: begin
              if (step == 5'd0) begin
                t0 <= getr(opx[2:0], osz);
                `C_SETR(opx[2:0], osz, getr(3'd0, osz))
                step <= 5'd1;
              end else begin `C_SETR(3'd0, osz, t0) `C_DONE(next_eip) end
            end

            // CBW/CWDE (98), CWD/CDQ (99)
            9'b0_10011000: begin
              `C_SETR(3'd0, osz, intel_80386_pkg::sign_extend(gpr[0], o32 ? 2'd1 : 2'd0))
              `C_DONE(next_eip)
            end
            9'b0_10011001: begin
              `C_SETR(3'd2, osz, {32{intel_80386_pkg::sign_bit(gpr[0], osz)}})
              `C_DONE(next_eip)
            end

            // CALL ptr16:16/32 (9A)
            9'b0_10011010: begin
              if (step == 5'd0) `C_PUSH({16'b0, sel[1]}, nbytes, 5'd1)
              else if (step == 5'd1) `C_PUSH(next_eip & intel_80386_pkg::size_mask(osz), nbytes, 5'd2)
              else begin
                xv = o32 ? imm1 : {16'b0, imm1[15:0]};
                if (xv > slimit[1]) `C_FAULT(13)
                else begin
                  gpr[4] <= tsp;
                  `C_LOADSEG(3'd1, imm2)
                  `C_DONE(xv)
                end
              end
            end

            // WAIT (9B): #NM when MP and TS are both set.
            9'b0_10011011: begin
              if (cr0[1] && cr0[3]) `C_FAULT(7)
              else `C_DONE(next_eip)
            end

            // PUSHF (9C): the image has VM and RF clear.
            9'b0_10011100: begin
              if (step == 5'd0) `C_PUSH(o32 ? (eflags & 32'h0000_7FD7) : {16'b0, eflags[15:0]}, nbytes, 5'd1)
              else begin gpr[4] <= tsp; `C_DONE(next_eip) end
            end

            // POPF (9D)
            9'b0_10011101: begin
              if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else begin
                gpr[4] <= tsp;
                eflags <= popped_flags(mdata, o32);
                `C_DONE(next_eip)
              end
            end

            // SAHF (9E), LAHF (9F)
            9'b0_10011110: begin
              eflags <= {eflags[31:8], (gpr[0][15:8] & 8'hD5) | 8'h02};
              `C_DONE(next_eip)
            end
            9'b0_10011111: begin
              gpr[0] <= {gpr[0][31:16], eflags[7:0], gpr[0][7:0]};
              `C_DONE(next_eip)
            end

            // MOV AL/eAX, moffs (A0, A1); MOV moffs, AL/eAX (A2, A3)
            9'b0_101000??: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin
                if (opx[1]) `C_DMEM(seg, addr_mask(imm1), `C_SIZE(sz), 1'b1, getr(3'd0, sz), 5'd1)
                else `C_DMEM(seg, addr_mask(imm1), `C_SIZE(sz), 1'b0, 32'b0, 5'd1)
              end else begin
                if (!opx[1]) `C_SETR(3'd0, sz, mdata)
                `C_DONE(next_eip)
              end
            end

            // TEST AL/eAX, imm (A8, A9)
            9'b0_1010100?: begin
              sz = opx[0] ? osz : 2'd0;
              alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_AND, sz, gpr[0], imm1, 1'b0);
              eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
              `C_DONE(next_eip)
            end

            // String instructions: MOVS CMPS STOS LODS SCAS INS OUTS
            9'b0_1010010?, 9'b0_1010011?, 9'b0_1010101?, 9'b0_1010110?, 9'b0_1010111?,
            9'b0_0110110?, 9'b0_0110111?: begin
              sz = opx[0] ? osz : 2'd0;
              xsi = a32 ? gpr[6] : {16'b0, gpr[6][15:0]};
              xdi = a32 ? gpr[7] : {16'b0, gpr[7][15:0]};
              xcnt = a32 ? gpr[1] : {16'b0, gpr[1][15:0]};
              xdelta = {29'b0, `C_SIZE(sz)};
              if (eflags[intel_80386_pkg::FLAG_DF]) xdelta = 32'd0 - xdelta;
              if (step == 5'd0) begin
                if (rep != 2'd0 && xcnt == 32'b0) `C_DONE(next_eip)
                else case (opx[7:0])
                  8'hAA, 8'hAB: `C_DMEM(3'd0, xdi, `C_SIZE(sz), 1'b1, getr(3'd0, sz), 5'd2)
                  8'hAE, 8'hAF: `C_DMEM(3'd0, xdi, `C_SIZE(sz), 1'b0, 32'b0, 5'd2)
                  8'hAC, 8'hAD: `C_DMEM(seg, xsi, `C_SIZE(sz), 1'b0, 32'b0, 5'd2)
                  8'h6C, 8'h6D: `C_MEM({16'b0, gpr[2][15:0]}, `C_SIZE(sz), 1'b0, 32'b0, 1'b1, 5'd1)
                  default: `C_DMEM(seg, xsi, `C_SIZE(sz), 1'b0, 32'b0, 5'd1)
                endcase
              end else if (step == 5'd1) begin
                t0 <= mdata;
                case (opx[7:0])
                  8'hA6, 8'hA7: `C_DMEM(3'd0, xdi, `C_SIZE(sz), 1'b0, 32'b0, 5'd2)
                  8'h6E, 8'h6F: `C_MEM({16'b0, gpr[2][15:0]}, `C_SIZE(sz), 1'b1, mdata, 1'b1, 5'd2)
                  default: `C_DMEM(3'd0, xdi, `C_SIZE(sz), 1'b1, mdata, 5'd2)
                endcase
              end else begin
                fl = eflags;
                xcont = 1'b1;
                case (opx[7:0])
                  8'hA6, 8'hA7: begin
                    alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_SUB, sz, t0, mdata, 1'b0);
                    fl = fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                    xcont = (rep == 2'd3) ? fl[intel_80386_pkg::FLAG_ZF] : !fl[intel_80386_pkg::FLAG_ZF];
                  end
                  8'hAE, 8'hAF: begin
                    alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_SUB, sz, gpr[0], mdata, 1'b0);
                    fl = fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                    xcont = (rep == 2'd3) ? fl[intel_80386_pkg::FLAG_ZF] : !fl[intel_80386_pkg::FLAG_ZF];
                  end
                  8'hAC, 8'hAD: `C_SETR(3'd0, sz, mdata)
                  default: ;
                endcase
                eflags <= fl;
                if (uses_si(opx[7:0])) gpr[6] <= a32 ? xsi + xdelta : {gpr[6][31:16], 16'(xsi + xdelta)};
                if (uses_di(opx[7:0])) gpr[7] <= a32 ? xdi + xdelta : {gpr[7][31:16], 16'(xdi + xdelta)};
                if (rep != 2'd0) begin
                  gpr[1] <= a32 ? xcnt - 32'd1 : {gpr[1][31:16], 16'(xcnt - 32'd1)};
                  if (xcont && (xcnt - 32'd1) != 32'b0 &&
                      (a32 || (xcnt[15:0] - 16'd1) != 16'b0)) step <= 5'd0;
                  else `C_DONE(next_eip)
                end else `C_DONE(next_eip)
              end
            end

            // MOV r8, imm8 (B0-B7); MOV r, imm (B8-BF)
            9'b0_10110???: begin `C_SETR(opx[2:0], 2'd0, imm1) `C_DONE(next_eip) end
            9'b0_10111???: begin `C_SETR(opx[2:0], osz, imm1) `C_DONE(next_eip) end

            // Shift group 2 (C0, C1, D0-D3)
            9'b0_1100000?, 9'b0_110100??: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else if (step == 5'd1) begin
                xcount = opx[4] ? (opx[1] ? gpr[1][7:0] : 8'd1) : imm1[7:0];
                sh_out = intel_80386_pkg::shift(rg, sz, rm_value(sz), xcount, eflags);
                t1 <= (eflags & ~sh_out[95:64]) | (sh_out[63:32] & sh_out[95:64]);
                if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, sh_out[31:0], 5'd2)
                else begin
                  `SET_RM(sz, sh_out[31:0])
                  eflags <= (eflags & ~sh_out[95:64]) | (sh_out[63:32] & sh_out[95:64]);
                  `C_DONE(next_eip)
                end
              end else begin eflags <= t1; `C_DONE(next_eip) end
            end

            // RET near (C2 imm16, C3)
            9'b0_1100001?: begin
              if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else begin
                xv = o32 ? mdata : {16'b0, mdata[15:0]};
                if (xv > slimit[1]) `C_FAULT(13)
                else begin
                  gpr[4] <= stack_merge(tsp + (opx[0] ? 32'b0 : {16'b0, imm1[15:0]}));
                  `C_DONE(xv)
                end
              end
            end

            // LES (C4), LDS (C5), LSS (0F B2), LFS (0F B4), LGS (0F B5)
            9'b0_1100010?, 9'b1_10110010, 9'b1_1011010?: begin
              xs = opx[8] ? (opx[2] ? (opx[0] ? 3'd5 : 3'd4) : 3'd2) : (opx[0] ? 3'd3 : 3'd0);
              if (!is_mem) `C_UD
              else if (step == 5'd0) `C_DMEM(seg, ea, nbytes, 1'b0, 32'b0, 5'd1)
              else if (step == 5'd1) begin
                t0 <= mdata;
                `C_DMEM(seg, addr_mask(ea + 32'(nbytes)), 3'd2, 1'b0, 32'b0, 5'd2)
              end else begin
                `C_SETR(rg, osz, t0)
                `C_LOADSEG(xs, mdata[15:0])
                `C_DONE(next_eip)
              end
            end

            // MOV r/m, imm (C6 /0, C7 /0)
            9'b0_1100011?: begin
              sz = opx[0] ? osz : 2'd0;
              if (rg != 3'd0) `C_UD
              else if (step == 5'd0) begin
                if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, imm1, 5'd1)
                else begin `SET_RM(sz, imm1) `C_DONE(next_eip) end
              end else `C_DONE(next_eip)
            end

            // ENTER imm16, imm8 (C8)
            9'b0_11001000: begin
              if (step == 5'd0) begin
                count <= imm2[4:0];
                tbp <= gpr[5];
                `C_PUSH(getr(3'd5, osz), nbytes, 5'd1)
              end else if (step == 5'd1) begin
                t0 <= tsp;
                if (count == 5'd0) step <= 5'd4;
                else if (count == 5'd1) step <= 5'd3;
                else step <= 5'd2;
              end else if (step == 5'd2) begin
                xv = stack_merge_bp(tbp - 32'(nbytes));
                tbp <= xv;
                count <= count - 5'd1;
                `C_DMEM(3'd2, stack_off(xv), nbytes, 1'b0, 32'b0, 5'd5)
              end else if (step == 5'd5) begin
                `C_PUSH(mdata, nbytes, (count == 5'd1) ? 5'd3 : 5'd2)
              end else if (step == 5'd3) begin
                `C_PUSH(t0 & intel_80386_pkg::size_mask(osz), nbytes, 5'd4)
              end else begin
                `C_SETR(3'd5, osz, t0)
                gpr[4] <= stack_merge(tsp - {16'b0, imm1[15:0]});
                `C_DONE(next_eip)
              end
            end

            // LEAVE (C9)
            9'b0_11001001: begin
              if (step == 5'd0) begin tsp <= stack_merge(gpr[5]); step <= 5'd1; end
              else if (step == 5'd1) `C_POP(nbytes, 5'd2)
              else begin
                `C_SETR(3'd5, osz, mdata)
                gpr[4] <= tsp;
                `C_DONE(next_eip)
              end
            end

            // RETF (CA imm16, CB)
            9'b0_1100101?: begin
              if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else if (step == 5'd1) begin t0 <= mdata; `C_POP(nbytes, 5'd2) end
              else begin
                xv = o32 ? t0 : {16'b0, t0[15:0]};
                if (xv > slimit[1]) `C_FAULT(13)
                else begin
                  gpr[4] <= stack_merge(tsp + (opx[0] ? 32'b0 : {16'b0, imm1[15:0]}));
                  `C_LOADSEG(3'd1, mdata[15:0])
                  `C_DONE(xv)
                end
              end
            end

            // INT3 (CC), INT imm8 (CD), INTO (CE), ICEBP (F1)
            9'b0_11001100: `C_TRAP(3)
            9'b0_11001101: `C_TRAP(imm1[7:0])
            9'b0_11001110: begin
              if (eflags[intel_80386_pkg::FLAG_OF]) `C_TRAP(4)
              else `C_DONE(next_eip)
            end
            9'b0_11110001: `C_TRAP(1)

            // IRET (CF)
            9'b0_11001111: begin
              if (step == 5'd0) `C_POP(nbytes, 5'd1)
              else if (step == 5'd1) begin t0 <= mdata; `C_POP(nbytes, 5'd2) end
              else if (step == 5'd2) begin t1 <= mdata; `C_POP(nbytes, 5'd3) end
              else begin
                xv = o32 ? t0 : {16'b0, t0[15:0]};
                if (xv > slimit[1]) `C_FAULT(13)
                else begin
                  gpr[4] <= tsp;
                  `C_LOADSEG(3'd1, t1[15:0])
                  eflags <= popped_flags(mdata, o32);
                  `C_DONE(xv)
                end
              end
            end

            // AAM (D4), AAD (D5)
            9'b0_11010100: begin
              if (imm1[7:0] == 8'b0) `C_FAULT(0)
              else if (step == 5'd0) begin
                div_dividend <= {56'b0, gpr[0][7:0]};
                div_divisor <= {24'b0, imm1[7:0]};
                div_start <= 1'b1;
                state <= S_DIV;
              end else begin
                xv = {24'b0, div_remainder[7:0]};
                gpr[0] <= {gpr[0][31:16], div_quotient[7:0], xv[7:0]};
                fl = intel_80386_pkg::result_flags(xv, 2'd0);
                eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, fl);
                `C_DONE(next_eip)
              end
            end
            9'b0_11010101: begin
              xv = {24'b0, 8'(gpr[0][15:8] * imm1[7:0])};
              alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_ADD, 2'd0, {24'b0, gpr[0][7:0]}, xv, 1'b0);
              gpr[0] <= {gpr[0][31:16], 8'b0, alu_out[7:0]};
              eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
              `C_DONE(next_eip)
            end

            // SALC (D6, undocumented): AL = CF ? FFh : 00h
            9'b0_11010110: begin
              gpr[0] <= {gpr[0][31:8], {8{eflags[intel_80386_pkg::FLAG_CF]}}};
              `C_DONE(next_eip)
            end

            // XLAT (D7)
            9'b0_11010111: begin
              if (step == 5'd0)
                `C_DMEM(seg, addr_mask(gpr[3] + {24'b0, gpr[0][7:0]}), 3'd1, 1'b0, 32'b0, 5'd1)
              else begin gpr[0] <= {gpr[0][31:8], mdata[7:0]}; `C_DONE(next_eip) end
            end

            // ESC (D8-DF): no coprocessor is attached.
            // ASSUMPTION: A8. With EM and TS clear the escape completes as a
            // no-op without an operand transfer.
            9'b0_11011???: begin
              if (cr0[2] || cr0[3]) `C_FAULT(7)
              else `C_DONE(next_eip)
            end

            // LOOPNE (E0), LOOPE (E1), LOOP (E2), JCXZ/JECXZ (E3)
            9'b0_111000??: begin
              xcnt = a32 ? gpr[1] : {16'b0, gpr[1][15:0]};
              xv = ip_mask(next_eip + intel_80386_pkg::sign_extend(imm1, 2'd0));
              if (opx[1:0] == 2'd3) begin
                if (xcnt == 32'b0) `C_JUMP(xv)
                else `C_DONE(next_eip)
              end else begin
                xa = addr_mask(xcnt - 32'd1);
                xcont = (xa != 32'b0) && (opx[1] ||
                        (opx[0] ? eflags[intel_80386_pkg::FLAG_ZF] : !eflags[intel_80386_pkg::FLAG_ZF]));
                if (xcont && xv > slimit[1]) `C_FAULT(13)
                else begin
                  gpr[1] <= a32 ? xa : {gpr[1][31:16], xa[15:0]};
                  `C_DONE(xcont ? xv : next_eip)
                end
              end
            end

            // IN AL/eAX, imm8 (E4, E5); IN AL/eAX, DX (EC, ED)
            9'b0_1110010?, 9'b0_1110110?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0)
                `C_MEM(opx[3] ? {16'b0, gpr[2][15:0]} : {24'b0, imm1[7:0]}, `C_SIZE(sz), 1'b0, 32'b0, 1'b1, 5'd1)
              else begin `C_SETR(3'd0, sz, mdata) `C_DONE(next_eip) end
            end

            // OUT imm8, AL/eAX (E6, E7); OUT DX, AL/eAX (EE, EF)
            9'b0_1110011?, 9'b0_1110111?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0)
                `C_MEM(opx[3] ? {16'b0, gpr[2][15:0]} : {24'b0, imm1[7:0]}, `C_SIZE(sz), 1'b1,
                       getr(3'd0, sz), 1'b1, 5'd1)
              else `C_DONE(next_eip)
            end

            // CALL rel16/32 (E8)
            9'b0_11101000: begin
              xv = ip_mask(next_eip + (o32 ? imm1 : intel_80386_pkg::sign_extend(imm1, 2'd1)));
              if (step == 5'd0) begin
                if (xv > slimit[1]) `C_FAULT(13)
                else `C_PUSH(next_eip & intel_80386_pkg::size_mask(osz), nbytes, 5'd1)
              end else begin gpr[4] <= tsp; `C_DONE(xv) end
            end

            // JMP rel16/32 (E9), JMP rel8 (EB)
            9'b0_11101001: `C_JUMP(ip_mask(next_eip + (o32 ? imm1 : intel_80386_pkg::sign_extend(imm1, 2'd1))))
            9'b0_11101011: `C_JUMP(ip_mask(next_eip + intel_80386_pkg::sign_extend(imm1, 2'd0)))

            // JMP ptr16:16/32 (EA)
            9'b0_11101010: begin
              xv = o32 ? imm1 : {16'b0, imm1[15:0]};
              if (xv > slimit[1]) `C_FAULT(13)
              else begin `C_LOADSEG(3'd1, imm2) `C_DONE(xv) end
            end

            // HLT (F4)
            9'b0_11110100: begin
              eip <= next_eip;
              retire_o <= 1'b1;
              state <= S_HALT;
            end

            // CMC CLC STC CLI STI CLD STD (F5, F8-FD)
            9'b0_11110101: begin eflags[0] <= !eflags[0]; `C_DONE(next_eip) end
            9'b0_1111100?: begin eflags[0] <= opx[0]; `C_DONE(next_eip) end
            9'b0_1111101?: begin eflags[9] <= opx[0]; `C_DONE(next_eip) end
            9'b0_1111110?: begin eflags[10] <= opx[0]; `C_DONE(next_eip) end

            // Group 3 (F6, F7): TEST NOT NEG MUL IMUL DIV IDIV
            9'b0_1111011?: begin
              sz = opx[0] ? osz : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else if (step == 5'd1) begin
                xa = rm_value(sz);
                case (rg)
                  3'd0, 3'd1: begin
                    alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_AND, sz, xa, imm1, 1'b0);
                    eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                    `C_DONE(next_eip)
                  end
                  3'd2, 3'd3: begin
                    if (rg == 3'd2) begin
                      xv = ~xa & intel_80386_pkg::size_mask(sz);
                      t1 <= eflags;
                    end else begin
                      alu_out = intel_80386_pkg::alu(intel_80386_pkg::ALU_NEG, sz, xa, 32'b0, 1'b0);
                      xv = alu_out[31:0];
                      t1 <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                    end
                    if (is_mem) `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, xv, 5'd3)
                    else begin
                      `SET_RM(sz, xv)
                      if (rg == 3'd3) eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                      `C_DONE(next_eip)
                    end
                  end
                  3'd4, 3'd5: begin
                    mul_a <= getr(3'd0, sz);
                    mul_b <= xa;
                    mul_sgn <= (rg == 3'd5);
                    mul_sz <= sz;
                    step <= 5'd4;
                  end
                  default: begin
                    // DIV / IDIV: start the iterative divider on magnitudes.

                    case (sz)
                      2'd0: xw = {48'b0, gpr[0][15:0]};
                      2'd1: xw = {32'b0, gpr[2][15:0], gpr[0][15:0]};
                      default: xw = {gpr[2], gpr[0]};
                    endcase
                    xneg_a = (rg == 3'd7) && (sz == 2'd0 ? xw[15] : sz == 2'd1 ? xw[31] : xw[63]);
                    xneg_b = (rg == 3'd7) && intel_80386_pkg::sign_bit(xa, sz);
                    if (xa == 32'b0) `C_FAULT(0)
                    else begin
                      if (xneg_a) begin
                        case (sz)
                          2'd0: xw = {48'b0, 16'(16'd0 - xw[15:0])};
                          2'd1: xw = {32'b0, 32'(32'd0 - xw[31:0])};
                          default: xw = 64'd0 - xw;
                        endcase
                      end
                      div_dividend <= xw;
                      div_divisor <= xneg_b ? ((32'd0 - xa) & intel_80386_pkg::size_mask(sz)) : xa;
                      div_neg_q <= xneg_a ^ xneg_b;
                      div_neg_r <= xneg_a;
                      div_signed <= (rg == 3'd7);
                      div_start <= 1'b1;
                      state <= S_DIV;
                    end
                  end
                endcase
              end else if (step == 5'd4) begin
                    product = mul_p;
                    case (sz)
                      2'd0: begin
                        gpr[0] <= {gpr[0][31:16], product[15:0]};
                        xcont = (rg == 3'd4) ? (product[15:8] != 8'b0)
                                             : (product[15:0] != {{8{product[7]}}, product[7:0]});
                        xv = {24'b0, product[7:0]};
                      end
                      2'd1: begin
                        gpr[0] <= {gpr[0][31:16], product[15:0]};
                        gpr[2] <= {gpr[2][31:16], product[31:16]};
                        xcont = (rg == 3'd4) ? (product[31:16] != 16'b0)
                                             : (product[31:0] != {{16{product[15]}}, product[15:0]});
                        xv = {16'b0, product[15:0]};
                      end
                      default: begin
                        gpr[0] <= product[31:0];
                        gpr[2] <= product[63:32];
                        xcont = (rg == 3'd4) ? (product[63:32] != 32'b0)
                                             : (product != {{32{product[31]}}, product[31:0]});
                        xv = product[31:0];
                      end
                    endcase
                    fl = intel_80386_pkg::result_flags(xv, sz);
                    fl[intel_80386_pkg::FLAG_CF] = xcont;
                    fl[intel_80386_pkg::FLAG_OF] = xcont;
                    eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, fl);
                    `C_DONE(next_eip)
              end else if (step == 5'd2) begin
                // Divider finished: apply the size-specific overflow rule.
                xw = div_quotient;
                xbig = 1'b0;
                if (div_signed) begin
                  case (sz)
                    2'd0: xbig = div_neg_q ? (xw > 64'h80) : (xw > 64'h7F);
                    2'd1: xbig = div_neg_q ? (xw > 64'h8000) : (xw > 64'h7FFF);
                    default: xbig = div_neg_q ? (xw > 64'h8000_0000) : (xw > 64'h7FFF_FFFF);
                  endcase
                end else begin
                  case (sz)
                    2'd0: xbig = xw > 64'hFF;
                    2'd1: xbig = xw > 64'hFFFF;
                    default: xbig = xw > 64'hFFFF_FFFF;
                  endcase
                end
                xa = div_neg_q ? (32'd0 - xw[31:0]) : xw[31:0];
                xb = div_neg_r ? (32'd0 - div_remainder) : div_remainder;
                if (xbig) `C_FAULT(0)
                else begin
                  case (sz)
                    2'd0: gpr[0] <= {gpr[0][31:16], xb[7:0], xa[7:0]};
                    2'd1: begin
                      gpr[0] <= {gpr[0][31:16], xa[15:0]};
                      gpr[2] <= {gpr[2][31:16], xb[15:0]};
                    end
                    default: begin gpr[0] <= xa; gpr[2] <= xb; end
                  endcase
                  `C_DONE(next_eip)
                end
              end else begin
                eflags <= t1;
                `C_DONE(next_eip)
              end
            end

            // Group 4/5 (FE, FF)
            9'b0_1111111?: begin
              sz = opx[0] ? osz : 2'd0;
              if ((!opx[0] && rg > 3'd1) || rg == 3'd7 ||
                  (!is_mem && (rg == 3'd3 || rg == 3'd5))) `C_UD
              else if (step == 5'd0) begin
                if (rg == 3'd3 || rg == 3'd5) `C_DMEM(seg, ea, nbytes, 1'b0, 32'b0, 5'd1)
                else begin `RD_RM(`C_SIZE(sz)) end
              end else if (step == 5'd1) begin
                xa = rm_value(sz);
                case (rg)
                  3'd0, 3'd1: begin
                    alu_out = intel_80386_pkg::alu(rg[0] ? intel_80386_pkg::ALU_DEC : intel_80386_pkg::ALU_INC,
                                                   sz, xa, 32'b0, eflags[intel_80386_pkg::FLAG_CF]);
                    if (is_mem) begin
                      t1 <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                      `C_DMEM(seg, ea, `C_SIZE(sz), 1'b1, alu_out[31:0], 5'd4)
                    end else begin
                      `SET_RM(sz, alu_out[31:0])
                      eflags <= fmerge(intel_80386_pkg::STATUS_FLAGS, alu_out[63:32]);
                      `C_DONE(next_eip)
                    end
                  end
                  3'd2: begin
                    xv = o32 ? xa : {16'b0, xa[15:0]};
                    t0 <= xv;
                    if (xv > slimit[1]) `C_FAULT(13)
                    else `C_PUSH(next_eip & intel_80386_pkg::size_mask(osz), nbytes, 5'd5)
                  end
                  3'd4: `C_JUMP(o32 ? xa : {16'b0, xa[15:0]})
                  3'd6: `C_PUSH(xa, nbytes, 5'd6)
                  default: begin
                    // CALLF / JMPF m16:16/32: read the selector next.
                    t0 <= o32 ? mdata : {16'b0, mdata[15:0]};
                    `C_DMEM(seg, addr_mask(ea + 32'(nbytes)), 3'd2, 1'b0, 32'b0, 5'd2)
                  end
                endcase
              end else if (step == 5'd2) begin
                t1 <= mdata;
                if (t0 > slimit[1]) `C_FAULT(13)
                else if (rg == 3'd5) begin `C_LOADSEG(3'd1, mdata[15:0]) `C_DONE(t0) end
                else `C_PUSH({16'b0, sel[1]}, nbytes, 5'd3)
              end else if (step == 5'd3) begin
                `C_PUSH(next_eip & intel_80386_pkg::size_mask(osz), nbytes, 5'd7)
              end else if (step == 5'd7) begin
                gpr[4] <= tsp;
                `C_LOADSEG(3'd1, t1[15:0])
                `C_DONE(t0)
              end else if (step == 5'd4) begin
                eflags <= t1;
                `C_DONE(next_eip)
              end else if (step == 5'd5) begin
                gpr[4] <= tsp;
                `C_DONE(t0)
              end else begin
                gpr[4] <= tsp;
                `C_DONE(next_eip)
              end
            end

            // 0F 01 group: SGDT SIDT LGDT LIDT SMSW LMSW
            9'b1_00000001: begin
              if ((rg <= 3'd3 && !is_mem) || rg == 3'd5 || rg == 3'd7) `C_UD
              else case (rg)
                3'd0, 3'd1: begin
                  if (step == 5'd0)
                    `C_DMEM(seg, ea, 3'd2, 1'b1, {16'b0, rg[0] ? idt_limit : gdt_limit}, 5'd1)
                  else if (step == 5'd1)
                    // ASSUMPTION: A9. A 16-bit SGDT/SIDT stores the high base
                    // byte as zero.
                    `C_DMEM(seg, addr_mask(ea + 32'd2), 3'd4, 1'b1,
                            (rg[0] ? idt_base : gdt_base) & (o32 ? 32'hFFFF_FFFF : 32'h00FF_FFFF), 5'd2)
                  else `C_DONE(next_eip)
                end
                3'd2, 3'd3: begin
                  if (step == 5'd0) `C_DMEM(seg, ea, 3'd2, 1'b0, 32'b0, 5'd1)
                  else if (step == 5'd1) begin
                    t0 <= mdata;
                    `C_DMEM(seg, addr_mask(ea + 32'd2), 3'd4, 1'b0, 32'b0, 5'd2)
                  end else begin
                    xv = o32 ? mdata : {8'b0, mdata[23:0]};
                    if (rg[0]) begin idt_limit <= t0[15:0]; idt_base <= xv; end
                    else begin gdt_limit <= t0[15:0]; gdt_base <= xv; end
                    `C_DONE(next_eip)
                  end
                end
                3'd4: begin
                  if (step == 5'd0) begin
                    if (is_mem) `C_DMEM(seg, ea, 3'd2, 1'b1, cr0, 5'd1)
                    else begin `SET_RM(osz, cr0) `C_DONE(next_eip) end
                  end else `C_DONE(next_eip)
                end
                default: begin
                  // LMSW loads PE MP EM TS; it cannot clear PE.
                  if (step == 5'd0) begin `RD_RM(3'd2) end
                  else begin
                    xv = rm_value(2'd1);
                    cr0[3:0] <= xv[3:0] | {3'b0, cr0[0]};
                    `C_DONE(next_eip)
                  end
                end
              endcase
            end

            // CLTS (0F 06)
            9'b1_00000110: begin cr0[3] <= 1'b0; `C_DONE(next_eip) end

            // MOV r32, CRn / CRn, r32 / r32, DRn / DRn, r32 (0F 20-23)
            9'b1_001000??: begin
              if (opx[0] == 1'b0) begin
                case ({opx[1], rg})
                  4'b0_000: gpr[rm] <= cr0;
                  4'b0_010: gpr[rm] <= cr2;
                  4'b0_011: gpr[rm] <= cr3;
                  4'b1_110: gpr[rm] <= dr6;
                  4'b1_111: gpr[rm] <= dr7;
                  default: gpr[rm] <= 32'b0;
                endcase
                `C_DONE(next_eip)
              end else begin
                case ({opx[1], rg})
                  4'b0_000: cr0 <= gpr[rm];
                  4'b0_010: cr2 <= gpr[rm];
                  4'b0_011: cr3 <= gpr[rm];
                  4'b1_110: dr6 <= gpr[rm];
                  4'b1_111: dr7 <= gpr[rm];
                  default: ;
                endcase
                `C_DONE(next_eip)
              end
            end

            // SETcc r/m8 (0F 90-9F)
            9'b1_1001????: begin
              xv = {31'b0, intel_80386_pkg::condition(opx[3:0], eflags)};
              if (step == 5'd0) begin
                if (is_mem) `C_DMEM(seg, ea, 3'd1, 1'b1, xv, 5'd1)
                else begin `SET_RM(2'd0, xv) `C_DONE(next_eip) end
              end else `C_DONE(next_eip)
            end

            // BT/BTS/BTR/BTC r/m, r (0F A3 AB B3 BB) and r/m, imm8 (0F BA /4-7)
            9'b1_10100011, 9'b1_10101011, 9'b1_10110011, 9'b1_10111011, 9'b1_10111010: begin
              xbit = (opx[7:0] == 8'hBA) ? imm1 : getr(rg, osz);
              xop = (opx[7:0] == 8'hBA) ? rg[1:0] : opx[4:3];
              if (opx[7:0] == 8'hBA && !rg[2]) `C_UD
              else if (step == 5'd0) begin
                if (is_mem) begin
                  xv = ea;
                  if (opx[7:0] != 8'hBA)
                    xv = addr_mask(ea + (o32 ? {xbit[31] ? 3'b111 : 3'b000, xbit[31:5], 2'b00}
                                             : {{16{xbit[15]}}, xbit[15] ? 3'b111 : 3'b000, xbit[15:4], 1'b0}));
                  t2 <= xv;
                  `C_DMEM(seg, xv, nbytes, 1'b0, 32'b0, 5'd1)
                end else step <= 5'd1;
              end else if (step == 5'd1) begin
                xa = rm_value(osz);
                xb = 32'd1 << (o32 ? xbit[4:0] : {1'b0, xbit[3:0]});
                fl = eflags;
                fl[intel_80386_pkg::FLAG_CF] = (xa & xb) != 32'b0;
                case (xop)
                  2'd1: xv = xa | xb;
                  2'd2: xv = xa & ~xb;
                  2'd3: xv = xa ^ xb;
                  default: xv = xa;
                endcase
                if (xop == 2'd0) begin eflags <= fl; `C_DONE(next_eip) end
                else if (is_mem) begin t1 <= fl; `C_DMEM(seg, t2, nbytes, 1'b1, xv, 5'd2) end
                else begin `SET_RM(osz, xv) eflags <= fl; `C_DONE(next_eip) end
              end else begin eflags <= t1; `C_DONE(next_eip) end
            end

            // SHLD (0F A4 imm8, A5 CL), SHRD (0F AC imm8, AD CL)
            9'b1_1010?10?: begin
              if (step == 5'd0) begin `RD_RM(nbytes) end
              else if (step == 5'd1) begin
                xcount = opx[0] ? gpr[1][7:0] : imm1[7:0];
                sh_out = intel_80386_pkg::double_shift(!opx[3], osz, rm_value(osz), getr(rg, osz),
                                                       xcount, eflags);
                t1 <= (eflags & ~sh_out[95:64]) | (sh_out[63:32] & sh_out[95:64]);
                if (is_mem) `C_DMEM(seg, ea, nbytes, 1'b1, sh_out[31:0], 5'd2)
                else begin
                  `SET_RM(osz, sh_out[31:0])
                  eflags <= (eflags & ~sh_out[95:64]) | (sh_out[63:32] & sh_out[95:64]);
                  `C_DONE(next_eip)
                end
              end else begin eflags <= t1; `C_DONE(next_eip) end
            end

            // MOVZX (0F B6, B7), MOVSX (0F BE, BF)
            9'b1_1011?11?: begin
              sz = opx[0] ? 2'd1 : 2'd0;
              if (step == 5'd0) begin `RD_RM(`C_SIZE(sz)) end
              else begin
                xv = opx[3] ? intel_80386_pkg::sign_extend(rm_value(sz), sz) : rm_value(sz);
                `C_SETR(rg, osz, xv)
                `C_DONE(next_eip)
              end
            end

            // BSF (0F BC), BSR (0F BD)
            9'b1_1011110?: begin
              if (step == 5'd0) begin `RD_RM(nbytes) end
              else begin
                xa = rm_value(osz);
                fl = eflags;
                fl[intel_80386_pkg::FLAG_ZF] = (xa == 32'b0);
                if (xa != 32'b0) begin
                  xv = 32'b0;
                  for (lk = 31; lk >= 0; lk = lk - 1)
                    if (!opx[0] && xa[lk]) xv = 32'(lk);
                  for (lk = 0; lk < 32; lk = lk + 1)
                    if (opx[0] && xa[lk]) xv = 32'(lk);
                  `C_SETR(rg, osz, xv)
                end
                eflags <= fl;
                `C_DONE(next_eip)
              end
            end

            // Decimal adjust: DAA (27), DAS (2F), AAA (37), AAS (3F)
            9'b0_00100111, 9'b0_00101111, 9'b0_00110111, 9'b0_00111111: begin
              fl = eflags;
              xa = {24'b0, gpr[0][7:0]};
              xcont = (xa[3:0] > 4'd9) || eflags[intel_80386_pkg::FLAG_AF];
              case (opx[4:3])
                2'b00: begin // DAA
                  xv = xa;
                  fl[intel_80386_pkg::FLAG_CF] = 1'b0;
                  if (xcont) begin
                    xv = xa + 32'd6;
                    fl[intel_80386_pkg::FLAG_CF] = eflags[intel_80386_pkg::FLAG_CF] | xv[8];
                    fl[intel_80386_pkg::FLAG_AF] = 1'b1;
                  end else fl[intel_80386_pkg::FLAG_AF] = 1'b0;
                  if (xa > 32'h99 || eflags[intel_80386_pkg::FLAG_CF]) begin
                    xv = xv + 32'h60;
                    fl[intel_80386_pkg::FLAG_CF] = 1'b1;
                  end else fl[intel_80386_pkg::FLAG_CF] = 1'b0;
                  fl = (fl & ~32'h0000_00C4) | intel_80386_pkg::result_flags(xv & 32'hFF, 2'd0);
                  gpr[0] <= {gpr[0][31:8], xv[7:0]};
                end
                2'b01: begin // DAS
                  xv = xa;
                  if (xcont) begin
                    xv = xa - 32'd6;
                    fl[intel_80386_pkg::FLAG_CF] = eflags[intel_80386_pkg::FLAG_CF] | xv[8];
                    fl[intel_80386_pkg::FLAG_AF] = 1'b1;
                  end else fl[intel_80386_pkg::FLAG_AF] = 1'b0;
                  if (xa > 32'h99 || eflags[intel_80386_pkg::FLAG_CF]) begin
                    xv = xv - 32'h60;
                    fl[intel_80386_pkg::FLAG_CF] = 1'b1;
                  end
                  fl = (fl & ~32'h0000_00C4) | intel_80386_pkg::result_flags(xv & 32'hFF, 2'd0);
                  gpr[0] <= {gpr[0][31:8], xv[7:0]};
                end
                default: begin // AAA / AAS
                  xv = {16'b0, gpr[0][15:0]};
                  if (xcont) begin
                    xv = opx[3] ? xv - 32'h0106 : xv + 32'h0106;
                    fl[intel_80386_pkg::FLAG_AF] = 1'b1;
                    fl[intel_80386_pkg::FLAG_CF] = 1'b1;
                  end else begin
                    fl[intel_80386_pkg::FLAG_AF] = 1'b0;
                    fl[intel_80386_pkg::FLAG_CF] = 1'b0;
                  end
                  fl = (fl & ~32'h0000_00C4) | intel_80386_pkg::result_flags(xv & 32'h0F, 2'd0);
                  gpr[0] <= {gpr[0][31:16], xv[15:8], 4'b0, xv[3:0]};
                end
              endcase
              eflags <= fl;
              `C_DONE(next_eip)
            end

            default: `C_UD
          endcase
          end
        end

        default: state <= S_SHUTDOWN;
      endcase
    end
  end

  /* verilator lint_on BLKSEQ */

  // LOCK is accepted only on the read-modify-write forms that the 386
  // manual lists, with a memory destination; anything else raises #UD.
  // ASSUMPTION: A10. A register destination under LOCK raises #UD.
  function automatic logic lockable();
    logic ok;
    casez (opx)
      9'b0_00???00?: ok = (opx[5:3] != 3'd7);
      9'b0_100000??: ok = (rg != 3'd7);
      9'b0_1000011?: ok = 1'b1;
      9'b0_1111011?: ok = (rg == 3'd2 || rg == 3'd3);
      9'b0_1111111?: ok = (rg == 3'd0 || rg == 3'd1);
      9'b1_10101011, 9'b1_10110011, 9'b1_10111011: ok = 1'b1;
      9'b1_10111010: ok = (rg >= 3'd5);
      default: ok = 1'b0;
    endcase
    lockable = ok && is_mem;
  endfunction

  function automatic logic [31:0] ip_mask(input logic [31:0] v);
    ip_mask = o32 ? v : {16'b0, v[15:0]};
  endfunction

  function automatic logic [31:0] stack_merge_bp(input logic [31:0] v);
    stack_merge_bp = sbig[2] ? v : {gpr[5][31:16], v[15:0]};
  endfunction

  // FLAGS image loaded by POPF/IRET in real-address mode: IOPL and NT are
  // writable; bit 1 reads as one, bits 3, 5 and 15 as zero; a 32-bit pop
  // keeps VM and loads RF.
  function automatic logic [31:0] popped_flags(input logic [31:0] v, input logic wide);
    if (wide) popped_flags = (v & 32'h0001_7FD5) | (eflags & 32'hFFFE_0000 & ~32'h0001_0000) | 32'h2;
    else popped_flags = {eflags[31:16], (v[15:0] & 16'h7FD5) | 16'h0002};
  endfunction

  /* verilator lint_off UNUSEDSIGNAL */
  function automatic logic uses_si(input logic [7:0] op);
    uses_si = (op[7:2] == 6'b101001) || (op[7:1] == 7'b1010110) || (op[7:1] == 7'b0110111);
  endfunction

  function automatic logic uses_di(input logic [7:0] op);
    uses_di = (op[7:2] == 6'b101001) || (op[7:1] == 7'b1010101) || (op[7:1] == 7'b1010111) ||
              (op[7:1] == 7'b0110110);
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */
endmodule
