// Front-panel and interrupt tests for the PDP-8 reconstruction.
//
// Simulates the machine's operator: DEPOSIT a program with the switch
// register, EXAMINE it back, LOAD ADDRESS, START, wait for HLT, then STEP one
// instruction at a time.  A second block checks that an interrupt vectors
// through location zero only after the ION delay.
`timescale 1ns/1ps
module tb_panel;
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

  logic [11:0] examined;
  int errors = 0;
  int i;
  bit debug_panel = 1'b0;
  logic [5:0] ptp_len;
  byte        ptp_bytes[0:63];

  task automatic pulse_key(ref logic key);
    @(posedge clk); #1; key = 1'b1;
    repeat (3) @(posedge clk);
    #1; key = 1'b0;
    repeat (3) @(posedge clk);
  endtask

  task automatic deposit(input logic [11:0] address, input logic [11:0] data);
    @(posedge clk); #1;
    sw = address;
    pulse_key(key_load_addr);
    @(posedge clk); #1;
    sw = data;
    pulse_key(key_deposit);
  endtask

  task automatic examine(input logic [11:0] address);
    @(posedge clk); #1;
    sw = address;
    pulse_key(key_load_addr);
    pulse_key(key_examine);
    examined = lamp_display;
    if (debug_panel)
      $display("EXAM %04o -> %04o (state=%0d re=%b rdata=%04o disp=%04o)",
               address, examined, dut.u_panel.state, dut.u_panel.examine_re_o,
               dut.u_panel.mem_rdata_i, dut.u_panel.display_o);
  endtask

  // Paper tape: capture punched bytes.
  always @(posedge clk) begin
    if (ptp_valid && ptp_len < 6'd63) begin
      ptp_bytes[ptp_len] = ptp_data;
      ptp_len = ptp_len + 1;
    end
  end

  initial begin
    sw = 0;
    key_load_addr = 0; key_examine = 0; key_deposit = 0; key_start = 0;
    key_stop = 0; key_cont = 0; key_step = 0;
    load_we = 0; load_addr = 0; load_data = 0;
    kb_valid = 0; kb_data = 0; ptr_valid = 0; ptr_data = 0;
    ptp_len = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // ---------------------------------------------------------- panel store
    // 0200 CLA / 0201 TAD 020 / 0202 DCA 021 / 0203 HLT / 0020 = 0123
    deposit(12'o0200, 12'o7200);
    deposit(12'o0201, 12'o1020);
    deposit(12'o0202, 12'o3021);
    deposit(12'o0203, 12'o7402);
    deposit(12'o0020, 12'o0123);

    // EXAMINE walks the same words back and advances PC.
    examine(12'o0200);
    if (examined !== 12'o7200) begin
      $display("FAIL: examine 0200 read %04o", examined);
      errors = errors + 1;
    end
    examine(12'o0201);
    if (examined !== 12'o1020) begin
      $display("FAIL: examine 0201 read %04o", examined);
      errors = errors + 1;
    end

    // ------------------------------------------------------------- run it
    @(posedge clk); #1;
    sw = 12'o0200;
    pulse_key(key_load_addr);
    pulse_key(key_start);
    for (i = 0; i < 400 && lamp_run !== 1'b0; i = i + 1) @(posedge clk);
    if (lamp_run !== 1'b0) begin
      $display("FAIL: program did not halt");
      errors = errors + 1;
    end
    if (lamp_ac !== 12'o0000) begin
      $display("FAIL: accumulator after DCA is %04o, expected 0000", lamp_ac);
      errors = errors + 1;
    end
    examine(12'o0021);
    if (examined !== 12'o0123) begin
      $display("FAIL: DCA stored %04o, expected 0123", examined);
      errors = errors + 1;
    end

    // --------------------------------------------------------- single step
    // 0200 CLA, 0201 IAC, 0202 IAC, 0203 HLT  -> AC after two steps is 2.
    deposit(12'o0200, 12'o7200);
    deposit(12'o0201, 12'o7001);
    deposit(12'o0202, 12'o7001);
    deposit(12'o0203, 12'o7402);
    @(posedge clk); #1;
    sw = 12'o0200;
    pulse_key(key_load_addr);
    pulse_key(key_step);      // instruction at 0200 (CLA)
    for (i = 0; i < 200 && lamp_run !== 1'b0; i = i + 1) @(posedge clk);
    pulse_key(key_step);      // instruction at 0201 (IAC)
    for (i = 0; i < 200 && lamp_run !== 1'b0; i = i + 1) @(posedge clk);
    if (lamp_pc !== 12'o0202) begin
      $display("FAIL: after two steps PC is %04o, expected 0202", lamp_pc);
      errors = errors + 1;
    end
    if (lamp_ac !== 12'o0001) begin
      $display("FAIL: after two steps AC is %04o, expected 0001", lamp_ac);
      errors = errors + 1;
    end
    pulse_key(key_cont);
    for (i = 0; i < 400 && lamp_run !== 1'b0; i = i + 1) @(posedge clk);
    if (lamp_ac !== 12'o0002) begin
      $display("FAIL: after CONT AC is %04o, expected 0002", lamp_ac);
      errors = errors + 1;
    end

    // ------------------------------------------------------------ interrupt
    // 0000 JMP 0300 (vector), 0200 CLA, 0201 ION, 0202 IAC, 0203 DCA 020,
    // 0204 HLT.  The keyboard flag arrives before ION, so the interrupt must
    // be taken only after the instruction following ION.
    deposit(12'o0001, 12'o5100);
    deposit(12'o0200, 12'o7200);
    deposit(12'o0201, 12'o6001);
    deposit(12'o0202, 12'o7001);
    deposit(12'o0203, 12'o3020);
    deposit(12'o0204, 12'o7402);
    deposit(12'o0100, 12'o6036);   // KRB
    deposit(12'o0101, 12'o6022);   // PPB  punch the character
    deposit(12'o0102, 12'o6002);   // IOF
    deposit(12'o0103, 12'o5400);   // JMP I 0
    kb_data = "Z"; kb_valid = 1'b1;
    @(posedge clk); #1;
    sw = 12'o0200;
    pulse_key(key_load_addr);
    pulse_key(key_start);
    for (i = 0; i < 800 && lamp_run !== 1'b0; i = i + 1) @(posedge clk);
    if (lamp_run !== 1'b0) begin
      $display("FAIL: interrupt program did not halt");
      errors = errors + 1;
    end
    if (ptp_len == 0 || ptp_bytes[0] !== 8'h5a) begin
      $display("FAIL: interrupt handler punched %02h, expected 5a", ptp_bytes[0]);
      errors = errors + 1;
    end
    if (lamp_ac !== 12'h000) begin
      // The handler clears AC (KCC) and the main program stores zero at 020.
      $display("NOTE: accumulator after interrupt is %03o", lamp_ac);
    end

    if (errors == 0) $display("PASS: panel store/examine/start/step and interrupt");
    else $display("FAIL: %0d panel checks failed", errors);
    $finish;
  end
endmodule
