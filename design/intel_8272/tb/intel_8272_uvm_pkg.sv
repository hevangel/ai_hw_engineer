package intel_8272_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `uvm_analysis_imp_decl(_expected)
    `uvm_analysis_imp_decl(_actual)
    typedef enum {STARTUP,CPU_PUT,CPU_GET,HEADER,DISK_BYTE,DISK_END,INDEX,
        DATA_GET,DATA_PUT,WRITE_SLOT,WAIT_CYCLES} action_t;
    class intel_8272_item extends uvm_sequence_item;
        `uvm_object_utils(intel_8272_item)
        action_t action;
        bit [7:0] value, cc=3, hh=0, rr=1, nn=0;
        bit terminal, command_start, non_dma, deleted;
        int cycles=4;
        function new(string name="intel_8272_item"); super.new(name); endfunction
    endclass
    class intel_8272_driver extends uvm_driver #(intel_8272_item);
        `uvm_component_utils(intel_8272_driver)
        virtual intel_8272_if vif;
        uvm_analysis_port #(intel_8272_item) expected, commands;
        function new(string name,uvm_component parent);
            super.new(name,parent); expected=new("expected",this); commands=new("commands",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual intel_8272_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","missing interface")
        endfunction
        task run_phase(uvm_phase phase);
            logic [7:0] observed;
            forever begin
                seq_item_port.get_next_item(req);
                if (req.action==CPU_GET || req.action==DATA_GET) expected.write(req);
                if (req.command_start) commands.write(req);
                case (req.action)
                    STARTUP: begin vif.startup(req.non_dma); vif.monitor_enable=1; end
                    CPU_PUT: vif.cpu_put(req.value);
                    CPU_GET: vif.cpu_get(observed);
                    HEADER: vif.header(req.cc,req.hh,req.rr,req.nn,req.deleted);
                    DISK_BYTE: vif.disk_byte(req.value);
                    DISK_END: vif.disk_end();
                    INDEX: vif.index_event();
                    DATA_GET: vif.data_get(observed,req.non_dma,req.terminal);
                    DATA_PUT: vif.data_put(req.value,req.non_dma,req.terminal);
                    WRITE_SLOT: begin
                        vif.disk_write(observed);
                        // Standalone regression checks write data; UVM observes host reads.
                    end
                    WAIT_CYCLES: vif.tick(req.cycles);
                endcase
                seq_item_port.item_done();
            end
        endtask
    endclass
    class intel_8272_monitor extends uvm_component;
        `uvm_component_utils(intel_8272_monitor)
        virtual intel_8272_if vif;
        uvm_analysis_port #(intel_8272_item) actual;
        bit old_read=1;
        function new(string name,uvm_component parent);
            super.new(name,parent); actual=new("actual",this);
        endfunction
        function void build_phase(uvm_phase phase);
            if (!uvm_config_db #(virtual intel_8272_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","missing interface")
        endfunction
        task run_phase(uvm_phase phase);
            intel_8272_item observation;
            forever begin
                @(posedge vif.clk);
                if (vif.monitor_enable && old_read && !vif.rd_n &&
                    ((!vif.cs_n && vif.a0) || (vif.cs_n && !vif.dack_n))) begin
                    observation=intel_8272_item::type_id::create("observation");
                    observation.value=vif.db_out; actual.write(observation);
                end
                old_read=vif.rd_n;
            end
        endtask
    endclass
    class intel_8272_scoreboard extends uvm_component;
        `uvm_component_utils(intel_8272_scoreboard)
        uvm_analysis_imp_expected #(intel_8272_item,intel_8272_scoreboard) expected;
        uvm_analysis_imp_actual #(intel_8272_item,intel_8272_scoreboard) actual;
        bit [7:0] queue[$]; int matched=0;
        function new(string name,uvm_component parent);
            super.new(name,parent); expected=new("expected",this); actual=new("actual",this);
        endfunction
        function void write_expected(intel_8272_item item); queue.push_back(item.value); endfunction
        function void write_actual(intel_8272_item item);
            bit [7:0] want;
            if (queue.size()==0) `uvm_error("SCORE","unexpected read")
            else begin
                want=queue.pop_front();
                if (item.value!==want) `uvm_error("SCORE",$sformatf("expected %02x got %02x",want,item.value))
                else matched++;
            end
        endfunction
        function void check_phase(uvm_phase phase);
            if (queue.size()!=0 || matched!=203) `uvm_error("SCORE",$sformatf("matched=%0d remaining=%0d",matched,queue.size()))
            else `uvm_info("SCORE",$sformatf("8272 UVM SCOREBOARD PASSED reads=%0d",matched),UVM_LOW)
        endfunction
    endclass
    class intel_8272_coverage extends uvm_subscriber #(intel_8272_item);
        `uvm_component_utils(intel_8272_coverage)
        bit [4:0] opcode;
        covergroup command_cg;
            option.per_instance=1;
            commands: coverpoint opcode {
                bins supported[]={5'h02,5'h03,5'h04,5'h05,5'h06,5'h07,5'h08,
                    5'h09,5'h0a,5'h0c,5'h0d,5'h0f,5'h11,5'h19,5'h1d};
            }
        endgroup
        function new(string name,uvm_component parent);
            super.new(name,parent); command_cg=new();
        endfunction
        function void write(intel_8272_item item); opcode=item.value[4:0]; command_cg.sample(); endfunction
        function void report_phase(uvm_phase phase);
            `uvm_info("COVER",$sformatf("8272 command coverage %0.2f%%",command_cg.get_inst_coverage()),UVM_LOW)
        endfunction
    endclass
    class intel_8272_sequence extends uvm_sequence #(intel_8272_item);
        `uvm_object_utils(intel_8272_sequence)
        bit non_dma=1;
        function new(string name="intel_8272_sequence"); super.new(name); endfunction
        task send(input action_t action,input bit [7:0] value=0,
            input bit terminal=0,command_start=0);
            intel_8272_item item;
            item=intel_8272_item::type_id::create("item"); start_item(item);
            item.action=action; item.value=value; item.terminal=terminal;
            item.command_start=command_start; item.non_dma=non_dma;
            finish_item(item);
        endtask
        task cmd(input bit [7:0] opcode,input bit [7:0] tail=0);
            send(CPU_PUT,opcode,0,1); send(CPU_PUT,0); send(CPU_PUT,3); send(CPU_PUT,0);
            send(CPU_PUT,1); send(CPU_PUT,0); send(CPU_PUT,1); send(CPU_PUT,8'h1b); send(CPU_PUT,tail);
            send(WAIT_CYCLES);
        endtask
        task result(input bit [7:0] s0=0,s1=0,s2=0,cc=4,hh=0,rr=1,nn=0);
            send(CPU_GET,s0); send(CPU_GET,s1); send(CPU_GET,s2); send(CPU_GET,cc);
            send(CPU_GET,hh); send(CPU_GET,rr); send(CPU_GET,nn); send(WAIT_CYCLES);
        endtask
        task body;
            send(STARTUP);
            send(CPU_PUT,3,0,1); send(CPU_PUT,8'hf1); send(CPU_PUT,1); send(WAIT_CYCLES);
            send(CPU_PUT,4,0,1); send(CPU_PUT,0); send(CPU_GET,8'h38); send(WAIT_CYCLES);
            send(CPU_PUT,8'h4a,0,1); send(CPU_PUT,0); send(WAIT_CYCLES); send(HEADER);
            result(0,0,0,3,0,1,0);
            cmd(8'h46); send(HEADER);
            for (int k=0;k<128;k++) begin send(DISK_BYTE,8'(k^8'ha5)); send(DATA_GET,8'(k^8'ha5),k==127); end
            send(DISK_END); result();
            // Other data commands are real commands, terminated by missing headers.
            foreach_opcode();
            send(CPU_PUT,8'h0f,0,1); send(CPU_PUT,0); send(CPU_PUT,0); send(WAIT_CYCLES);
            send(CPU_PUT,8,0,1); send(CPU_GET,8'h20); send(CPU_GET,0); send(WAIT_CYCLES);
            send(CPU_PUT,7,0,1); send(CPU_PUT,0); send(WAIT_CYCLES);
            send(CPU_PUT,8,0,1); send(CPU_GET,8'h20); send(CPU_GET,0); send(WAIT_CYCLES);
        endtask
        task foreach_opcode;
            bit [7:0] ops[7]='{8'h45,8'h49,8'h4c,8'h51,8'h59,8'h5d,8'h42};
            for (int k=0;k<7;k++) begin
                cmd(ops[k],1); if (ops[k]==8'h42) send(INDEX);
                send(INDEX); send(INDEX); result(8'h40,5,0,3,0,1,0);
            end
            send(CPU_PUT,8'h4d,0,1); send(CPU_PUT,0); send(CPU_PUT,0); send(CPU_PUT,0);
            send(CPU_PUT,8'h1b); send(CPU_PUT,8'he5); send(WAIT_CYCLES); send(INDEX); send(INDEX);
            // SC=0 has no sector IDs; the retained command bytes are not meaningful.
            result(0,0,0,0,0,8'h1c,0);
        endtask
    endclass
    class intel_8272_test extends uvm_test;
        `uvm_component_utils(intel_8272_test)
        intel_8272_driver driver;
        intel_8272_monitor monitor;
        intel_8272_scoreboard scoreboard;
        intel_8272_coverage coverage;
        uvm_sequencer #(intel_8272_item) sequencer;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            driver=intel_8272_driver::type_id::create("driver",this);
            monitor=intel_8272_monitor::type_id::create("monitor",this);
            scoreboard=intel_8272_scoreboard::type_id::create("scoreboard",this);
            coverage=intel_8272_coverage::type_id::create("coverage",this);
            sequencer=new("sequencer",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.expected.connect(scoreboard.expected); monitor.actual.connect(scoreboard.actual);
            driver.commands.connect(coverage.analysis_export);
        endfunction
        task run_phase(uvm_phase phase);
            intel_8272_sequence sequence_inst;
            phase.raise_objection(this);
            sequence_inst=intel_8272_sequence::type_id::create("sequence_inst");
            sequence_inst.start(sequencer); phase.drop_objection(this);
        endtask
    endclass
endpackage
