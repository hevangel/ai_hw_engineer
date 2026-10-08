`timescale 1ns/1ps
module tb_software;
  logic clk=0, rst_n=0, ready=1;
  logic req, write_en, io, intack, inte, hlda, halted, retire, fault;
  logic [15:0] addr, pc, sp;
  logic [7:0] wdata, rdata, status, flags;
  logic [55:0] regs;
  logic [7:0] memory [0:65535];
  string prefix, memfile, tracefile, consolefile;
  int trace_fd, console_fd, parsed, checked=0, writes=0, outs=0;
  logic [15:0] actual_addr [0:1];
  logic [7:0] actual_data [0:1], actual_port, actual_out;
  logic initialized=0;
  logic [15:0] before_pc, expected_pc, expected_sp, wa0, wa1;
  logic [7:0] opcode, expected_flags, wd0, wd1, expected_port, expected_out, next_opcode;
  logic [55:0] expected_regs;
  logic expected_inte, expected_halted, mask;
  int expected_writes, expected_outs;
  logic unit_mode=0;
  int unit_cases=0, rows_remaining=0, unit_id, unit_variant, patch_count;
  logic [7:0] unit_opcode, patch_data;
  logic [15:0] patch_address;
  logic opcode_seen [0:255];
  intel_8080 dut (.clk(clk), .rst_n(rst_n), .bus_ready_i(ready), .bus_rdata_i(rdata),
      .int_i(1'b0), .hold_i(1'b0), .bus_req_o(req), .bus_write_o(write_en),
      .bus_io_o(io), .bus_intack_o(intack), .bus_addr_o(addr), .bus_wdata_o(wdata),
      .bus_status_o(status), .inte_o(inte), .hlda_o(hlda), .halted_o(halted),
      .retire_o(retire), .fault_o(fault), .pc_o(pc), .sp_o(sp), .regs_o(regs), .flags_o(flags));
  always_comb rdata = io ? addr[7:0]^8'h5a : memory[addr];

  task automatic load_expected;
    parsed=$fscanf(trace_fd,"%h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
      before_pc,opcode,expected_pc,expected_sp,expected_regs,expected_flags,
      expected_inte,expected_halted,expected_writes,wa0,wd0,wa1,wd1,
      expected_outs,expected_port,expected_out,next_opcode,mask);
    if (parsed!=18) $fatal(1,"missing/malformed independent trace at instruction %0d",checked);
  endtask
  task automatic load_unit;
    parsed=$fscanf(trace_fd,"%d %h %d %d %d\n",unit_id,unit_opcode,unit_variant,patch_count,rows_remaining);
    if (parsed!=5) begin
      if (unit_cases!=7808) $fatal(1,"incomplete unit cases: %0d",unit_cases);
      for (int code=0;code<256;code++) begin
        case (code)
          'h08,'h10,'h18,'h20,'h28,'h30,'h38,'hcb,'hd9,'hdd,'hed,'hfd: ;
          default: if (!opcode_seen[code]) $fatal(1,"missing opcode %h",8'(code));
        endcase
      end
      $display("TEST PASSED: %0d cases, all 244 documented opcodes, %0d exact retirement/next-instruction/effect checks; 0 failures",unit_cases,checked);
      $finish;
    end else begin
      if (unit_id!=unit_cases || unit_variant<0 || unit_variant>=32 || rows_remaining<8)
        $fatal(1,"invalid unit header");
      opcode_seen[unit_opcode]=1;
      foreach (memory[index]) memory[index]=8'h76;
      repeat (patch_count) begin
        parsed=$fscanf(trace_fd,"%h %h\n",patch_address,patch_data);
        if (parsed!=2) $fatal(1,"malformed memory patch");
        memory[patch_address]=patch_data;
      end
      load_expected();
    end
  endtask
  task automatic check_retirement;
    if (pc !== expected_pc || inte !== expected_inte || halted !== expected_halted)
      $fatal(1,"control mismatch #%0d at %h op=%h pc=%h expected=%h",checked,before_pc,opcode,pc,expected_pc);
    if (mask && (sp !== expected_sp || regs !== expected_regs || flags !== expected_flags))
      $fatal(1,"state mismatch #%0d at %h op=%h regs=%h/%h flags=%h/%h sp=%h/%h",
             checked,before_pc,opcode,regs,expected_regs,flags,expected_flags,sp,expected_sp);
    if (writes!=expected_writes || outs!=expected_outs) $fatal(1,"effect count mismatch");
    if (writes==1 && (actual_addr[0]!==wa0 || actual_data[0]!==wd0)) $fatal(1,"single write mismatch");
    if (writes==2 && !(
        (actual_addr[0]===wa0 && actual_data[0]===wd0 && actual_addr[1]===wa1 && actual_data[1]===wd1) ||
        (actual_addr[0]===wa1 && actual_data[0]===wd1 && actual_addr[1]===wa0 && actual_data[1]===wd0)))
      $fatal(1,"two-write mismatch");
    if (outs!=0 && (actual_port!==expected_port || actual_out!==expected_out)) $fatal(1,"I/O write mismatch");
    // Assert exact next-PC contents; the next fetch is checked separately below.
    if (!(outs!=0 && actual_port==0) && memory[expected_pc]!==next_opcode) $fatal(1,"next opcode memory mismatch");
    checked++;
    writes=0; outs=0;
    if (unit_mode) begin
      rows_remaining--;
      if (rows_remaining==0) begin
        unit_cases++; rst_n=0;
        repeat (3) begin #5; clk=1; #5; clk=0; end
        load_unit(); rst_n=1;
      end else load_expected();
    end else if (expected_outs!=0 && expected_port==0) begin
      if (!$feof(trace_fd)) begin
        // fscanf has consumed trailing whitespace; reject any additional trace.
        automatic int trailing;
        trailing=$fgetc(trace_fd);
        if (trailing!=-1) $fatal(1,"unconsumed oracle trace");
      end
      $fclose(console_fd); $fclose(trace_fd);
      $display("TEST PASSED: historical software %s, %0d exact retirement/next-PC/effect checks; 0 failures",prefix,checked);
      $finish;
    end else load_expected();
  endtask

  initial begin
    if ($value$plusargs("UNITFILE=%s",tracefile)) begin
      unit_mode=1; trace_fd=$fopen(tracefile,"r"); console_fd=0;
      if (trace_fd==0) $fatal(1,"cannot open unit bundle");
      foreach (opcode_seen[index]) opcode_seen[index]=0;
      load_unit();
    end else begin
      if (!$value$plusargs("PREFIX=%s",prefix)) $fatal(1,"PREFIX required");
      memfile={prefix,".mem"}; tracefile={prefix,".trace"}; consolefile={prefix,".rtl-console"};
      $readmemh(memfile,memory);
      trace_fd=$fopen(tracefile,"r"); console_fd=$fopen(consolefile,"w");
      if (trace_fd==0 || console_fd==0) $fatal(1,"cannot open trace/output");
      load_expected();
    end
    repeat (3) begin #5; clk=1; #5; clk=0; end
    rst_n=1;
    forever begin
      // READY stalls on a reproducible schedule also exercise real-code waits.
      ready=1'(checked%7!=3) || clk;
      // An occasional one-step stall, not a permanently blocked instruction.
      if (checked%7==3 && req) begin
        ready=0; #5; clk=1; #5; clk=0; ready=1;
      end
      if (fault || hlda || intack || halted)
        $fatal(1,"unexpected control unit=%0d test=%h variant=%0d expected fetch=%h/%h pc=%h fault=%b halt=%b rows=%0d",
               unit_id,unit_opcode,unit_variant,before_pc,opcode,pc,fault,halted,rows_remaining);
      if (req && status==8'ha2) begin
        if (addr!==before_pc || memory[addr]!==opcode) $fatal(1,"exact next fetch mismatch");
        if (!unit_mode && addr==16'h0100 && !initialized) begin
          memory[0]=8'hd3; memory[1]=0; initialized=1;
        end
      end
      if (req && write_en) begin
        if (io) begin
          outs++; actual_port=addr[7:0]; actual_out=wdata;
          if (!unit_mode && addr[7:0]==1 && regs[39:32]==2) $fwrite(console_fd,"%c",regs[23:16]);
          if (!unit_mode && addr[7:0]==1 && regs[39:32]==9) begin
            automatic logic [15:0] string_addr=regs[31:16];
            automatic int guard=0;
            while (memory[string_addr]!=8'h24) begin
              if (++guard>65536) $fatal(1,"unterminated BDOS string");
              $fwrite(console_fd,"%c",memory[string_addr]); string_addr++;
            end
          end
        end else begin
          if (writes>=2) $fatal(1,"excess writes in instruction");
          actual_addr[writes]=addr; actual_data[writes]=wdata; writes++;
          memory[addr]=wdata;
        end
      end
      #5; clk=1; #5; clk=0;
      if (retire) check_retirement();
    end
  end
  initial begin #200000000; $fatal(1,"software watchdog expired"); end
endmodule
