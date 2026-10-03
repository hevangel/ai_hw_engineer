`timescale 1ns/1ps
package amd_am9080_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class amd_am9080_item extends uvm_sequence_item;
    `uvm_object_utils(amd_am9080_item)
    bit step=1;
    logic rst_n=1, ready=1, int_req=0, hold_req=0;
    logic [7:0] rdata=0;
    logic pre_req, pre_write, pre_io, pre_intack;
    logic [15:0] pre_addr, pre_pc, pre_sp;
    logic [7:0] pre_wdata, pre_status, pre_flags;
    logic [55:0] pre_regs;
    logic req, write_en, io, intack, inte, hlda, halted, retire, fault;
    logic [15:0] addr, pc, sp;
    logic [7:0] wdata, status, flags;
    logic [55:0] regs;
    bit [7:0] check_mask=0;
    logic [15:0] expected_pc, expected_sp;
    logic [7:0] expected_a, expected_flags;
    logic expected_inte=0, expected_halt=0, expected_hold=0, expected_fault=0;
    bit check_regs=0;
    bit check_irq_status=0;
    logic [7:0] expected_irq_status;
    logic [55:0] expected_regs;
    function new(string name="amd_am9080_item"); super.new(name); endfunction
  endclass

  class amd_am9080_driver extends uvm_driver #(amd_am9080_item);
    `uvm_component_utils(amd_am9080_driver)
    virtual amd_am9080_if vif;
    uvm_analysis_port #(amd_am9080_item) observed;
    function new(string name, uvm_component parent); super.new(name,parent); observed=new("observed",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual amd_am9080_if)::get(this,"","vif",vif))
        `uvm_fatal("VIF","missing virtual interface")
    endfunction
    function void snapshot(amd_am9080_item tr);
      tr.req=vif.req; tr.write_en=vif.write_en; tr.io=vif.io; tr.intack=vif.intack;
      tr.addr=vif.addr; tr.wdata=vif.wdata; tr.status=vif.status;
      tr.pc=vif.pc; tr.sp=vif.sp; tr.regs=vif.regs; tr.flags=vif.flags;
      tr.inte=vif.inte; tr.hlda=vif.hlda; tr.halted=vif.halted; tr.retire=vif.retire; tr.fault=vif.fault;
    endfunction
    task run_phase(uvm_phase phase);
      amd_am9080_item tr;
      forever begin
        seq_item_port.get_next_item(tr);
        if (tr.step) begin
          @(negedge vif.clk);
          vif.rst_n=tr.rst_n; vif.ready=tr.ready; vif.int_req=tr.int_req;
          vif.hold_req=tr.hold_req; vif.rdata=tr.rdata;
          #1;
          tr.pre_req=vif.req; tr.pre_write=vif.write_en; tr.pre_io=vif.io; tr.pre_intack=vif.intack;
          tr.pre_addr=vif.addr; tr.pre_wdata=vif.wdata; tr.pre_status=vif.status;
          tr.pre_pc=vif.pc; tr.pre_sp=vif.sp; tr.pre_regs=vif.regs; tr.pre_flags=vif.flags;
          @(posedge vif.clk); #1;
        end
        snapshot(tr);
        observed.write(tr);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class amd_am9080_scoreboard extends uvm_subscriber #(amd_am9080_item);
    `uvm_component_utils(amd_am9080_scoreboard)
    int checks=0, steps=0, transfers=0;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void write(amd_am9080_item tr);
      if (tr.step) begin
        steps++;
        if (tr.pre_req && tr.ready) transfers++;
        if (tr.check_irq_status && tr.pre_req && tr.pre_intack && tr.ready &&
            tr.pre_status!==tr.expected_irq_status)
          `uvm_error("IRQSTATUS","interrupt/HALT/NULL status mismatch")
        if (tr.pre_req && !tr.ready && tr.rst_n) begin
          if (!tr.req || {tr.addr,tr.wdata,tr.status,tr.write_en,tr.io,tr.intack} !==
              {tr.pre_addr,tr.pre_wdata,tr.pre_status,tr.pre_write,tr.pre_io,tr.pre_intack} ||
              {tr.pc,tr.sp,tr.regs,tr.flags} !== {tr.pre_pc,tr.pre_sp,tr.pre_regs,tr.pre_flags} || tr.retire)
            `uvm_error("WAIT","stalled transaction or architecture changed")
        end
        if ((tr.hlda || tr.fault || !tr.rst_n) && tr.req) `uvm_error("BUS","bus driven during hold/fault/reset")
        if (tr.req && tr.io && tr.addr[15:8]!==tr.addr[7:0]) `uvm_error("PORT","I/O address not replicated")
        if (tr.req && tr.intack && (tr.write_en || tr.io || !(tr.status==8'h23 || tr.status==8'h2b || tr.status==8'h02)))
          `uvm_error("IRQ","invalid acknowledge/NULL transaction")
      end
      if (tr.check_mask!=0 || tr.check_regs) begin
        checks++;
        if (tr.check_mask[0] && tr.pc!==tr.expected_pc) `uvm_error("PC",$sformatf("PC %h expected %h",tr.pc,tr.expected_pc))
        if (tr.check_mask[1] && tr.sp!==tr.expected_sp) `uvm_error("SP","stack pointer mismatch")
        if (tr.check_mask[2] && tr.regs[55:48]!==tr.expected_a) `uvm_error("A","accumulator mismatch")
        if (tr.check_mask[3] && tr.flags!==tr.expected_flags) `uvm_error("FLAGS","status flags mismatch")
        if (tr.check_mask[4] && tr.inte!==tr.expected_inte) `uvm_error("INTE","interrupt enable mismatch")
        if (tr.check_mask[5] && tr.halted!==tr.expected_halt) `uvm_error("HALT","halt state mismatch")
        if (tr.check_mask[6] && tr.hlda!==tr.expected_hold) `uvm_error("HOLD","hold acknowledgement mismatch")
        if (tr.check_mask[7] && tr.fault!==tr.expected_fault) `uvm_error("FAULT","validity fault mismatch")
        if (tr.check_regs && tr.regs!==tr.expected_regs) `uvm_error("REGS","general register reset/retention mismatch")
      end
    endfunction
    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("COUNTS",$sformatf("%0d independent control snapshots, %0d clock steps, %0d transfers",checks,steps,transfers),UVM_LOW)
    endfunction
  endclass

  class amd_am9080_coverage extends uvm_subscriber #(amd_am9080_item);
    `uvm_component_utils(amd_am9080_coverage)
    bit wait_seen, hold_seen, halt_seen, irq_seen, fault_seen, io_seen;
    bit [5:0] reached=0;
    covergroup control_cg;
      option.per_instance=1;
      coverpoint wait_seen; coverpoint hold_seen; coverpoint halt_seen;
      coverpoint irq_seen; coverpoint fault_seen; coverpoint io_seen;
    endgroup
    function new(string name, uvm_component parent); super.new(name,parent); control_cg=new(); endfunction
    function void write(amd_am9080_item tr);
      if (tr.step && tr.rst_n) begin
        wait_seen=tr.pre_req && !tr.ready; hold_seen=tr.hlda; halt_seen=tr.halted;
        irq_seen=tr.pre_req && tr.pre_intack && tr.ready; fault_seen=tr.fault;
        io_seen=tr.pre_req && tr.pre_io && tr.ready;
        reached |= {io_seen,fault_seen,irq_seen,halt_seen,hold_seen,wait_seen};
        control_cg.sample();
      end
    endfunction
  endclass

  class amd_am9080_control_seq extends uvm_sequence #(amd_am9080_item);
    `uvm_object_utils(amd_am9080_control_seq)
    logic [7:0] memory [0:65535];
    logic [7:0] irq_bytes [0:2];
    int irq_index=0, completed_scenarios=0;
    bit req_int=0, req_hold=0, req_ready=1;
    bit irq_expect_halted=0;
    amd_am9080_item last;
    function new(string name="amd_am9080_control_seq"); super.new(name); endfunction
    task tick(input bit reset_n=1);
      amd_am9080_item tr=amd_am9080_item::type_id::create("step");
      start_item(tr);
      tr.rst_n=reset_n; tr.ready=req_ready; tr.int_req=req_int; tr.hold_req=req_hold;
      tr.rdata=0;
      if (last!=null && last.req) begin
        if (last.intack) begin
          if (irq_index>=3) `uvm_fatal("IRQ","too many injected bytes")
          tr.rdata=irq_bytes[irq_index];
          tr.check_irq_status=1;
          tr.expected_irq_status=irq_index==0 ? (irq_expect_halted ? 8'h2b : 8'h23) : 8'h02;
        end else if (last.io) tr.rdata=last.addr[7:0]^8'h5a;
        else tr.rdata=memory[last.addr];
      end
      finish_item(tr);
      if (tr.pre_req && tr.ready && reset_n) begin
        if (tr.pre_intack) irq_index++;
        if (tr.pre_write && !tr.pre_io) memory[tr.pre_addr]=tr.pre_wdata;
      end
      last=tr;
    endtask
    task check(input bit [7:0] mask, input logic [15:0] pc_value,
               input logic [15:0] sp_value=16'h9000, input logic [7:0] a_value=8'h5a,
               input bit enable=0, input bit halt_value=0, input bit hold_value=0, input bit fault_value=0,
               input bit all_regs=0);
      amd_am9080_item tr=amd_am9080_item::type_id::create("check");
      start_item(tr); tr.step=0;
      tr.check_mask=mask; tr.expected_pc=pc_value; tr.expected_sp=sp_value;
      tr.expected_a=a_value; tr.expected_flags=8'h02; tr.expected_inte=enable;
      tr.expected_halt=halt_value; tr.expected_hold=hold_value; tr.expected_fault=fault_value;
      tr.check_regs=all_regs; tr.expected_regs=56'h5a123456789abc;
      finish_item(tr);
    endtask
    task wait_retire(input logic [15:0] expected_pc);
      bit found=0;
      for (int count=0;count<100 && !found;count++) begin tick(); found=last.retire; end
      if (!found || last.fault) `uvm_fatal("TIMEOUT","instruction did not retire")
      check(8'h01,expected_pc);
    endtask
    task reset_chip;
      req_int=0; req_hold=0; req_ready=1; irq_index=0;
      irq_expect_halted=0;
      repeat (3) tick(0);
    endtask
    task setup_program;
      foreach (memory[index]) memory[index]=8'h76;
      memory[0]=8'h31; memory[1]=0; memory[2]=8'h80; memory[3]=8'hf1;
      memory[4]=8'h01; memory[5]=8'h34; memory[6]=8'h12;
      memory[7]=8'h11; memory[8]=8'h78; memory[9]=8'h56;
      memory[10]=8'h21; memory[11]=8'hbc; memory[12]=8'h9a;
      memory[13]=8'h31; memory[14]=0; memory[15]=8'h90;
      memory[16]=8'hfb; memory[17]=0; memory[18]=8'h76;
      memory[19]=8'hd3; memory[20]=8'h55; memory[21]=8'hdb; memory[22]=8'haa; memory[23]=8'h76;
      memory[16'h8000]=8'h02; memory[16'h8001]=8'h5a; memory[16'h4000]=8'hc9;
    endtask
    task initialize_through_ei;
      wait_retire(3); wait_retire(4); wait_retire(7); wait_retire(10);
      wait_retire(13); wait_retire(16); wait_retire(17);
      check(8'hff,17,16'h9000,8'h5a,1,0,0,0,1);
    endtask
    task wait_fault(input logic [15:0] expected_pc);
      bit found=0;
      for (int count=0;count<50 && !found;count++) begin tick(); found=last.fault; end
      if (!found) `uvm_fatal("TIMEOUT","expected validity fault not raised")
      check(8'hff,expected_pc,16'h9000,8'h5a,0,0,0,1,1);
      repeat (3) tick();
    endtask
    task body;
      setup_program(); reset_chip();
      req_ready=0; tick();
      req_hold=1;
      repeat (3) begin tick(); check(8'hd1,0,0,0,0,0,0,0); end
      req_ready=1; tick(); check(8'hd1,1,0,0,0,0,1,0);
      repeat (6) begin tick(); check(8'hd1,1,0,0,0,0,1,0); end
      req_hold=0; tick(); check(8'hd1,1,0,0,0,0,0,0);
      initialize_through_ei();
      memory[8]=8'hc9; irq_bytes[0]=8'hcf; req_int=1;
      wait_retire(18); check(8'hff,18,16'h9000,8'h5a,1);
      wait_retire(8); req_int=0;
      check(8'hff,8,16'h8ffe);
      if (irq_index!=1 || memory[16'h8ffe]!==8'h12 || memory[16'h8fff]!==0)
        `uvm_error("RST","wrong interrupt byte count or pushed return PC")
      wait_retire(18); wait_retire(19);
      check(8'hff,19,16'h9000,8'h5a,0,1);
      req_int=1;
      repeat (6) begin tick(); check(8'hff,19,16'h9000,8'h5a,0,1); end
      req_hold=1; repeat (3) tick(); check(8'hff,19,16'h9000,8'h5a,0,1,1);
      req_hold=0; repeat (2) tick(); check(8'hff,19,16'h9000,8'h5a,0,1);
      completed_scenarios++;

      reset_chip(); check(8'hff,0,16'h9000,8'h5a,0,0,0,0,1);
      setup_program(); initialize_through_ei(); wait_retire(18); wait_retire(19);
      check(8'hff,19,16'h9000,8'h5a,1,1);
      irq_bytes[0]=8'hcd; irq_bytes[1]=0; irq_bytes[2]=8'h40;
      irq_expect_halted=1;
      req_hold=1; req_int=1;
      repeat (4) begin tick(); check(8'hff,19,16'h9000,8'h5a,1,1,1); end
      if (irq_index!=0) `uvm_error("HOLDIRQ","interrupt accepted during HOLD")
      req_hold=0; tick(); req_ready=0;
      repeat (4) tick(); req_ready=1;
      wait_retire(16'h4000); req_int=0;
      check(8'hff,16'h4000,16'h8ffe);
      if (irq_index!=3 || memory[16'h8ffe]!==8'h13 || memory[16'h8fff]!==0)
        `uvm_error("CALL","injected CALL did not preserve unincremented PC")
      // Actual manufacturer's ISR skeleton, handbook 15-2 / PDF 301:
      // PUSH PSW,B,D,H; POP H,D,B,PSW; EI; RET (Figure 15-3 exit).
      memory[16'h4000]=8'hf5; memory[16'h4001]=8'hc5;
      memory[16'h4002]=8'hd5; memory[16'h4003]=8'he5;
      memory[16'h4004]=8'he1; memory[16'h4005]=8'hd1;
      memory[16'h4006]=8'hc1; memory[16'h4007]=8'hf1;
      memory[16'h4008]=8'hfb; memory[16'h4009]=8'hc9;
      for (int instruction=1;instruction<=8;instruction++) wait_retire(16'h4000+16'(instruction));
      req_int=1; // Pending request must not preempt the real EI/RET return.
      wait_retire(16'h4009); check(8'hff,16'h4009,16'h8ffe,8'h5a,1,0,0,0,1);
      wait_retire(19); req_int=0;
      check(8'hff,19,16'h9000,8'h5a,1,0,0,0,1);
      wait_retire(21); check(8'hff,21,16'h9000,8'h5a,1);
      wait_retire(23); check(8'hff,23,16'h9000,8'hf0,1);
      wait_retire(24); check(8'hff,24,16'h9000,8'hf0,1,1);
      completed_scenarios++;

      reset_chip(); setup_program(); initialize_through_ei();
      irq_bytes[0]=8'he3; req_int=1; wait_retire(18); wait_fault(18);
      completed_scenarios++;
      for (int code=0;code<256;code++) begin
        case (code)
          'h08,'h10,'h18,'h20,'h28,'h30,'h38,'hcb,'hd9,'hdd,'hed,'hfd: begin
            reset_chip(); check(8'hff,0,16'h9000,8'h5a,0,0,0,0,1);
            memory[0]=8'(code); wait_fault(1); completed_scenarios++;
          end
          default: ;
        endcase
      end
      if (completed_scenarios!=15) `uvm_fatal("COUNT","missing control/fault scenarios")
    endtask
  endclass

  class amd_am9080_control_test extends uvm_test;
    `uvm_component_utils(amd_am9080_control_test)
    uvm_sequencer #(amd_am9080_item) sequencer;
    amd_am9080_driver driver;
    amd_am9080_scoreboard scoreboard;
    amd_am9080_coverage coverage;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer=new("sequencer",this); driver=amd_am9080_driver::type_id::create("driver",this);
      scoreboard=amd_am9080_scoreboard::type_id::create("scoreboard",this);
      coverage=amd_am9080_coverage::type_id::create("coverage",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.observed.connect(scoreboard.analysis_export); driver.observed.connect(coverage.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
      amd_am9080_control_seq sequence_test=amd_am9080_control_seq::type_id::create("sequence_test");
      phase.raise_objection(this);
      sequence_test.start(sequencer);
      if (scoreboard.checks<50 || coverage.reached!=6'b111111) `uvm_fatal("COVERAGE","incomplete control checks")
      phase.drop_objection(this);
    endtask
    function void report_phase(uvm_phase phase);
      uvm_report_server server=uvm_report_server::get_server();
      super.report_phase(phase);
      if (server.get_severity_count(UVM_ERROR)!=0 || server.get_severity_count(UVM_FATAL)!=0)
        `uvm_fatal("RESULT","control regression failed")
      `uvm_info("RESULT","TEST PASSED: 15 UVM control/fault scenarios; 0 failures",UVM_NONE)
    endfunction
  endclass
endpackage
