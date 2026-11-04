`timescale 1ns/1ps
// DEC PDP-1 reconstructed from five Am2901 slices and one Am2910, with the
// 1961 instruction set, 4096-word core memory, console and standard I/O.
// See spec/spec.md for the sourced contract and the assumption ledger.
`ifndef PDP1_AM29XX_SV
`define PDP1_AM29XX_SV

module pdp1_am29xx (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [17:0] tw_i,
    input  logic [5:0]  ss_i,
    input  logic        resume_i,
    // Paper tape and keyboard queues from the host bridge.
    input  logic        tape_valid_i,
    input  logic [17:0] tape_data_i,
    output logic        tape_pop_o,
    input  logic        kbd_valid_i,
    input  logic [17:0] kbd_data_i,
    output logic        kbd_pop_o,
    // Device outputs.
    output logic [17:0] tty_data_o,
    output logic        tty_stb_o,
    output logic [17:0] punch_data_o,
    output logic        punch_stb_o,
    output logic [9:0]  dpy_x_o,
    output logic [9:0]  dpy_y_o,
    output logic [2:0]  dpy_int_o,
    output logic        dpy_stb_o,
    // Sequence-break request from a device model (display frame).
    input  logic        sbs_req_i,
    // Architectural state for the panel and the oracle trace.
    output logic [11:0] pc_o,
    output logic [17:0] ac_o,
    output logic [17:0] io_o,
    output logic [17:0] ir_o,
    output logic [17:0] mb_o,
    output logic [11:0] ma_o,
    output logic        ov_o,
    output logic        halted_o,
    output logic        illegal_o,
    output logic        sbs_enb_o,
    output logic        sbs_pending_o,
    output logic [5:0]  flag_o,
    output logic [31:0] microcycles_o,
    output logic [31:0] core_cycles_o,
    output logic [11:0] microaddr_o,
    output logic [17:0] dbg_d_o,
    output logic [19:0] dbg_y_o,
    output logic [32:0] dbg_uc_o,
    // Instruction-start trace (state before execution).
    output logic        trace_o,
    output logic [11:0] trace_pc_o,
    output logic [17:0] trace_ir_o,
    output logic [17:0] trace_ac_o,
    output logic [17:0] trace_io_o,
    output logic        trace_ov_o,
    output logic [5:0]  trace_pf_o,
    output logic [31:0] trace_micro_o,
    // Host memory loader port.
    input  logic [11:0] host_addr_i,
    input  logic [17:0] host_wdata_i,
    input  logic        host_we_i,
    output logic [17:0] host_rdata_o
);

  `include "pdp1_defs.svh"

  pdp1_uc_pkg::pdp1_uc_t uc, uc_rom;
  logic [99:0] uc_dbg;

  logic [11:0] pc_q, ma_q, micro_addr;
  logic [17:0] ir_q, mb_q, mem_rdata;
  logic        ov_q, halted_q, illegal_q;
  logic [3:0]  nfc_q;
  logic [31:0] microcycles_q, core_cycles_q;
  logic        trace_q;
  logic [11:0] trace_pc_q;
  logic [17:0] trace_ir_q, trace_ac_q, trace_io_q;
  logic        trace_ov_q;
  logic [5:0]  trace_pf_q;
  logic [31:0] trace_micro_q;

  logic [19:0] y_bus, ac_mirror, io_mirror;
  logic [17:0] shf_value, d_eff;
  logic        alu_zero, ov_next, cond;
  logic [5:0]  flag_q;
  logic [5:0]  flag_set, flag_clr;
  logic [17:0] devdata;
  logic        io_ready;
  logic        skip_cond, skip_true;
  logic        mr_indirect;
  logic [3:0]  nfc_next;
  logic [5:0]  flag_mask;
  logic [2:0]  flag_sel_eff;

  // ---------------------------------------------------------------- memory
  logic cpu_we;
  assign cpu_we = (uc.mem_op == MEM_WRITE);

  pdp1_memory memory (
      .clk_i(clk_i),
      .cpu_addr_i(ma_q),
      .cpu_wdata_i(y_bus[17:0]),
      .cpu_we_i(cpu_we),
      .cpu_rdata_o(mem_rdata),
      .host_addr_i(host_addr_i),
      .host_wdata_i(host_wdata_i),
      .host_we_i(host_we_i),
      .host_rdata_o(host_rdata_o)
  );

  // ------------------------------------------------------------- datapath
  pdp1_datapath datapath (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .uc_i(uc),
      .ir_i(ir_q),
      .mb_i(mb_q),
      .mem_i(mem_rdata),
      .pc_i(pc_q),
      .ma_i(ma_q),
      .tw_i(tw_i),
      .ss_i(ss_i),
      .status_i(18'd0),
      .devdata_i(devdata),
      .y_o(y_bus),
      .shf_o(shf_value),
      .d_o(d_eff),
      .alu_zero_o(alu_zero),
      .ov_next_o(ov_next),
      .ac_o(ac_mirror),
      .io_o(io_mirror)
  );

  // ---------------------------------------------------------------- console
  pdp1_io console (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .tw_i(tw_i),
      .ss_i(ss_i),
      .dev_strobe_i(uc.io_strobe),
      .dev_i(ir_q[5:0]),
      .pulse_i(ir_q[11:6]),
      .io_i(io_mirror[17:0]),
      .ac_i(ac_mirror[17:0]),
      .devdata_o(devdata),
      .kbd_valid_i(kbd_valid_i),
      .kbd_data_i(kbd_data_i),
      .kbd_pop_o(kbd_pop_o),
      .tape_valid_i(tape_valid_i),
      .tape_data_i(tape_data_i),
      .tape_pop_o(tape_pop_o),
      .tty_data_o(tty_data_o),
      .tty_stb_o(tty_stb_o),
      .punch_data_o(punch_data_o),
      .punch_stb_o(punch_stb_o),
      .dpy_x_o(dpy_x_o),
      .dpy_y_o(dpy_y_o),
      .dpy_int_o(dpy_int_o),
      .dpy_stb_o(dpy_stb_o),
      .flag_set_i(flag_set),
      .flag_clr_i(flag_clr),
      .flag_o(flag_q),
      .sbs_set_i(uc.flag_we && 1'b0),
      .sbs_clr_i(1'b0),
      .sbs_enb_o(sbs_enb_o),
      .sbs_req_i(sbs_req_i),
      .sbs_pending_o(sbs_pending_o),
      .sbs_ack_i(uc.sbs_vec),
      .status_o()
  );

  // ------------------------------------------------------------ sequencer
  pdp1_microseq sequencer (
      .clk_i(clk_i),
      .rst_n_i(rst_n_i),
      .uc_i(uc),
      .cond_i(cond),
      .opcode_i(ir_q[17:13]),
      .device_i(ir_q[5:0]),
      .sft_i(ir_q[12:9]),
      .uc_o(uc_rom),
      .addr_o(micro_addr)
  );
  assign microaddr_o = micro_addr;
  assign dbg_d_o = d_eff;
  assign dbg_y_o = y_bus;
  assign dbg_uc_o = {uc.seq, uc.cc, uc.dest, uc.src, uc.fn, uc.d, uc.a, uc.b, uc.cn};

  // Control-word pipeline register (the microcode pipeline stage).
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    // Reset drives the documented power-up word (JZ) and the sequencer then
    // jumps to microaddress 0 for the reset sequence.
    if (!rst_n_i) uc <= '0;
    else uc <= uc_rom;
  end

  // Bit 5 (IR[12]) is the indirect bit only for memory-reference opcodes.
  // For the skip group it inverts the test, for shifts it is the direction,
  // for LAW it selects the complement, and for IOT it is the wait bit.
  always_comb begin
    unique case (ir_q[17:13])
      // Opcode 7 is CAL when bit 5 is clear and JDA when it is set; that bit
      // is not an indirect request, so it is resolved in the handler instead.
      OP_AND, OP_IOR, OP_XOR, OP_XCT, OP_LAC, OP_LIO, OP_DAC,
      OP_DAP, OP_DIP, OP_DIO, OP_DZM, OP_ADD, OP_SUB, OP_IDX, OP_ISP,
      OP_SAD, OP_SAS, OP_MUS, OP_DIS, OP_JMP, OP_JSP:
        mr_indirect = ir_q[12];
      default: mr_indirect = 1'b0;
    endcase
  end

  // ------------------------------------------------------------- conditions
  always_comb begin
    cond = 1'b0;
    unique case (uc.cc)
      CC_FALSE:      cond = 1'b0;
      CC_TRUE:       cond = 1'b1;
      CC_ALWAYS:     cond = 1'b1;
      CC_IR_IND:     cond = mr_indirect;
      CC_AC_ZERO:    cond = (ac_mirror[17:0] == 18'd0);
      CC_AC_SIGN:    cond = ac_mirror[17];
      CC_IO_SIGN:    cond = io_mirror[17];
      CC_IO_LSB:     cond = io_mirror[0];
      CC_IO_ZERO:    cond = (io_mirror[17:0] == 18'd0);
      CC_OV:         cond = ov_q;
      CC_NFC_ZERO:   cond = (nfc_q == 4'd0);
      CC_EAC:        cond = ac_mirror[18];
      CC_IO_READY:   cond = io_ready;
      CC_SBS_REQ:    cond = sbs_pending_o;
      CC_SBS_ACTIVE: cond = sbs_pending_o;
      CC_IR_A7:      cond = ir_q[7];
      CC_IR_A8:      cond = ir_q[8];
      CC_IR_A9:      cond = ir_q[9];
      CC_IR_A10:     cond = ir_q[10];
      CC_IR_A11:     cond = ir_q[11];
      CC_IR_A5:      cond = ir_q[5];
      CC_IR_A3:      cond = ir_q[3];
      CC_IR_A12:     cond = ir_q[12];
      CC_IR_A6:      cond = ir_q[6];
      CC_IR_A2_0:    cond = (ir_q[2:0] != 3'd0);
      CC_IR_A5_3:    cond = (ir_q[5:3] != 3'd0);
      CC_PF_ALL_ZERO: cond = (flag_q == 6'd0);
      CC_SS_ALL_ZERO: cond = (ss_i == 6'd0);
      CC_SKIP_ANY:   cond = skip_true;
      CC_HALTED:     cond = halted_q;
      CC_RESULT_ZERO: cond = alu_zero;
      CC_MEM_IDLE:   cond = 1'b1;
      default:       cond = 1'b0;
    endcase
  end

  // Skip group: address-field conditions ORed together, then inverted by
  // bit 5 (IR[12]); szo clears overflow whenever it is selected.
  always_comb begin
    logic pf_cond, ss_cond;
    logic [2:0] fsel, ssel;
    fsel = ir_q[2:0];
    ssel = ir_q[5:3];
    pf_cond = 1'b0;
    if (fsel != 3'd0) begin
      if (fsel == 3'd7) pf_cond = (flag_q == 6'd0);
      else pf_cond = ~flag_q[fsel - 3'd1];
    end
    ss_cond = 1'b0;
    if (ssel != 3'd0) begin
      if (ssel == 3'd7) ss_cond = (ss_i == 6'd0);
      else ss_cond = ~ss_i[ssel - 3'd1];
    end
    skip_cond = (ir_q[6] && (ac_mirror[17:0] == 18'd0)) ||
                (ir_q[7] && !ac_mirror[17]) ||
                (ir_q[8] && ac_mirror[17]) ||
                (ir_q[9] && !ov_q) ||
                (ir_q[10] && !io_mirror[17]) ||
                pf_cond || ss_cond;
    skip_true = skip_cond ^ ir_q[12];
  end

  // I/O readiness: input devices hold the machine in its wait loop until the
  // host bridge supplies a character or tape word.
  always_comb begin
    unique case (ir_q[5:0])
      6'o01, 6'o02, 6'o30: io_ready = tape_valid_i;
      6'o04: io_ready = kbd_valid_i;
      default: io_ready = 1'b1;
    endcase
  end

  // Program-flag set/clear masks (operate group).
  assign flag_sel_eff = uc.flag_dyn ? ir_q[2:0] : uc.flag_sel;

  always_comb begin
    flag_mask = 6'd0;
    if (flag_sel_eff != 3'd0) begin
      for (int i = 0; i < 6; i++) begin
        if (flag_sel_eff == 3'd7 || flag_sel_eff == 3'(i + 1)) flag_mask[i] = 1'b1;
      end
    end
    flag_set = (uc.flag_we && uc.flag_set) ? flag_mask : 6'd0;
    flag_clr = (uc.flag_we && !uc.flag_set) ? flag_mask : 6'd0;
  end

  // Shift count = number of ONE bits in IR<8:0>.
  always_comb begin
    nfc_next = 4'd0;
    for (int i = 0; i < 9; i++) nfc_next = nfc_next + 4'(ir_q[i]);
  end

  // ------------------------------------------------------------- registers
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      pc_q <= 12'd0;
      ma_q <= 12'd0;
      ir_q <= 18'd0;
      mb_q <= 18'd0;
      ov_q <= 1'b0;
      halted_q <= 1'b0;
      illegal_q <= 1'b0;
      nfc_q <= 4'd0;
      microcycles_q <= 32'd0;
      core_cycles_q <= 32'd0;
      trace_q <= 1'b0;
      trace_pc_q <= 12'd0;
      trace_ir_q <= 18'd0;
      trace_ac_q <= 18'd0;
      trace_io_q <= 18'd0;
      trace_ov_q <= 1'b0;
      trace_pf_q <= 6'd0;
      trace_micro_q <= 32'd0;
    end else begin
      microcycles_q <= microcycles_q + 32'd1;
      if (uc.core) core_cycles_q <= core_cycles_q + 32'd1;

      if (resume_i) halted_q <= 1'b0;
      if (uc.halt) halted_q <= 1'b1;
      if (uc.illegal) begin
        illegal_q <= 1'b1;
        halted_q <= 1'b1;
      end

      if (uc.pc_load) pc_q <= d_eff[11:0];
      else if (uc.pc_inc || uc.skip) pc_q <= pc_q + 12'd1;

      if (uc.ma_load) ma_q <= d_eff[11:0];
      if (uc.ir_load) ir_q <= mem_rdata;
      // An indirect step replaces only the address field (and carries the
      // indirect bit forward); the opcode belongs to the original word.
      if (uc.ir_ind) ir_q <= {ir_q[17:13], mem_rdata[12:0]};
      if (uc.mb_load) mb_q <= mem_rdata;

      if (uc.ov_clr) ov_q <= 1'b0;
      else if (uc.ov_upd) ov_q <= ov_next;

      if (uc.nfc_load) nfc_q <= nfc_next;
      else if (uc.nfc_dec) nfc_q <= nfc_q - 4'd1;

      trace_q <= uc.trace;
      if (uc.trace) begin
        trace_pc_q <= pc_q - 12'd1;
        trace_ir_q <= ir_q;
        trace_ac_q <= ac_mirror[17:0];
        trace_io_q <= io_mirror[17:0];
        trace_ov_q <= ov_q;
        trace_pf_q <= flag_q;
        trace_micro_q <= microcycles_q;
      end
    end
  end

  assign pc_o = pc_q;
  assign ac_o = ac_mirror[17:0];
  assign io_o = io_mirror[17:0];
  assign ir_o = ir_q;
  assign mb_o = mb_q;
  assign ma_o = ma_q;
  assign ov_o = ov_q;
  assign halted_o = halted_q;
  assign illegal_o = illegal_q;
  assign flag_o = flag_q;
  assign microcycles_o = microcycles_q;
  assign core_cycles_o = core_cycles_q;
  assign trace_o = trace_q;
  assign trace_pc_o = trace_pc_q;
  assign trace_ir_o = trace_ir_q;
  assign trace_ac_o = trace_ac_q;
  assign trace_io_o = trace_io_q;
  assign trace_ov_o = trace_ov_q;
  assign trace_pf_o = trace_pf_q;
  assign trace_micro_o = trace_micro_q;

endmodule

`endif
