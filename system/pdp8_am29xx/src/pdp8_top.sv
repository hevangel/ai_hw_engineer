// PDP-8 (1965) reconstruction: CPU, 4K core, console and front panel.
`timescale 1ns/1ps
module pdp8_top (
    input  logic        clk_i,
    input  logic        rst_n_i,
    // front panel
    input  logic [11:0] sw_i,
    input  logic        key_load_addr_i,
    input  logic        key_examine_i,
    input  logic        key_deposit_i,
    input  logic        key_start_i,
    input  logic        key_stop_i,
    input  logic        key_cont_i,
    input  logic        key_step_i,
    // lamps
    output logic [11:0] lamp_pc_o,
    output logic [11:0] lamp_ac_o,
    output logic [11:0] lamp_ma_o,
    output logic [11:0] lamp_mb_o,
    output logic [11:0] lamp_display_o,
    output logic        lamp_l_o,
    output logic        lamp_ion_o,
    output logic        lamp_run_o,
    // console
    input  logic [7:0]  kb_data_i,
    input  logic        kb_valid_i,
    output logic        kb_ready_o,
    output logic        kb_take_o,
    output logic [7:0]  tty_data_o,
    output logic        tty_valid_o,
    input  logic [7:0]  ptr_data_i,
    input  logic        ptr_valid_i,
    output logic        ptr_take_o,
    output logic [7:0]  ptp_data_o,
    output logic        ptp_valid_o,
    // program load port (debug/bootstrap, not present on the original machine)
    input  logic        load_we_i,
    input  logic [11:0] load_addr_i,
    input  logic [11:0] load_data_i,
    // trace
    output logic [11:0] dbg_pc_o,
    output logic [11:0] dbg_ac_o,
    output logic        dbg_l_o,
    output logic        dbg_retire_o
);
  logic [11:0] cpu_raddr, cpu_waddr, cpu_wdata;
  logic        cpu_re, cpu_we;
  logic [11:0] mem_raddr, mem_waddr, mem_wdata;
  logic        mem_re, mem_we;
  logic [11:0] mem_rdata;

  logic [11:0] pc, ac, ma, mb, ir, y;
  logic        l, ion, run, retire;
  logic [1:0]  iot_ph;
  logic [11:0] iot_data;
  logic        iot_clr_ac, iot_data_we, iot_skip, ion_set, iof_set, int_req;

  logic        pc_we, master_clear, run_set, stop, step;
  logic [11:0] pc_out;
  logic [11:0] examine_addr, deposit_addr, deposit_data;
  logic        examine_re, deposit_we;
  logic [11:0] panel_display;

  pdp8_cpu u_cpu (
      .clk_i          (clk_i),
      .rst_n_i        (rst_n_i),
      .sw_i           (sw_i),
      .pc_we_i        (pc_we),
      .pc_in_i        (pc_out),
      .master_clear_i (master_clear),
      .run_set_i      (run_set),
      .stop_i         (stop),
      .step_i         (step),
      .mem_addr_o     (cpu_waddr),
      .mem_raddr_o    (cpu_raddr),
      .mem_re_o       (cpu_re),
      .mem_wdata_o    (cpu_wdata),
      .mem_we_o       (cpu_we),
      .mem_rdata_i    (mem_rdata),
      .ir_o           (ir),
      .iot_ph_o       (iot_ph),
      .y_o            (y),
      .iot_data_i     (iot_data),
      .iot_clr_ac_i   (iot_clr_ac),
      .iot_data_we_i  (iot_data_we),
      .iot_skip_i     (iot_skip),
      .ion_set_i      (ion_set),
      .iof_set_i      (iof_set),
      .int_req_i      (int_req),
      .pc_o           (pc),
      .ac_o           (ac),
      .ma_o           (ma),
      .mb_o           (mb),
      .l_o            (l),
      .ion_o          (ion),
      .run_o          (run),
      .retire_o       (retire)
  );

  pdp8_console u_console (
      .clk_i          (clk_i),
      .rst_n_i        (rst_n_i),
      .ir_i           (ir),
      .iot_ph_i       (iot_ph),
      .y_i            (y),
      .iot_data_o     (iot_data),
      .iot_clr_ac_o   (iot_clr_ac),
      .iot_data_we_o  (iot_data_we),
      .iot_skip_o     (iot_skip),
      .ion_set_o      (ion_set),
      .iof_set_o      (iof_set),
      .int_req_o      (int_req),
      .kb_data_i      (kb_data_i),
      .kb_valid_i     (kb_valid_i),
      .kb_ready_o     (kb_ready_o),
      .kb_take_o      (kb_take_o),
      .tty_data_o     (tty_data_o),
      .tty_valid_o    (tty_valid_o),
      .ptr_data_i     (ptr_data_i),
      .ptr_valid_i    (ptr_valid_i),
      .ptr_take_o     (ptr_take_o),
      .ptp_data_o     (ptp_data_o),
      .ptp_valid_o    (ptp_valid_o)
  );

  pdp8_panel u_panel (
      .clk_i           (clk_i),
      .rst_n_i         (rst_n_i),
      .sw_i            (sw_i),
      .key_load_addr_i (key_load_addr_i),
      .key_examine_i   (key_examine_i),
      .key_deposit_i   (key_deposit_i),
      .key_start_i     (key_start_i),
      .key_stop_i      (key_stop_i),
      .key_cont_i      (key_cont_i),
      .key_step_i      (key_step_i),
      .pc_i            (pc),
      .mem_rdata_i     (mem_rdata),
      .pc_we_o         (pc_we),
      .pc_out_o        (pc_out),
      .master_clear_o  (master_clear),
      .run_set_o       (run_set),
      .stop_o          (stop),
      .step_o          (step),
      .examine_addr_o  (examine_addr),
      .examine_re_o    (examine_re),
      .deposit_addr_o  (deposit_addr),
      .deposit_data_o  (deposit_data),
      .deposit_we_o    (deposit_we),
      .display_o       (panel_display),
      .display_valid_o ()
  );

  assign lamp_display_o = panel_display;

  // Panel accesses win only while the processor is stopped (it asserts no
  // memory requests in the halt loop).
  assign mem_raddr = examine_re ? examine_addr : cpu_raddr;
  assign mem_re    = examine_re | cpu_re;
  assign mem_waddr = deposit_we ? deposit_addr : cpu_waddr;
  assign mem_wdata = deposit_we ? deposit_data : cpu_wdata;
  assign mem_we    = deposit_we | cpu_we;

  pdp8_core u_core (
      .clk_i       (clk_i),
      .raddr_i     (mem_raddr),
      .re_i        (mem_re),
      .waddr_i     (mem_waddr),
      .we_i        (mem_we),
      .wdata_i     (mem_wdata),
      .init_we_i   (load_we_i),
      .init_addr_i (load_addr_i),
      .init_data_i (load_data_i),
      .rdata_o     (mem_rdata)
  );

  assign lamp_pc_o = pc;
  assign lamp_ac_o = ac;
  assign lamp_ma_o = ma;
  assign lamp_mb_o = mb;
  assign lamp_l_o  = l;
  assign lamp_ion_o = ion;
  assign lamp_run_o = run;

  assign dbg_pc_o     = pc;
  assign dbg_ac_o     = ac;
  assign dbg_l_o      = l;
  assign dbg_retire_o = retire;
endmodule
