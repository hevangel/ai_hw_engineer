// PDP-8 CPU built from three Am2901 bit slices and an Am2910 sequencer.
//
// Datapath
//   Three 4-bit Am2901 slices form the 12-bit accumulator (R0) and scratch
//   registers.  PC, MA, MB, IR, the link flip-flop and the switch register are
//   external 12-bit registers, as on the original machine.  The slice Y bus is
//   the 12-bit internal data bus: it drives the memory write data, MA, PC and
//   the console output latch.
//
// Timing
//   The Am2901 model latches its register-file read ports while CP is high and
//   writes the file while CP is low, matching the two-phase device.  One
//   microinstruction therefore occupies one clock: the microinstruction is
//   presented at the rising edge, the slice read latches close and the file,
//   the link and the external registers commit at the falling edge.  The
//   sequencer advances at the rising edge, so the ROM address is stable for
//   the whole cycle.
//
//   Microinstruction fields are documented in scripts/gen_microcode.py.
`timescale 1ns/1ps
module pdp8_cpu (
    input  logic        clk_i,
    input  logic        rst_n_i,
    // front panel
    input  logic [11:0] sw_i,
    input  logic        pc_we_i,
    input  logic [11:0] pc_in_i,
    input  logic        master_clear_i,
    input  logic        run_set_i,
    input  logic        stop_i,
    input  logic        step_i,
    // core memory
    output logic [11:0] mem_addr_o,
    output logic [11:0] mem_raddr_o,
    output logic        mem_re_o,
    output logic [11:0] mem_wdata_o,
    output logic        mem_we_o,
    input  logic [11:0] mem_rdata_i,
    // console
    output logic [11:0] ir_o,
    output logic [1:0]  iot_ph_o,
    output logic [11:0] y_o,
    input  logic [11:0] iot_data_i,
    input  logic        iot_clr_ac_i,
    input  logic        iot_data_we_i,
    input  logic        iot_skip_i,
    input  logic        ion_set_i,
    input  logic        iof_set_i,
    input  logic        int_req_i,
    // status
    output logic [11:0] pc_o,
    output logic [11:0] ac_o,
    output logic [11:0] ma_o,
    output logic [11:0] mb_o,
    output logic        l_o,
    output logic        ion_o,
    output logic        run_o,
    output logic        retire_o
);
  localparam logic [3:0] REG_AC = 4'd0;
  localparam logic [3:0] SEQ_JZ = 4'h0;

  // ------------------------------------------------------------ sequencer
  logic [71:0] ucode;
  logic [11:0] mpc;
  logic [1:0]  boot_cnt;
  logic        boot;
  logic        clear_req;
  logic [3:0]  cc_sel;
  logic        cc_pass;
  logic [3:0]  seq;
  logic [11:0] target;

  assign boot = (boot_cnt != 2'b11);
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) boot_cnt <= 2'b00;
    else if (master_clear_i) boot_cnt <= 2'b00;
    else if (!boot) boot_cnt <= 2'b11;
    else boot_cnt <= boot_cnt + 2'd1;
  end

  pdp8_sequencer u_seq (
      .clk_i   (clk_i),
      .boot_i  (boot),
      .seq_i   (seq),
      .target_i(target),
      .cc_n_i  (~cc_pass),
      .mpc_o   (mpc),
      .full_n_o()
  );

  pdp8_ucode u_rom (
      .addr_i (mpc),
      .ucode_o(ucode)
  );

  // ------------------------------------------------------------- decoding
  assign cc_sel  = ucode[3:0];
  assign seq     = boot ? SEQ_JZ : ucode[7:4];
  assign target  = ucode[19:8];
  logic [2:0]  u_alf, u_src, u_dest, u_dsel, u_acmask, u_lmask, u_lop;
  logic [3:0]  u_ra, u_rb;
  logic [1:0]  u_cin, u_rdsel, u_iot_ph;
  logic        u_ma_ld, u_ma_sel, u_pc_ld, u_mb_ld, u_mb_sel, u_ir_ld;
  logic        u_mem_rd, u_mem_wr, u_wrmb, u_halt, u_ion, u_iof;
  logic        u_retire, u_pg_ld, u_sh_ir, u_clr_ack;

  assign u_alf    = ucode[22:20];
  assign u_src    = ucode[25:23];
  assign u_ra     = ucode[29:26];
  assign u_rb     = ucode[33:30];
  assign u_dest   = ucode[36:34];
  assign u_dsel   = ucode[39:37];
  assign u_cin    = ucode[41:40];
  assign u_acmask = ucode[44:42];
  assign u_lmask  = ucode[47:45];
  assign u_ma_ld  = ucode[48];
  assign u_ma_sel = ucode[49];
  assign u_pc_ld  = ucode[50];
  assign u_mb_ld  = ucode[51];
  assign u_mb_sel = ucode[52];
  assign u_ir_ld  = ucode[53];
  assign u_mem_rd = ucode[54];
  assign u_rdsel  = ucode[56:55];
  assign u_mem_wr = ucode[57];
  assign u_wrmb   = ucode[58];
  assign u_lop    = ucode[61:59];
  assign u_halt   = ucode[62];
  assign u_ion    = ucode[63];
  assign u_iof    = ucode[64];
  assign u_iot_ph = ucode[66:65];
  assign u_retire = ucode[67];
  assign u_pg_ld  = ucode[68];
  assign u_sh_ir  = ucode[69];
  assign u_clr_ack= ucode[70];

  // ------------------------------------------------------------ registers
  logic [11:0] pc, ma, mb, ir;
  logic [11:7] pg;
  logic        l_ff, l_hold, ion_ff, ion_delay, run_ff, step_ff, step_seen;

  assign pc_o  = pc;
  assign ma_o  = ma;
  assign mb_o  = mb;
  assign ir_o  = ir;

  assign l_o   = l_ff;
  assign ion_o = ion_ff;
  assign run_o = run_ff;

  // Direct page-relative address: current instruction page + 7-bit offset.
  logic [11:0] ea;
  // Page zero unless the instruction sets the page bit (IR<7>).
  assign ea = {(ir[7] ? pg : 5'd0), ir[6:0]};

  // Auto-index applies to page-zero locations 0010-0017 only on a 4K machine.
  logic ai;
  assign ai = ((ea & 12'o7770) == 12'o0010);

  logic cn_in;
  always_comb begin
    case (u_cin)
      2'd0: cn_in = 1'b0;
      2'd1: cn_in = l_hold;
      default: cn_in = 1'b1;
    endcase
  end

  // ------------------------------------------------------- operation gating
  // Operate instructions are microcoded combinations: each micro-operation is
  // enabled only when its instruction bit is present.  mask_value is the gate
  // table indexed by the microinstruction's acquire/link mask field.
  logic [7:0] mask_value;
  assign mask_value[0] = 1'b1;           // always
  assign mask_value[1] = ir[7];          // CLA (0700 group: 0200 bit)
  assign mask_value[2] = ir[6];          // CLL
  assign mask_value[3] = ir[5];          // CMA
  assign mask_value[4] = ir[4];          // CML
  assign mask_value[5] = ir[0];          // IAC
  assign mask_value[6] = ir[3] | ir[2];  // RAR/RAL/RTR/RTL
  assign mask_value[7] = ir[2];          // OSR

  logic ac_en, l_en;
  assign ac_en = mask_value[u_acmask];
  assign l_en  = mask_value[u_lmask];

  logic [2:0]  dest_eff, dsel_eff, src_eff, alf_eff;
  logic [3:0]  ra_eff, rb_eff;

  always_comb begin
    dest_eff = u_dest;
    dsel_eff = u_dsel;
    src_eff  = u_src;
    alf_eff  = u_alf;
    ra_eff   = u_ra;
    rb_eff   = u_rb;

    // OPR group 1 shift direction is selected by the instruction bits.
    if (u_sh_ir) dest_eff = ir[3] ? 3'd4 : 3'd6;

    if (!ac_en) dest_eff = 3'd1;

    // I/O transfer cycle 1: present the accumulator, or clear it for KCC.
    if (u_iot_ph == 2'd1) begin
      dest_eff = 3'd1;
      if (iot_clr_ac_i) begin
        dest_eff = 3'd2;
        dsel_eff = 3'd0;
        src_eff  = 3'd7;
        alf_eff  = 3'd0;
      end
    end
    // I/O transfer cycle 2: or the device byte into the accumulator.
    if (u_iot_ph == 2'd2) begin
      dest_eff = iot_data_we_i ? 3'd2 : 3'd1;
      dsel_eff = 3'd6;
      src_eff  = 3'd5;
      alf_eff  = 3'd3;
      ra_eff   = REG_AC;
      rb_eff   = REG_AC;
    end
  end

  // ------------------------------------------------------------- D bus mux
  logic [11:0] d_bus;
  always_comb begin
    case (dsel_eff)
      3'd0: d_bus = 12'h000;
      3'd1: d_bus = mb;
      3'd2: d_bus = ma;
      3'd3: d_bus = pc;
      3'd4: d_bus = sw_i;
      3'd5: d_bus = 12'h001;
      3'd6: d_bus = iot_data_i;
      default: d_bus = 12'hfff;
    endcase
  end

  // ------------------------------------------------------ Am2901 slices
  logic [3:0] y0, y1, y2;
  logic       cn4_0, cn4_1, cn4_2;
  logic       z0, z1, z2, f3_2;
  logic       ram0_0, ram3_0, ram0_1, ram3_1, ram0_2, ram3_2;
  // The Q register is unused: the PDP-8 accumulator lives in R0 and the
  // 2901 shift destinations carry the link through RAM, not through Q.
  logic [2:0] q0_unused, q3_unused;

  // Right shift: the link enters slice 2 and each slice's LSB feeds the next.
  // Left shift: the link enters slice 0 and each slice's MSB feeds the next.
  logic ram0_i0, ram3_i0, ram0_i1, ram3_i1, ram0_i2, ram3_i2;
  assign ram3_i0 = ram0_1;
  assign ram3_i1 = ram0_2;
  // The slice latches its shift input during the write phase, which starts on
  // the same edge that updates the link.  l_hold carries the link value that
  // was valid at the start of the cycle so the written word cannot change
  // after the edge.
  assign ram3_i2 = l_hold;
  assign ram0_i0 = l_hold;
  assign ram0_i1 = ram3_0;
  assign ram0_i2 = ram3_1;

  assign y_o = {y2, y1, y0};

  amd_am2901 u_slice0 (
      .cp_i(clk_i), .instruction_i({dest_eff, alf_eff, src_eff}),
      .a_i(ra_eff), .b_i(rb_eff), .d_i(d_bus[3:0]), .cn_i(cn_in), .oe_n_i(1'b0),
      .ram0_i(ram0_i0), .ram3_i(ram3_i0), .q0_i(1'b0), .q3_i(1'b0),
      .y_o(y0), .y_oe_o(), .q0_o(q0_unused[0]), .q3_o(q3_unused[0]), .ram0_o(ram0_0), .ram3_o(ram3_0),
      .ram0_oe_o(), .ram3_oe_o(), .q0_oe_o(), .q3_oe_o(),
      .cn4_o(cn4_0), .p_n_o(), .g_n_o(), .ovr_o(), .f3_o(), .zero_o(z0)
  );

  amd_am2901 u_slice1 (
      .cp_i(clk_i), .instruction_i({dest_eff, alf_eff, src_eff}),
      .a_i(ra_eff), .b_i(rb_eff), .d_i(d_bus[7:4]), .cn_i(cn4_0), .oe_n_i(1'b0),
      .ram0_i(ram0_i1), .ram3_i(ram3_i1), .q0_i(1'b0), .q3_i(1'b0),
      .y_o(y1), .y_oe_o(), .q0_o(q0_unused[1]), .q3_o(q3_unused[1]), .ram0_o(ram0_1), .ram3_o(ram3_1),
      .ram0_oe_o(), .ram3_oe_o(), .q0_oe_o(), .q3_oe_o(),
      .cn4_o(cn4_1), .p_n_o(), .g_n_o(), .ovr_o(), .f3_o(), .zero_o(z1)
  );

  amd_am2901 u_slice2 (
      .cp_i(clk_i), .instruction_i({dest_eff, alf_eff, src_eff}),
      .a_i(ra_eff), .b_i(rb_eff), .d_i(d_bus[11:8]), .cn_i(cn4_1), .oe_n_i(1'b0),
      .ram0_i(ram0_i2), .ram3_i(ram3_i2), .q0_i(1'b0), .q3_i(1'b0),
      .y_o(y2), .y_oe_o(), .q0_o(q0_unused[2]), .q3_o(q3_unused[2]), .ram0_o(ram0_2), .ram3_o(ram3_2),
      .ram0_oe_o(), .ram3_oe_o(), .q0_oe_o(), .q3_oe_o(),
      .cn4_o(cn4_2), .p_n_o(), .g_n_o(), .ovr_o(), .f3_o(f3_2), .zero_o(z2)
  );

  logic zero;
  assign zero = z0 & z1 & z2;

  // Shift-out bit for the link: LSB on a right shift, MSB on a left shift.
  logic shift_out;
  assign shift_out = (dest_eff == 3'd4 || dest_eff == 3'd5) ? ram0_0 : ram3_2;

  // -------------------------------------------------------- condition codes
  logic g2_skip;
  assign g2_skip = ir[3] ^ ((ir[4] & l_ff) | (ir[5] & zero) | (ir[6] & f3_2));

  logic irq;
  assign irq = ion_ff & int_req_i & ~ion_delay & run_ff;

  always_comb begin
    case (cc_sel)
      4'd0:  cc_pass = 1'b1;
      4'd1:  cc_pass = ir[11];
      4'd2:  cc_pass = ir[10];
      4'd3:  cc_pass = ir[9];
      4'd4:  cc_pass = ir[8];
      4'd5:  cc_pass = zero;
      4'd6:  cc_pass = l_ff;
      4'd7:  cc_pass = g2_skip;
      4'd8:  cc_pass = irq;
      4'd9:  cc_pass = ir[1];
      4'd10: cc_pass = clear_req;
      4'd11: cc_pass = ir[0];
      4'd12: cc_pass = ir[2];
      4'd13: cc_pass = ai;
      4'd14: cc_pass = iot_skip_i;
      default: cc_pass = run_ff;
    endcase
  end

  // ------------------------------------------------------------ memory bus
  logic [11:0] mem_raddr;
  always_comb begin
    case (u_rdsel)
      2'd0: mem_raddr = y_o;
      2'd1: mem_raddr = ma;
      default: mem_raddr = ea;
    endcase
  end

  assign mem_addr_o  = ma;
  assign mem_raddr_o = mem_raddr;
  assign mem_re_o    = u_mem_rd;
  assign mem_wdata_o = u_wrmb ? mb : y_o;
  assign mem_we_o    = u_mem_wr;
  assign iot_ph_o    = u_iot_ph;
  assign retire_o    = u_retire;

  // ------------------------------------------------------- link and state
  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) l_hold <= 1'b0;
    else l_hold <= l_ff;
  end

  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      l_ff <= 1'b0;
    end else begin
      if (l_en) begin
        case (u_lop)
          3'd1: l_ff <= cn4_2;
          3'd2: l_ff <= l_ff ^ cn4_2;
          3'd3: l_ff <= 1'b0;
          3'd4: l_ff <= 1'b1;
          3'd5: l_ff <= ~l_ff;
          3'd6: l_ff <= shift_out;
          default: l_ff <= l_ff;
        endcase
      end
    end
  end

  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      pc <= 12'd0;
      ma <= 12'd0;
      mb <= 12'd0;
      ir <= 12'd0;
      pg <= 5'd0;
      ac_o <= 12'd0;
      ion_ff <= 1'b0;
      ion_delay <= 1'b0;
    end else begin
      if (pc_we_i) pc <= pc_in_i;
      else if (u_pc_ld) pc <= y_o;
      if (u_pg_ld) pg <= pc[11:7];
      if (u_ma_ld) ma <= u_ma_sel ? ea : y_o;
      if (u_mb_ld) mb <= u_mb_sel ? y_o : mem_rdata_i;
      if (u_ir_ld) ir <= mem_rdata_i;
      // Sample the accumulator on the instruction-boundary cycle.  The
      // 2901 Y bus presents the A latch for destination code 2 and a shifted
      // word for codes 4-7, so Y is only the plain accumulator here, where
      // the microcode selects A as the source with no destination write.
      if (u_retire) ac_o <= y_o;

      // Interrupt enable, with the documented one-instruction ION delay.
      if (u_iof || iof_set_i) ion_ff <= 1'b0;
      else if (u_ion || ion_set_i) ion_ff <= 1'b1;
      if (u_retire) ion_delay <= 1'b0;
      else if (ion_set_i) ion_delay <= 1'b1;
    end
  end

  // --------------------------------------------------- run / halt / stepping
  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      run_ff <= 1'b0;
      step_ff <= 1'b0;
      step_seen <= 1'b0;
      clear_req <= 1'b0;
    end else begin
      if (master_clear_i) begin
        clear_req <= 1'b1;
        run_ff <= 1'b0;
        step_ff <= 1'b0;
        step_seen <= 1'b0;
      end else begin
        if (u_clr_ack) clear_req <= 1'b0;
        if (run_set_i) begin
          run_ff <= 1'b1;
          step_seen <= 1'b0;
        end
        if (stop_i) begin
          run_ff <= 1'b0;
          step_ff <= 1'b0;
        end
        if (step_i) begin
          run_ff <= 1'b1;
          step_ff <= 1'b1;
          step_seen <= 1'b0;
        end
        if (u_halt && ir[1]) begin
          run_ff <= 1'b0;
        end
        if (u_retire) begin
          if (step_ff && step_seen) begin
            run_ff <= 1'b0;
            step_ff <= 1'b0;
          end else if (step_ff) begin
            step_seen <= 1'b1;
          end
        end
      end
    end
  end

`ifdef FORMAL
  // Every architectural write to the accumulator must match the mirror.
  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) f_past_valid <= 1'b1;
`endif
endmodule
