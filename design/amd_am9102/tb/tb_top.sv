`timescale 1ns/1ps
module tb_top;
  logic [9:0] a = 0;
  logic cs_n = 1, we_n = 1, din = 0, standby = 0;
  logic dout, oe, valid;
  logic expected [0:1023];
  int mode_checks = 0, read_checks = 0, transparent_checks = 0, bank_checks = 0;
  amd_am9102 dut (.a_i(a), .cs_n_i(cs_n), .we_n_i(we_n), .din_i(din),
      .standby_i(standby), .dout_o(dout), .dout_oe_o(oe), .output_valid_o(valid));

  logic [10:0] bank_a = 0;
  logic bank_cs_n = 1, bank_we_n = 1, bank_din = 0;
  logic bank_d0, bank_d1, bank_oe0, bank_oe1, bank_valid0, bank_valid1;
  logic bank_expected [0:2047];
  tri bank_bus;
  amd_am9102 bank0 (.a_i(bank_a[9:0]), .cs_n_i(bank_cs_n | bank_a[10]),
      .we_n_i(bank_we_n), .din_i(bank_din), .standby_i(1'b0),
      .dout_o(bank_d0), .dout_oe_o(bank_oe0), .output_valid_o(bank_valid0));
  amd_am9102 bank1 (.a_i(bank_a[9:0]), .cs_n_i(bank_cs_n | !bank_a[10]),
      .we_n_i(bank_we_n), .din_i(bank_din), .standby_i(1'b0),
      .dout_o(bank_d1), .dout_oe_o(bank_oe1), .output_valid_o(bank_valid1));
  assign bank_bus = bank_oe0 ? bank_d0 : 1'bz;
  assign bank_bus = bank_oe1 ? bank_d1 : 1'bz;

  task automatic idle;
    cs_n = 1;
    we_n = 1;
    #1;
  endtask
  task automatic write_word(input int address, input logic value);
    idle();
    a = 10'(address);
    din = value;
    #1;
    cs_n = 0;
    we_n = 0;
    #1;
    if (!valid || !oe || dout !== value) $fatal(1,"write feedthrough at %0d", address);
    expected[address] = value;
    we_n = 1;
    #1;
  endtask
  task automatic read_word(input int address);
    idle();
    a = 10'(address);
    cs_n = 0;
    #1;
    if (!valid || !oe || dout !== expected[address])
      $fatal(1,"read mismatch a=%0d expected=%b actual=%b", address, expected[address], dout);
    read_checks++;
  endtask

  initial begin
    #1;
    for (int addr = 0; addr < 1024; addr++) write_word(addr, 1'(^addr));
    for (int addr = 0; addr < 1024; addr++) begin
      for (int data_bit = 0; data_bit < 2; data_bit++) begin
        for (int mode = 0; mode < 4; mode++) begin
          idle();
          a = 10'(addr);
          din = 1'(data_bit);
          #1;
          cs_n = 1'(mode >> 1);
          we_n = 1'(mode);
          #1;
          if (!valid || oe !== !cs_n) $fatal(1,"mode enable a=%0d m=%0d", addr, mode);
          if (!cs_n && !we_n) expected[addr] = din;
          if (oe && dout !== expected[addr]) $fatal(1,"mode data mismatch");
          mode_checks++;
          idle();
          read_word(addr);
          for (int bitno = 0; bitno < 10; bitno++) read_word(addr ^ (1 << bitno));
        end
      end
      // Keep CS/WE low while DIN changes: no extra write edge is available.
      write_word(addr, 0);
      we_n = 0;
      #1;
      for (int update = 0; update < 2; update++) begin
        din = 1'(1-update);
        #1;
        if (!oe || !valid || dout !== din) $fatal(1,"transparent output mismatch");
        transparent_checks++;
      end
      expected[addr] = din;
      we_n = 1;
      #1;
      read_word(addr);
    end

    // March C-: w0; up(r0,w1,r1,w0); down(r0,w1,r1,w0); r0.
    for (int addr = 0; addr < 1024; addr++) write_word(addr, 0);
    for (int direction = 0; direction < 2; direction++) begin
      for (int step = 0; step < 1024; step++) begin
        automatic int addr = direction == 0 ? step : 1023-step;
        if (expected[addr] !== 0) $fatal(1,"March initial data mismatch");
        read_word(addr);
        write_word(addr, 1);
        read_word(addr);
        write_word(addr, 0);
      end
    end
    for (int addr = 0; addr < 1024; addr++) read_word(addr);
    for (int pattern = 0; pattern < 2; pattern++) begin
      for (int addr = 0; addr < 1024; addr++) write_word(addr, 1'((^addr) ^ pattern));
      for (int addr = 0; addr < 1024; addr++) read_word(addr);
    end

    // Legal standby: CS remains high; WE/address/DIN activity cannot corrupt cells.
    idle();
    standby = 1;
    #1;
    for (int addr = 0; addr < 1024; addr++) begin
      a = 10'(addr);
      din = !expected[addr];
      we_n = 1'(addr);
      #1;
      if (!valid || oe) $fatal(1,"legal standby did not disable output");
    end
    we_n = 1;
    standby = 0;
    #1; // Zero-delay model; a physical caller must wait one TCYCLE here.
    for (int addr = 0; addr < 1024; addr++) read_word(addr);

    // Illegal selected standby has masked output, but cells remain isolated.
    idle();
    standby = 1;
    cs_n = 0;
    we_n = 0;
    for (int addr = 0; addr < 1024; addr++) begin
      a = 10'(addr);
      din = !expected[addr];
      #1;
      if (valid) $fatal(1,"undocumented selected standby marked valid");
    end
    idle();
    standby = 0;
    #1;
    for (int addr = 0; addr < 1024; addr++) read_word(addr);

    for (int addr = 0; addr < 2048; addr++) begin
      bank_cs_n = 1;
      bank_we_n = 1;
      #1;
      bank_a = 11'(addr);
      bank_din = 1'(^addr);
      bank_expected[addr] = bank_din;
      #1;
      bank_cs_n = 0;
      bank_we_n = 0;
      #1;
      if (!bank_valid0 || !bank_valid1 || (bank_oe0 == bank_oe1) || bank_bus !== bank_din)
        $fatal(1,"bank write/output contention at %0d", addr);
      bank_checks++;
    end
    bank_we_n = 1;
    #1;
    for (int addr = 0; addr < 2048; addr++) begin
      bank_a = 11'(addr);
      #1;
      if ((bank_oe0 == bank_oe1) || bank_bus !== bank_expected[addr])
        $fatal(1,"bank read/protection mismatch at %0d", addr);
      bank_checks++;
    end
    bank_cs_n = 1;
    #1;
    if (bank_bus !== 1'bz || bank_oe0 || bank_oe1) $fatal(1,"bank bus not high impedance");
    bank_checks++;
    if (mode_checks != 8192 || read_checks != 100352 || transparent_checks != 2048 || bank_checks != 4097)
      $fatal(1,"incomplete coverage %0d/%0d/%0d/%0d",mode_checks,read_checks,transparent_checks,bank_checks);
    $display("TEST PASSED: %0d control/data cases, %0d reads, %0d transparent updates, %0d bank checks; 0 failures",
             mode_checks,read_checks,transparent_checks,bank_checks);
    $finish;
  end
  initial begin
    #1000000;
    $fatal(1,"test watchdog expired");
  end
endmodule
