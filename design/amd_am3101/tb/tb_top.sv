`timescale 1ns/1ps
module tb_top;
  logic [3:0] a_i = 0;
  logic cs_n_i = 1;
  logic we_n_i = 1;
  logic [3:0] d_i = 0;
  logic [3:0] q_n_o;
  logic output_valid_o;
  logic [3:0] expected [0:15];
  integer mode_checks = 0;
  integer read_checks = 0;
  integer transparent_checks = 0;
  integer bank_checks = 0;

  logic [4:0] bank_address = 0;
  logic [3:0] bank_data = 0;
  logic bank_selected = 0;
  logic bank_write = 0;
  logic [3:0] bank_q0, bank_q1, bank_bus;
  logic bank_valid0, bank_valid1;
  logic bank_cs0, bank_cs1, bank_we0, bank_we1;
  logic [3:0] bank_expected [0:31];
  amd_am3101 dut (.*);
  assign bank_cs0 = !(bank_selected && !bank_address[4]);
  assign bank_cs1 = !(bank_selected && bank_address[4]);
  // Inactive chip W stays HIGH: CS alone cannot release a deselected writer.
  assign bank_we0 = !(bank_write && !bank_cs0);
  assign bank_we1 = !(bank_write && !bank_cs1);
  assign bank_bus = bank_q0 & bank_q1;
  amd_am3101 bank0 (
      .a_i(bank_address[3:0]), .cs_n_i(bank_cs0), .we_n_i(bank_we0),
      .d_i(bank_data), .q_n_o(bank_q0), .output_valid_o(bank_valid0)
  );
  amd_am3101 bank1 (
      .a_i(bank_address[3:0]), .cs_n_i(bank_cs1), .we_n_i(bank_we1),
      .d_i(bank_data), .q_n_o(bank_q1), .output_valid_o(bank_valid1)
  );

  task automatic check_mode;
    mode_checks++;
    if (output_valid_o !== (!cs_n_i || we_n_i))
      $fatal(1,"output-valid mode mismatch");
    if (cs_n_i && we_n_i && q_n_o !== 4'hf)
      $fatal(1,"deselected read did not release outputs");
    if (!cs_n_i && !we_n_i && q_n_o !== ~d_i)
      $fatal(1,"selected-write output did not invert D");
    if (!cs_n_i && we_n_i && q_n_o !== ~expected[a_i])
      $fatal(1,"selected read mismatch");
  endtask

  task automatic write_word(input logic [3:0] address_value, data_value);
    cs_n_i = 1;
    we_n_i = 1;
    a_i = address_value;
    d_i = data_value;
    #1;
    cs_n_i = 0;
    we_n_i = 0;
    #2;
    expected[address_value] = data_value;
    we_n_i = 1;
    #1;
    cs_n_i = 1;
    #1;
  endtask

  task automatic scan_memory;
    we_n_i = 1;
    cs_n_i = 0;
    for (integer address_value = 0; address_value < 16; address_value++) begin
      a_i = 4'(address_value);
      #1;
      if (!output_valid_o || q_n_o !== ~expected[address_value])
        $fatal(1,"RAM address %0d got=%h expected inverted=%h",address_value,q_n_o,~expected[address_value]);
      read_checks++;
    end
    cs_n_i = 1;
    #1;
  endtask

  initial begin
    // Known contents established exclusively by writes to the actual DUT.
    for (integer address_value = 0; address_value < 16; address_value++)
      write_word(4'(address_value),4'(address_value));
    scan_memory();
    for (integer address_value = 0; address_value < 16; address_value++) begin
      for (integer data_value = 0; data_value < 16; data_value++) begin
        for (integer mode_value = 0; mode_value < 4; mode_value++) begin
          cs_n_i = 1;
          we_n_i = 1;
          a_i = 4'(address_value);
          d_i = 4'(data_value);
          #1;
          cs_n_i = 1'(mode_value >> 1);
          we_n_i = 1'(mode_value);
          #2;
          if (!cs_n_i && !we_n_i) expected[address_value] = d_i;
          check_mode();
          we_n_i = 1;
          #1;
          cs_n_i = 1;
          #1;
          scan_memory();
        end
      end
    end

    // Data must remain transparent during a write, not just at a strobe edge.
    for (integer address_value = 0; address_value < 16; address_value++) begin
      a_i = 4'(address_value);
      d_i = 0;
      #1;
      cs_n_i = 0;
      we_n_i = 0;
      for (integer data_value = 0; data_value < 16; data_value++) begin
        d_i = 4'(data_value);
        #2;
        expected[address_value] = d_i;
        if (q_n_o !== ~d_i || !output_valid_o) $fatal(1,"transparent write output mismatch");
        transparent_checks++;
      end
      we_n_i = 1;
      #1;
      scan_memory();
    end

    // CS can define the write window while W is already LOW.
    for (integer address_value = 0; address_value < 16; address_value++) begin
      cs_n_i = 1;
      we_n_i = 0;
      a_i = 4'(address_value);
      d_i = 4'(address_value ^ 10);
      #2;
      if (output_valid_o) $fatal(1,"deselected write was presented as valid");
      cs_n_i = 0;
      #2;
      expected[address_value] = d_i;
      cs_n_i = 1;
      #1;
      d_i = ~d_i;
      #2;
      we_n_i = 1;
      #1;
      scan_memory();
    end

    for (integer address_value = 0; address_value < 32; address_value++) begin
      bank_selected = 0;
      bank_write = 0;
      bank_address = 5'(address_value);
      bank_data = 4'((address_value*3) ^ (address_value >> 4));
      #1;
      bank_selected = 1;
      bank_write = 1;
      #2;
      bank_expected[address_value] = bank_data;
      bank_write = 0;
      #1;
      bank_selected = 0;
      #1;
    end
    for (integer address_value = 0; address_value < 32; address_value++) begin
      bank_address = 5'(address_value);
      bank_selected = 1;
      #1;
      if (!bank_valid0 || !bank_valid1 || bank_bus !== ~bank_expected[address_value])
        $fatal(1,"open-collector bank address %0d mismatch",address_value);
      bank_checks++;
    end
    bank_selected = 0;
    #1;
    if (bank_bus !== 4'hf) $fatal(1,"both deselected banks did not release bus");
    bank_checks++;
    if (mode_checks != 1024 || read_checks != 16912 || transparent_checks != 256 || bank_checks != 33)
      $fatal(1,"incomplete coverage %0d/%0d/%0d/%0d",mode_checks,read_checks,transparent_checks,bank_checks);
    $display("TEST PASSED: %0d control/data cases, %0d memory reads, %0d transparent updates, %0d bank checks; 0 failures",
             mode_checks,read_checks,transparent_checks,bank_checks);
    $finish;
  end

  initial begin
    #100000;
    $fatal(1,"test watchdog expired");
  end
endmodule
