`timescale 1ns / 1ps
package intel_8086_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class intel_8086_item extends uvm_sequence_item;
    `uvm_object_utils(intel_8086_item)
    bit step = 1, rst_n = 1, ready = 1, check_state = 0;
    logic [15:0] rdata;
    logic pre_req, pre_write, pre_fetch;
    logic [19:0] pre_addr;
    logic [1:0] pre_be;
    logic [15:0] pre_wdata, pre_ip, pre_flags;
    logic [127:0] pre_regs;
    logic [63:0] pre_segs;
    logic req, write_en, fetch, halted, fault, retire;
    logic [19:0] addr;
    logic [1:0] be;
    logic [15:0] wdata, ip, flags;
    logic [127:0] regs;
    logic [63:0] segs;
    logic [15:0] expected_ip;
    bit expected_halt = 0, expected_fault = 0;
    bit check_register = 0;
    int register_index = 0;
    logic [15:0] expected_register;
    function new(string name = "intel_8086_item");
      super.new(name);
    endfunction
  endclass

  class intel_8086_driver extends uvm_driver #(intel_8086_item);
    `uvm_component_utils(intel_8086_driver)
    virtual intel_8086_if vif;
    uvm_analysis_port #(intel_8086_item) observed;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      observed = new("observed", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual intel_8086_if)::get(this, "", "vif", vif))
        `uvm_fatal("VIF", "missing interface")
    endfunction
    task run_phase(uvm_phase phase);
      intel_8086_item tr;
      forever begin
        seq_item_port.get_next_item(tr);
        if (tr.step) begin
          @(negedge vif.clk);
          vif.rst_n = tr.rst_n;
          vif.ready = tr.ready;
          vif.rdata = tr.rdata;
          #1;
          tr.pre_req = vif.req;
          tr.pre_write = vif.write_en;
          tr.pre_fetch = vif.fetch;
          tr.pre_addr = vif.addr;
          tr.pre_be = vif.be;
          tr.pre_wdata = vif.wdata;
          tr.pre_ip = vif.ip;
          tr.pre_flags = vif.flags;
          tr.pre_regs = vif.regs;
          tr.pre_segs = vif.segs;
          @(posedge vif.clk);
          #1;
        end
        tr.req = vif.req;
        tr.write_en = vif.write_en;
        tr.fetch = vif.fetch;
        tr.addr = vif.addr;
        tr.be = vif.be;
        tr.wdata = vif.wdata;
        tr.ip = vif.ip;
        tr.flags = vif.flags;
        tr.regs = vif.regs;
        tr.segs = vif.segs;
        tr.halted = vif.halted;
        tr.fault = vif.fault;
        tr.retire = vif.retire;
        observed.write(tr);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class intel_8086_scoreboard extends uvm_subscriber #(intel_8086_item);
    `uvm_component_utils(intel_8086_scoreboard)
    int snapshots = 0, transfers = 0, stalls = 0;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(intel_8086_item tr);
      if (tr.step) begin
        if (tr.pre_req && tr.ready && tr.rst_n) transfers++;
        if (tr.pre_req && !tr.ready && tr.rst_n) begin
          stalls++;
          if (!tr.req || {tr.addr,tr.be,tr.write_en,tr.fetch,tr.wdata} !==
              {tr.pre_addr,tr.pre_be,tr.pre_write,tr.pre_fetch,tr.pre_wdata} ||
              {tr.ip,tr.flags,tr.regs,tr.segs} !== {tr.pre_ip,tr.pre_flags,tr.pre_regs,tr.pre_segs} || tr.retire)
            `uvm_error("STALL", "request/architecture changed while stalled")
        end
        if (tr.req && (tr.addr[0] || !(tr.be == 1 || tr.be == 2) || tr.fetch && tr.write_en))
          `uvm_error("BUS", "invalid address/lane/direction")
        if ((!tr.rst_n || tr.halted || tr.fault) && tr.req)
          `uvm_error("IDLE", "request during reset/terminal state")
        if (!tr.rst_n && (tr.ip!==0 || tr.segs!==64'h00000000ffff0000 || tr.regs!==0 || tr.flags!==16'hf002))
          `uvm_error("RESET", "incorrect reset state")
      end
      if (tr.check_state) begin
        snapshots++;
        if (tr.ip!==tr.expected_ip || tr.halted!==tr.expected_halt || tr.fault!==tr.expected_fault)
          `uvm_error(
              "STATE", $sformatf(
              "IP=%h expected=%h halt=%b fault=%b", tr.ip, tr.expected_ip, tr.halted, tr.fault))
      end
      if (tr.check_register && tr.regs[tr.register_index*16+:16] !== tr.expected_register)
        `uvm_error("REGISTER", "architectural register mismatch")
    endfunction
  endclass

  class intel_8086_coverage extends uvm_subscriber #(intel_8086_item);
    `uvm_component_utils(intel_8086_coverage)
    bit stalled, low_lane, high_lane, wrote, halted, faulted, reset_seen;
    bit [6:0] reached = 0;
    covergroup bus_cg;
      option.per_instance = 1;
      coverpoint stalled;
      coverpoint low_lane;
      coverpoint high_lane;
      coverpoint wrote;
      coverpoint halted;
      coverpoint faulted;
      coverpoint reset_seen;
    endgroup
    function new(string name, uvm_component parent);
      super.new(name, parent);
      bus_cg = new();
    endfunction
    function void write(intel_8086_item tr);
      if (tr.step) begin
        stalled = tr.pre_req && !tr.ready && tr.rst_n;
        low_lane = tr.pre_req && tr.ready && tr.pre_be == 1;
        high_lane = tr.pre_req && tr.ready && tr.pre_be == 2;
        wrote = tr.pre_req && tr.ready && tr.pre_write;
        halted = tr.halted;
        faulted = tr.fault;
        reset_seen = !tr.rst_n;
        reached |= {reset_seen, faulted, halted, wrote, high_lane, low_lane, stalled};
        bus_cg.sample();
      end
    endfunction
  endclass

  class intel_8086_control_seq extends uvm_sequence #(intel_8086_item);
    `uvm_object_utils(intel_8086_control_seq)
    bit [7:0] memory[0:1048575];
    intel_8086_item last;
    int steps = 0, completed = 0, writes = 0;
    bit stall_enable = 1;
    bit [19:0] first_fetch;
    bit [7:0] first_opcode;
    bit fetched = 0;
    function new(string name = "intel_8086_control_seq");
      super.new(name);
    endfunction
    task tick(input bit reset_n = 1, input bit force_stall = 0);
      intel_8086_item tr = intel_8086_item::type_id::create("step");
      start_item(tr);
      steps++;
      tr.rst_n = reset_n;
      tr.ready = !(force_stall || stall_enable && steps % 7 < 3);
      tr.rdata = 0;
      if (last != null && last.req) tr.rdata = {memory[(last.addr+1)&20'hfffff], memory[last.addr]};
      finish_item(tr);
      if (tr.pre_req && tr.ready && reset_n) begin
        bit [19:0] address = tr.pre_addr + (tr.pre_be == 2 ? 20'd1 : 20'd0);
        if (tr.pre_write) begin
          memory[address] = tr.pre_be == 2 ? tr.pre_wdata[15:8] : tr.pre_wdata[7:0];
          writes++;
        end else if (tr.pre_fetch && !fetched) begin
          first_fetch = address;
          first_opcode = memory[address];
          fetched = 1;
        end
      end
      last = tr;
    endtask
    task check(input logic [15:0] expected_ip, input bit halt = 0, input bit fault = 0,
               input int reg_index = -1, input logic [15:0] reg_value = 0);
      intel_8086_item tr = intel_8086_item::type_id::create("check");
      start_item(tr);
      tr.step = 0;
      tr.check_state = 1;
      tr.expected_ip = expected_ip;
      tr.expected_halt = halt;
      tr.expected_fault = fault;
      tr.check_register = reg_index >= 0;
      tr.register_index = reg_index;
      tr.expected_register = reg_value;
      finish_item(tr);
    endtask
    task instruction(input logic [15:0] next_ip, input bit halt = 0, input int reg_index = -1,
                     input logic [15:0] reg_value = 0);
      bit found = 0;
      bit [19:0] expected_fetch = ((32'(last.segs[31:16]) << 4) + 32'(last.ip)) & 20'hfffff;
      bit [7:0] expected_opcode = memory[expected_fetch];
      fetched = 0;
      for (int count = 0; count < 500 && !found; count++) begin
        tick();
        found = last.retire;
      end
      if (!found || last.fault || !fetched || first_fetch!==expected_fetch || first_opcode!==expected_opcode)
        `uvm_fatal("INSTRUCTION", "exact next instruction/retirement mismatch")
      check(next_ip, halt, 0, reg_index, reg_value);
    endtask
    task boot;
      // Only the five-byte far jump is placed at reset; no tolerant padding.
      memory[20'hffff0] = 8'hea;
      memory[20'hffff1] = 0;
      memory[20'hffff2] = 0;
      memory[20'hffff3] = 0;
      memory[20'hffff4] = 8'h10;
      writes = 0;
      repeat (2) tick(0);
      instruction(0);
    endtask
    task program_bytes(input bit [7:0] code[]);
      foreach (code[i]) memory[20'h10000+i] = code[i];
    endtask
    task body;
      // Segment-offset word wrap, with exact writes and opposite-lane accesses.
      program_bytes('{8'hb8, 0, 8'h20, 8'h8e, 8'hd8, 8'hb8, 8'h34, 8'h12, 8'ha3, 8'hff, 8'hff,
                    8'hb8, 0, 0, 8'ha1, 8'hff, 8'hff, 8'hf4});
      boot();
      instruction(3);
      instruction(5);
      instruction(8);
      instruction(11);
      instruction(14);
      instruction(17, 0, 0, 16'h1234);
      instruction(18, 1);
      if (writes != 2 || memory[20'h2ffff] != 8'h34 || memory[20'h20000] != 8'h12)
        `uvm_fatal("WRAP", "word did not wrap its segment offset")
      repeat (10) tick();
      check(18, 1);
      completed++;

      // BP+SI defaults to SS; signed disp8=-2, explicit DS override wins.
      program_bytes('{8'hb8, 0, 8'h20, 8'h8e, 8'hd8, 8'hb8, 0, 8'h30, 8'h8e, 8'hd0, 8'hbd, 8'h10, 0,
                    8'hbe, 3, 0, 8'hb8, 8'h22, 8'h11, 8'h89, 8'h42, 8'hfe, 8'h3e, 8'h89, 8'h42,
                    8'hfe, 8'h8d, 8'h5a, 8'hfe, 8'hf4});
      boot();
      instruction(3);
      instruction(5);
      instruction(8);
      instruction(10);
      instruction(13);
      instruction(16);
      instruction(19);
      instruction(22);
      instruction(26);
      instruction(29, 0, 3, 16'h0011);
      instruction(30, 1);
      if (writes!=4 || memory[20'h30011]!=8'h22 || memory[20'h30012]!=8'h11 ||
          memory[20'h20011]!=8'h22 || memory[20'h20012]!=8'h11)
        `uvm_fatal("SEGMENT", "BP/default/override/disp8 mismatch")
      completed++;

      // Original PUSH SP stores decremented SP; POP SP loads its popped value.
      program_bytes('{8'hbc, 0, 8'h80, 8'h54, 8'h58, 8'h50, 8'h5c, 8'hf4});
      boot();
      instruction(3);
      instruction(4, 0, 4, 16'h7ffe);
      instruction(5, 0, 0, 16'h7ffe);
      instruction(6);
      instruction(7, 0, 4, 16'h7ffe);
      instruction(8, 1);
      if (writes != 4 || memory[20'h07ffe] != 8'hfe || memory[20'h07fff] != 8'h7f)
        `uvm_fatal("STACK", "PUSH/POP SP mismatch")
      completed++;

      // 20-bit physical wrap: FFFF:0010 is physical zero.
      program_bytes('{8'hb8, 8'hff, 8'hff, 8'h8e, 8'hd8, 8'hb0, 8'h5a, 8'ha2, 8'h10, 0, 8'hb0, 0,
                    8'ha0, 8'h10, 0, 8'hf4});
      boot();
      instruction(3);
      instruction(5);
      instruction(7);
      instruction(10);
      instruction(12);
      instruction(15, 0, 0, 16'hff5a);
      instruction(16, 1);
      if (writes != 1 || memory[0] != 8'h5a) `uvm_fatal("PHYSICAL", "20-bit wrap mismatch")
      completed++;

      // Fetch at CS:FFFF wraps IP, without advancing CS.
      program_bytes('{8'hea, 8'hff, 8'hff, 0, 8'h10});
      memory[20'h1ffff] = 8'h90;
      boot();
      instruction(16'hffff);
      instruction(0);
      // Install a distinct next opcode only after the previous exact boundary.
      memory[20'h10000] = 8'hf4;
      instruction(1, 1);
      completed++;

      // Reset aborts an indefinitely stalled write, before memory acceptance.
      program_bytes('{8'hb8, 8'h55, 8'haa, 8'ha3, 8'h00, 8'h40, 8'hf4});
      boot();
      instruction(3);
      begin
        bit found = 0;
        for (int count = 0; count < 100 && !found; count++) begin
          tick();
          found = last.req && last.write_en;
        end
        if (!found) `uvm_fatal("WRITE", "write request absent")
      end
      repeat (20) tick(1, 1);
      if (writes != 0) `uvm_fatal("RESET", "stalled write accepted")
      tick(0, 1);
      check(0);
      if (last.req) `uvm_fatal("RESET", "reset request still active")
      completed++;

      // Unsupported LOCK and MOV CS fail explicitly and never retire.
      for (int scenario = 0; scenario < 2; scenario++) begin
        if (scenario == 0) program_bytes('{8'hf0, 8'h90});
        else program_bytes('{8'h8e, 8'hc8});
        boot();
        begin
          bit found = 0;
          for (int count = 0; count < 100 && !found; count++) begin
            tick();
            found = last.fault;
            if (last.retire) `uvm_fatal("FAULT", "unsupported instruction retired")
          end
          if (!found) `uvm_fatal("FAULT", "unsupported instruction did not stop")
        end
        check(scenario == 0 ? 1 : 2, 0, 1);
        repeat (10) tick();
        if (last.req || last.retire) `uvm_fatal("FAULT", "fault state not idle")
        completed++;
      end
    endtask
  endclass

  class intel_8086_control_test extends uvm_test;
    `uvm_component_utils(intel_8086_control_test)
    uvm_sequencer #(intel_8086_item) sequencer;
    intel_8086_driver driver;
    intel_8086_scoreboard scoreboard;
    intel_8086_coverage coverage;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = new("sequencer", this);
      driver = intel_8086_driver::type_id::create("driver", this);
      scoreboard = intel_8086_scoreboard::type_id::create("scoreboard", this);
      coverage = intel_8086_coverage::type_id::create("coverage", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.observed.connect(scoreboard.analysis_export);
      driver.observed.connect(coverage.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
      intel_8086_control_seq sequence_inst;
      phase.raise_objection(this);
      sequence_inst = intel_8086_control_seq::type_id::create("sequence_inst");
      sequence_inst.start(sequencer);
      if (sequence_inst.completed!=8 || coverage.reached!==7'h7f || scoreboard.stalls<20 || scoreboard.snapshots<40)
        `uvm_fatal("COVERAGE", "required scenarios/control observations absent")
      if (uvm_report_server::get_server().get_severity_count(
              UVM_ERROR
          ) != 0 || uvm_report_server::get_server().get_severity_count(
              UVM_FATAL
          ) != 0)
        `uvm_fatal("RESULT", "scoreboard reported failures")
      `uvm_info("RESULT", "TEST PASSED: 8 UVM 8086 control/boundary scenarios; 0 failures",
                UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage
