`timescale 1ns / 1ps
package intel_8088_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class intel_8088_item extends uvm_sequence_item;
    `uvm_object_utils(intel_8088_item)
    // Command fields.
    bit run_until_retire = 0, run_ticks = 0, sample_only = 0;
    int max_cycles = 40000, run_count = 1;
    bit force_stall = 0;
    bit set_reset = 0, reset_val = 0;
    bit set_mode = 0, mode_val = 1;
    bit set_intr = 0, intr_val = 0;
    bit set_hold = 0, hold_val = 0;
    bit set_testn = 0, testn_val = 1;
    bit clear_mem = 0;
    bit load_bytes = 0;
    logic [19:0] load_addr;
    logic [7:0] bytes[$];
    bit check_mem = 0;
    logic [19:0] mem_addr;
    logic [7:0] mem_val;
    bit wait_write_cycle = 0, wait_queue = 0;
    int queue_target = 4;
    bit ready_at_t2 = 1;
    // Observed command outcome.
    bit retired = 0, timed_out = 0;
    logic [15:0] ip, flags;
    logic [127:0] regs;
    logic [63:0] segs;
    bit halted, fault;
    bit mem_match = 1;
    logic [7:0] mem_read;
    // Per-clock snapshot fields (pre-edge pins, post-edge state).
    bit [2:0] pre_phase, post_phase, status, status_pins;
    bit [19:0] address;
    bit [7:0] ad_out, high_address;
    bit [3:0] address_status;
    bit ale, den_n, dt_r, wr_n, rd_n, inta_n, io_m, sso_n, sso_oe, ad_oe;
    bit high_address_oe, address_status_oe, control_oe, hlda;
    bit [1:0] rqgt_oe, qs;
    bit [2:0] queue_count;
    bit ready_driven, min_mode, reset;
    function new(string name = "intel_8088_item");
      super.new(name);
    endfunction
  endclass

  class intel_8088_driver extends uvm_driver #(intel_8088_item);
    `uvm_component_utils(intel_8088_driver)
    virtual intel_8088_if vif;
    uvm_analysis_port #(intel_8088_item) observed;
    bit [7:0] mem [bit [19:0]];
    bit [7:0] ports [bit [15:0]];
    int steps = 0, cycles = 0, acknowledgements = 0, write_count = 0;
    bit [19:0] cycle_address;
    bit [2:0] cycle_status = 3'b111;
    bit ready_at_t2 = 1;
    bit [1:0] external_rqgt = 2'b11;
    bit stall_enable = 1;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      observed = new("observed", this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual intel_8088_if)::get(this, "", "vif", vif))
        `uvm_fatal("VIF", "missing interface")
      for (int i = 0; i < 65536; i++) ports[i] = 8'hff;
    endfunction
    function byte read_mem(bit [19:0] a);
      return mem.exists(a) ? mem[a] : 8'h00;
    endfunction
    task tick(bit stall);
      intel_8088_item tr = intel_8088_item::type_id::create("clk");
      @(negedge vif.clk);
      steps++;
      vif.ready = !(stall || (stall_enable && (steps % 7 < 3)));
      vif.rqgt_n = external_rqgt & (vif.rqgt_n_o | (~vif.rqgt_oe & 2'b11));
      if (vif.control_oe && vif.phase == 3'd1 && !vif.reset) begin
        cycle_status = vif.status;
        if (vif.status != 3'd0)
          cycle_address = {vif.address_status, vif.high_address, vif.ad_out};
      end
      if (vif.phase == 3'd2) ready_at_t2 = vif.ready;
      vif.ad_in = (cycle_status == 3'd0) ? 8'h20 :
                  (cycle_status <= 3'd2) ? ports[cycle_address[15:0]] : read_mem(cycle_address);
      tr.pre_phase = vif.phase; tr.status = cycle_status; tr.status_pins = vif.status;
      tr.address = cycle_address; tr.ad_out = vif.ad_out; tr.high_address = vif.high_address;
      tr.address_status = vif.address_status;
      tr.ale = vif.ale; tr.den_n = vif.den_n; tr.dt_r = vif.dt_r; tr.wr_n = vif.wr_n;
      tr.rd_n = vif.rd_n; tr.inta_n = vif.inta_n; tr.io_m = vif.io_m; tr.sso_n = vif.sso_n;
      tr.sso_oe = vif.sso_oe; tr.ad_oe = vif.ad_oe; tr.high_address_oe = vif.high_address_oe;
      tr.address_status_oe = vif.address_status_oe; tr.control_oe = vif.control_oe;
      tr.hlda = vif.hlda; tr.rqgt_oe = vif.rqgt_oe; tr.qs = vif.qs;
      tr.queue_count = vif.queue_count; tr.ready_driven = vif.ready;
      tr.ready_at_t2 = ready_at_t2;
      tr.min_mode = vif.min_mode; tr.reset = vif.reset;
      @(posedge vif.clk);
      #1;
      tr.post_phase = vif.phase; tr.ip = vif.ip; tr.flags = vif.flags;
      tr.regs = vif.regs; tr.segs = vif.segs; tr.halted = vif.halted;
      tr.fault = vif.fault; tr.retire = vif.retire;
      if (!vif.reset && (tr.pre_phase == 3'd3 || tr.pre_phase == 3'd4) && tr.post_phase == 3'd5) begin
        if (cycle_status == 3'd0) acknowledgements++;
        else if (cycle_status == 3'd2) ports[cycle_address[15:0]] = tr.ad_out;
        else if (cycle_status == 3'd6) begin
          mem[cycle_address] = tr.ad_out;
          write_count++;
        end
      end
      cycles++;
      observed.write(tr);
    endtask
    function void apply_command(intel_8088_item tr);
      if (tr.set_reset) vif.reset = tr.reset_val;
      if (tr.set_mode) vif.min_mode = tr.mode_val;
      if (tr.set_intr) vif.intr = tr.intr_val;
      if (tr.set_hold) vif.hold = tr.hold_val;
      if (tr.set_testn) vif.test_n = tr.testn_val;
      if (tr.clear_mem) begin
        mem.delete();
        for (int i = 0; i < 65536; i++) ports[i] = 8'hff;
        acknowledgements = 0; write_count = 0;
      end
      if (tr.load_bytes)
        for (int i = 0; i < tr.bytes.size(); i++)
          mem[tr.load_addr + i] = tr.bytes[i];
      if (tr.check_mem) begin
        tr.mem_read = read_mem(tr.mem_addr);
        tr.mem_match = tr.mem_read == tr.mem_val;
      end
    endfunction
    task run_phase(uvm_phase phase);
      intel_8088_item tr;
      forever begin
        seq_item_port.get_next_item(tr);
        apply_command(tr);
        if (tr.sample_only) begin
          capture_state(tr);
        end else if (tr.run_ticks) begin
          for (int i = 0; i < tr.run_count; i++) tick(tr.force_stall);
          capture_state(tr);
        end else if (tr.run_until_retire) begin
          tr.timed_out = 1;
          for (int i = 0; i < tr.max_cycles && tr.timed_out; i++) begin
            tick(tr.force_stall);
            if (vif.retire || vif.fault) tr.timed_out = 0;
          end
          capture_state(tr);
        end else if (tr.wait_write_cycle) begin
          tr.timed_out = 1;
          for (int i = 0; i < tr.max_cycles && tr.timed_out; i++) begin
            tick(0);
            if (vif.control_oe && vif.phase >= 3'd2 && vif.phase <= 3'd4 &&
                vif.status == 3'd6) tr.timed_out = 0;
          end
          capture_state(tr);
        end else if (tr.wait_queue) begin
          tr.timed_out = 1;
          for (int i = 0; i < tr.max_cycles && tr.timed_out; i++) begin
            tick(0);
            if (vif.queue_count == tr.queue_target[2:0]) tr.timed_out = 0;
          end
          capture_state(tr);
        end
        tr.retired = vif.retire;
        tr.ip = vif.ip; tr.flags = vif.flags; tr.regs = vif.regs; tr.segs = vif.segs;
        tr.halted = vif.halted; tr.fault = vif.fault;
        seq_item_port.item_done();
      end
    endtask
    function void capture_state(intel_8088_item tr);
      tr.ip = vif.ip; tr.flags = vif.flags; tr.regs = vif.regs; tr.segs = vif.segs;
      tr.halted = vif.halted; tr.fault = vif.fault;
      tr.hlda = vif.hlda; tr.queue_count = vif.queue_count;
    endfunction
  endclass

  class intel_8088_scoreboard extends uvm_subscriber #(intel_8088_item);
    `uvm_component_utils(intel_8088_scoreboard)
    int snapshots = 0, waits = 0;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(intel_8088_item tr);
      if (tr.reset) begin
        if (tr.ip !== 16'h0000 || tr.flags !== 16'hf002 ||
            tr.segs !== 64'h00000000ffff0000 || tr.regs !== 128'h0)
          `uvm_error("RESET", "incorrect reset state")
        return;
      end
      snapshots++;
      if (tr.ale !== (tr.min_mode && tr.pre_phase == 3'd1 && tr.control_oe))
        `uvm_error("ALE", "ALE timing/mode")
      if (tr.hlda && (tr.ad_oe || tr.high_address_oe || tr.address_status_oe ||
                      tr.control_oe || tr.sso_oe))
        `uvm_error("HOLD", "pins did not float during HLDA")
      if ((tr.pre_phase == 3'd3 && !tr.ready_at_t2 || tr.pre_phase == 3'd4 && !tr.ready_driven) &&
          tr.post_phase !== 3'd4)
        `uvm_error("TW", "wait state did not persist")
      if (tr.control_oe && tr.pre_phase >= 3'd2 && tr.pre_phase <= 3'd4) begin
        bit writing = tr.status == 3'd2 || tr.status == 3'd6;
        if (tr.ad_oe !== writing)
          `uvm_error("DIR", "native data direction")
        if (tr.rd_n !== (writing || tr.status == 3'd0))
          `uvm_error("RD", "native RD phase")
        if (tr.io_m !== (tr.status <= 3'd2))
          `uvm_error("IOM", "IO/M polarity")
        if (tr.min_mode) begin
          if (tr.den_n !== 1'b0)
            `uvm_error("DEN", "data enable phase")
          if (tr.wr_n !== !writing)
            `uvm_error("WR", "write strobe phase")
          if (tr.inta_n !== (tr.status != 3'd0))
            `uvm_error("INTA", "interrupt acknowledge strobe")
        end
        if (tr.status != 3'd0 && tr.high_address !== tr.address[15:8])
          `uvm_error("A815", "A8-A15 lost during bus cycle")
      end
      // Status and SS0 track the latched cycle status only while the status
      // bus is still active: through T2, and through T3/Tw only until READY
      // permits completion, mirroring the datasheet rule that the 8288 must
      // see the active status until the T3/Tw completion.
      if (tr.control_oe && tr.pre_phase >= 3'd2 && tr.pre_phase <= 3'd4 &&
          (tr.pre_phase == 3'd2 ||
           (tr.pre_phase == 3'd3 ? !tr.ready_at_t2 : !tr.ready_driven))) begin
        if (tr.status_pins !== tr.status)
          `uvm_error("STATUS", "active cycle status lost during READY wait")
        if (tr.min_mode && tr.sso_n !== !tr.status[0])
          `uvm_error("SS0", "SS0 does not mirror status bit 0")
      end
      if (tr.control_oe && tr.pre_phase == 3'd5) begin
        if (tr.ad_oe !== (tr.status == 3'd2 || tr.status == 3'd6))
          `uvm_error("T4", "write-data hold")
        if (tr.min_mode && tr.den_n !== 1'b0)
          `uvm_error("T4DEN", "data-enable hold")
      end
      if (tr.post_phase == 3'd4 && tr.pre_phase != 3'd4) waits++;
      if (tr.queue_count > 3'd4)
        `uvm_error("QUEUE", "four-byte prefetch overflow")
    endfunction
  endclass

  class intel_8088_coverage extends uvm_subscriber #(intel_8088_item);
    `uvm_component_utils(intel_8088_coverage)
    bit [9:0] reached = 0;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(intel_8088_item tr);
      if (tr.post_phase == 3'd4 && tr.pre_phase != 3'd4) reached[0] = 1;
      if (tr.pre_phase == 3'd3 && !tr.ready_driven) reached[0] = 1;
      if (tr.status == 3'd6 && tr.pre_phase == 3'd3 && tr.post_phase == 3'd5) reached[1] = 1;
      if (tr.status == 3'd4 && tr.pre_phase == 3'd3 && tr.post_phase == 3'd5) reached[2] = 1;
      if (tr.status <= 3'd2 && tr.status >= 3'd1 && tr.pre_phase >= 3'd3 &&
          tr.pre_phase <= 3'd4 && tr.post_phase == 3'd5) reached[3] = 1;
      if (tr.queue_count == 3'd4) reached[5] = 1;
      if (tr.qs == 2'b10) reached[6] = 1;
      if (tr.hlda) reached[7] = 1;
      if (tr.fault) reached[8] = 1;
      if (tr.reset) reached[9] = 1;
    endfunction
  endclass

  class intel_8088_control_seq extends uvm_sequence #(intel_8088_item);
    `uvm_object_utils(intel_8088_control_seq)
    int completed = 0;
    function new(string name = "intel_8088_control_seq");
      super.new(name);
    endfunction
    task tick(input int count = 1, input bit stall = 0);
      intel_8088_item tr = intel_8088_item::type_id::create("ticks");
      start_item(tr);
      tr.run_ticks = 1; tr.run_count = count; tr.force_stall = stall;
      finish_item(tr);
    endtask
    task set_signal(input bit do_reset = 0, input bit reset_val = 0,
                    input bit do_hold = 0, input bit hold_val = 0,
                    input bit do_testn = 0, input bit testn_val = 1);
      intel_8088_item tr = intel_8088_item::type_id::create("signal");
      start_item(tr);
      tr.set_reset = do_reset; tr.reset_val = reset_val;
      tr.set_hold = do_hold; tr.hold_val = hold_val;
      tr.set_testn = do_testn; tr.testn_val = testn_val;
      finish_item(tr);
    endtask
    task program_bytes(input bit [19:0] addr, input bit [7:0] code[]);
      intel_8088_item tr = intel_8088_item::type_id::create("load");
      start_item(tr);
      tr.load_bytes = 1; tr.load_addr = addr;
      foreach (code[i]) tr.bytes.push_back(code[i]);
      finish_item(tr);
    endtask
    task check_mem(input bit [19:0] addr, input bit [7:0] expected);
      intel_8088_item tr = intel_8088_item::type_id::create("checkmem");
      start_item(tr);
      tr.check_mem = 1; tr.mem_addr = addr; tr.mem_val = expected;
      finish_item(tr);
      if (!tr.mem_match)
        `uvm_fatal("MEMORY", $sformatf("memory[%h]=%02h expected=%02h",
                   addr, tr.mem_read, expected))
    endtask
    task instruction(input logic [15:0] next_ip, input bit halt = 0, input bit fault = 0,
                     input int reg_index = -1, input logic [15:0] reg_value = 0);
      intel_8088_item tr = intel_8088_item::type_id::create("instr");
      start_item(tr);
      tr.run_until_retire = 1;
      finish_item(tr);
      if (tr.timed_out || !tr.retired && !fault || tr.fault !== fault || tr.halted !== halt ||
          tr.ip !== next_ip)
        `uvm_fatal("INSTRUCTION", $sformatf(
          "exact boundary mismatch ip=%h expected=%h fault=%b halted=%b timed_out=%b",
          tr.ip, next_ip, tr.fault, tr.halted, tr.timed_out))
      if (reg_index >= 0 && tr.regs[reg_index*16 +: 16] !== reg_value)
        `uvm_fatal("REGISTER", "architectural register mismatch")
    endtask
    task boot;
      set_signal(1, 1);
      tick(2, 1);
      set_signal(1, 0);
      program_bytes(20'hffff0, '{8'hea, 8'h00, 8'h00, 8'h00, 8'h10});
      // Only the five-byte far jump is placed at reset; no tolerant padding.
      instruction(0);
    endtask
    task body;
      // Segment-offset word wrap, with exact writes and opposite-lane reads.
      program_bytes(20'h10000, '{8'hb8, 8'h00, 8'h20, 8'h8e, 8'hd8, 8'hb8, 8'h34, 8'h12,
                    8'ha3, 8'hff, 8'hff, 8'hb8, 8'h00, 8'h00, 8'ha1, 8'hff, 8'hff, 8'hf4});
      boot();
      instruction(3);
      instruction(5);
      instruction(8);
      instruction(11);
      instruction(14);
      instruction(17, 0, 0, 0, 16'h1234);
      instruction(18, 1);
      check_mem(20'h2ffff, 8'h34);
      check_mem(20'h20000, 8'h12);
      repeat (5) tick();
      completed++;

      // BP+SI defaults to SS; signed disp8=-2, explicit DS override wins.
      program_bytes(20'h10000, '{8'hb8, 8'h00, 8'h20, 8'h8e, 8'hd8, 8'hb8, 8'h00, 8'h30,
                    8'h8e, 8'hd0, 8'hbd, 8'h10, 8'h00, 8'hbe, 8'h03, 8'h00, 8'hb8, 8'h22,
                    8'h11, 8'h89, 8'h42, 8'hfe, 8'h3e, 8'h89, 8'h42, 8'hfe, 8'h8d, 8'h5a,
                    8'hfe, 8'hf4});
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
      instruction(29, 0, 0, 3, 16'h0011);
      instruction(30, 1);
      check_mem(20'h30011, 8'h22);
      check_mem(20'h30012, 8'h11);
      check_mem(20'h20011, 8'h22);
      check_mem(20'h20012, 8'h11);
      completed++;

      // Original PUSH SP stores decremented SP; POP SP loads its popped value.
      program_bytes(20'h10000, '{8'hbc, 8'h00, 8'h80, 8'h54, 8'h58, 8'h50, 8'h5c, 8'hf4});
      boot();
      instruction(3);
      instruction(4, 0, 0, 4, 16'h7ffe);
      instruction(5, 0, 0, 0, 16'h7ffe);
      instruction(6);
      instruction(7, 0, 0, 4, 16'h7ffe);
      instruction(8, 1);
      check_mem(20'h07ffe, 8'hfe);
      check_mem(20'h07fff, 8'h7f);
      completed++;

      // 20-bit physical wrap: FFFF:0010 is physical zero.
      program_bytes(20'h10000, '{8'hb8, 8'hff, 8'hff, 8'h8e, 8'hd8, 8'hb0, 8'h5a, 8'ha2,
                    8'h10, 8'h00, 8'hb0, 8'h00, 8'ha0, 8'h10, 8'h00, 8'hf4});
      boot();
      instruction(3);
      instruction(5);
      instruction(7);
      instruction(10);
      instruction(12);
      instruction(15, 0, 0, 0, 16'hff5a);
      instruction(16, 1);
      check_mem(20'h00000, 8'h5a);
      completed++;

      // Fetch at CS:FFFF wraps IP, without advancing CS.
      program_bytes(20'h10000, '{8'hea, 8'hff, 8'hff, 8'h00, 8'h10});
      program_bytes(20'h1ffff, '{8'h90});
      boot();
      instruction(16'hffff);
      instruction(0);
      program_bytes(20'h10000, '{8'hf4});
      instruction(1, 1);
      completed++;

      // Reset aborts an indefinitely stalled write, before memory acceptance.
      program_bytes(20'h10000, '{8'hb8, 8'h55, 8'haa, 8'ha3, 8'h00, 8'h40, 8'hf4});
      boot();
      instruction(3);
      begin
        intel_8088_item tr = intel_8088_item::type_id::create("write");
        start_item(tr);
        tr.wait_write_cycle = 1;
        finish_item(tr);
        if (tr.timed_out) `uvm_fatal("WRITE", "write cycle absent")
      end
      tick(20, 1);
      check_mem(20'h04000, 8'h00);
      check_mem(20'h04001, 8'h00);
      set_signal(1, 1);
      tick(1, 1);
      begin
        intel_8088_item tr = intel_8088_item::type_id::create("state");
        start_item(tr);
        tr.sample_only = 1;
        finish_item(tr);
        if (tr.ip !== 16'h0000 || tr.segs !== 64'h00000000ffff0000)
          `uvm_fatal("RESET", "reset did not restore the reset state")
        if (tr.fault)
          `uvm_fatal("RESET", "reset left the diagnostic fault sticky")
      end
      set_signal(1, 0);
      completed++;

      // Undefined opcode 60h and undocumented MOV CS fail explicitly.
      for (int scenario = 0; scenario < 2; scenario++) begin
        if (scenario == 0) program_bytes(20'h10000, '{8'h60, 8'h90});
        else program_bytes(20'h10000, '{8'h8e, 8'hc8});
        boot();
        instruction(scenario == 0 ? 16'h0001 : 16'h0002, 0, 1);
        repeat (10) tick();
        completed++;
      end

      // The four-byte queue fills during a busy WAIT; a taken jump flushes
      // stale bytes so the modified byte executes only after the flush.
      program_bytes(20'h10000, '{8'h90, 8'h9b, 8'h90, 8'heb, 8'hfd, 8'h90, 8'h90, 8'h90, 8'h90});
      boot();
      instruction(1);
      set_signal(0, 0, 0, 0, 1, 1);
      begin
        intel_8088_item tr = intel_8088_item::type_id::create("queuefill");
        start_item(tr);
        tr.wait_queue = 1; tr.queue_target = 4;
        finish_item(tr);
        if (tr.timed_out) `uvm_fatal("QUEUE", "four-byte queue did not fill during WAIT")
      end
      program_bytes(20'h10002, '{8'hf4});
      set_signal(0, 0, 0, 0, 1, 0);
      instruction(2);
      instruction(3);
      instruction(2);
      instruction(3, 1);
      completed++;

      // Byte I/O through the 8-bit bus: OUT then IN loop back through the
      // port model, exercising the IO/M polarity in both directions.
      program_bytes(20'h10000, '{8'hb0, 8'h34, 8'he7, 8'h21, 8'he5, 8'h21, 8'hf4});
      boot();
      instruction(2, 0, 0, 0, 16'h0034);
      instruction(4);
      instruction(6, 0, 0, 0, 16'h0034);
      instruction(7, 1);
      completed++;

      // HOLD is honored at the idle boundary and floats every pin.
      program_bytes(20'h10000, '{8'hf4});
      boot();
      instruction(1, 1);
      set_signal(0, 0, 1, 1);
      tick(8);
      begin
        intel_8088_item tr = intel_8088_item::type_id::create("hold");
        start_item(tr);
        tr.sample_only = 1;
        finish_item(tr);
        if (!tr.hlda) `uvm_fatal("HOLD", "HLDA not asserted while held")
      end
      set_signal(0, 0, 1, 0);
      tick(8);
      begin
        intel_8088_item tr = intel_8088_item::type_id::create("holdrel");
        start_item(tr);
        tr.sample_only = 1;
        finish_item(tr);
        if (tr.hlda) `uvm_fatal("HOLD", "HLDA stuck after release")
      end
      completed++;
    endtask
  endclass

  class intel_8088_control_test extends uvm_test;
    `uvm_component_utils(intel_8088_control_test)
    uvm_sequencer #(intel_8088_item) sequencer;
    intel_8088_driver driver;
    intel_8088_scoreboard scoreboard;
    intel_8088_coverage coverage;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = new("sequencer", this);
      driver = intel_8088_driver::type_id::create("driver", this);
      scoreboard = intel_8088_scoreboard::type_id::create("scoreboard", this);
      coverage = intel_8088_coverage::type_id::create("coverage", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.observed.connect(scoreboard.analysis_export);
      driver.observed.connect(coverage.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
      intel_8088_control_seq sequence_inst;
      phase.raise_objection(this);
      sequence_inst = intel_8088_control_seq::type_id::create("sequence_inst");
      sequence_inst.start(sequencer);
      if (sequence_inst.completed != 11 || coverage.reached !== 10'h3ef ||
          scoreboard.snapshots < 200)
        `uvm_fatal("COVERAGE", $sformatf(
          "required scenarios/control observations absent: completed=%0d reached=%h snapshots=%0d",
          sequence_inst.completed, coverage.reached, scoreboard.snapshots))
      if (uvm_report_server::get_server().get_severity_count(
              UVM_ERROR
          ) != 0 || uvm_report_server::get_server().get_severity_count(
              UVM_FATAL
          ) != 0)
        `uvm_fatal("RESULT", "scoreboard reported failures")
      `uvm_info("RESULT", "TEST PASSED: 11 UVM 8088 control/boundary scenarios; 0 failures",
                UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage
