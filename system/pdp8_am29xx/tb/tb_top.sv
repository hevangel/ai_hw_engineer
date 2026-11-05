// System testbench for the PDP-8 reconstruction.
//
// Plusargs
//   +prog=<hex>     program image, one 12-bit word per line ($readmemh)
//   +start=<n>      decimal address loaded before START
//   +trace=<path>   per-instruction architectural trace (pc ac l)
//   +tty=<path>     printer output bytes
//   +ptp=<path>     punch output bytes
//   +kb=<path>      keyboard input bytes
//   +ptr=<path>     paper-tape reader input bytes
//   +maxcyc=<n>     watchdog
`timescale 1ns/1ps
module tb_top;
  logic clk = 1'b0;
  logic rst_n = 1'b0;

  logic [11:0] sw;
  logic        key_load_addr, key_examine, key_deposit, key_start;
  logic        key_stop, key_cont, key_step;

  logic [11:0] lamp_pc, lamp_ac, lamp_ma, lamp_mb, lamp_display;
  logic        lamp_l, lamp_ion, lamp_run;

  logic [7:0]  kb_data, tty_data, ptr_data, ptp_data;
  logic        kb_valid, kb_ready, kb_take, tty_valid, ptr_valid, ptr_take, ptp_valid;

  logic        load_we;
  logic [11:0] load_addr, load_data;

  logic [11:0] dbg_pc, dbg_ac;
  logic        dbg_l, dbg_retire;

  pdp8_top dut (
      .clk_i(clk), .rst_n_i(rst_n),
      .sw_i(sw),
      .key_load_addr_i(key_load_addr), .key_examine_i(key_examine),
      .key_deposit_i(key_deposit), .key_start_i(key_start),
      .key_stop_i(key_stop), .key_cont_i(key_cont), .key_step_i(key_step),
      .lamp_pc_o(lamp_pc), .lamp_ac_o(lamp_ac), .lamp_ma_o(lamp_ma),
      .lamp_mb_o(lamp_mb), .lamp_display_o(lamp_display),
      .lamp_l_o(lamp_l), .lamp_ion_o(lamp_ion), .lamp_run_o(lamp_run),
      .kb_data_i(kb_data), .kb_valid_i(kb_valid), .kb_ready_o(kb_ready),
      .kb_take_o(kb_take),
      .tty_data_o(tty_data), .tty_valid_o(tty_valid),
      .ptr_data_i(ptr_data), .ptr_valid_i(ptr_valid), .ptr_take_o(ptr_take),
      .ptp_data_o(ptp_data), .ptp_valid_o(ptp_valid),
      .load_we_i(load_we), .load_addr_i(load_addr), .load_data_i(load_data),
      .dbg_pc_o(dbg_pc), .dbg_ac_o(dbg_ac), .dbg_l_o(dbg_l),
      .dbg_retire_o(dbg_retire)
  );

  always #5 clk = ~clk;

  logic [11:0] prog[0:4095];
  logic [7:0]  kb_mem[0:65535];
  logic [7:0]  ptr_mem[0:65535];

  string prog_path, trace_path, tty_path, ptp_path, kb_path, ptr_path;
  int    start_addr, maxcyc, switch_value;
  int    kb_len, ptr_len, kb_pos, ptr_pos;
  int    cycles, running_seen;
  bit    tracing;
  int    tf, ttyf, ptpf;
  int    i, code;

  initial begin
    if (!$value$plusargs("prog=%s", prog_path)) begin
      $display("FAIL: +prog is required");
      $finish;
    end
    if (!$value$plusargs("trace=%s", trace_path)) trace_path = "trace.txt";
    if (!$value$plusargs("tty=%s", tty_path)) tty_path = "tty.bin";
    if (!$value$plusargs("ptp=%s", ptp_path)) ptp_path = "ptp.bin";
    kb_len = 0;
    ptr_len = 0;
    if ($value$plusargs("kb=%s", kb_path)) begin
      code = $fopen(kb_path, "rb");
      while (!$feof(code)) begin
        i = $fgetc(code);
        if (i >= 0) begin kb_mem[kb_len] = i[7:0]; kb_len = kb_len + 1; end
      end
      $fclose(code);
    end
    if ($value$plusargs("ptr=%s", ptr_path)) begin
      code = $fopen(ptr_path, "rb");
      while (!$feof(code)) begin
        i = $fgetc(code);
        if (i >= 0) begin ptr_mem[ptr_len] = i[7:0]; ptr_len = ptr_len + 1; end
      end
      $fclose(code);
    end
    if (!$value$plusargs("start=%d", start_addr)) start_addr = 0;
    if (!$value$plusargs("sw=%d", switch_value)) switch_value = 0;
    if (!$value$plusargs("maxcyc=%d", maxcyc)) maxcyc = 200000;

    $readmemh(prog_path, prog);

    tf   = $fopen(trace_path, "w");
    ttyf = $fopen(tty_path, "wb");
    ptpf = $fopen(ptp_path, "wb");

    sw = 12'd0;
    key_load_addr = 0; key_examine = 0; key_deposit = 0; key_start = 0;
    key_stop = 0; key_cont = 0; key_step = 0;
    load_we = 0; load_addr = 0; load_data = 0;
    kb_pos = 0; ptr_pos = 0;
    tracing = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // Load the image through the debug port.
    for (i = 0; i < 4096; i = i + 1) begin
      @(posedge clk); #1;
      if (prog[i] !== 12'hxxx) begin
        load_we = 1'b1; load_addr = i[11:0]; load_data = prog[i];
      end else begin
        load_we = 1'b0;
      end
    end
    @(posedge clk); #1; load_we = 1'b0;

    // LOAD ADDRESS then START, through the real front-panel path.
    @(posedge clk); #1;
    sw = start_addr[11:0];
    key_load_addr = 1'b1;
    repeat (3) @(posedge clk);
    #1; key_load_addr = 1'b0;
    repeat (2) @(posedge clk);
    tracing = 1'b1;
    sw = switch_value[11:0];
    #1; key_start = 1'b1;
    repeat (3) @(posedge clk);
    #1; key_start = 1'b0;

    cycles = 0;
    running_seen = 0;
    while (cycles < maxcyc) begin
      @(posedge clk);
      cycles = cycles + 1;
      if (lamp_run === 1'b1) running_seen = 1;
      if (running_seen != 0 && lamp_run === 1'b0) break;
    end

    if (cycles >= maxcyc)
      $display("FAIL: watchdog expired after %0d cycles", cycles);
    else
      $display("PASS: stopped after %0d cycles", cycles);
    $fclose(tf); $fclose(ttyf); $fclose(ptpf);
    $finish;
  end

  always @(posedge clk) begin
    if (tracing && dbg_retire)
      $fdisplay(tf, "%0d %0d %0d", dbg_pc, dbg_ac, dbg_l);
  end

  always @(posedge clk) begin
    if (tty_valid) $fwrite(ttyf, "%c", tty_data);
    if (ptp_valid) $fwrite(ptpf, "%c", ptp_data);
    if (kb_take && kb_pos < kb_len) kb_pos <= kb_pos + 1;
    if (ptr_take && ptr_pos < ptr_len) ptr_pos <= ptr_pos + 1;
  end

  always_comb begin
    if (kb_pos < kb_len) begin
      kb_valid = 1'b1;
      kb_data  = kb_mem[kb_pos];
    end else begin
      kb_valid = 1'b0;
      kb_data  = 8'h00;
    end
    if (ptr_pos < ptr_len) begin
      ptr_valid = 1'b1;
      ptr_data  = ptr_mem[ptr_pos];
    end else begin
      ptr_valid = 1'b0;
      ptr_data  = 8'h00;
    end
  end
endmodule
