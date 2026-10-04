package intel_8273_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `uvm_analysis_imp_decl(_expected)
    `uvm_analysis_imp_decl(_actual)
    typedef enum {RESET,PUT,GET,DATA_PUT,DATA_GET,RX_BIT,TX_BIT,WAIT} action_t;
    class intel_8273_item extends uvm_sequence_item;
        `uvm_object_utils(intel_8273_item)
        action_t action;
        bit [1:0] addr;
        bit [7:0] value;
        int cycles=1;
        function new(string name="intel_8273_item"); super.new(name); endfunction
    endclass
    class intel_8273_driver extends uvm_driver #(intel_8273_item);
        `uvm_component_utils(intel_8273_driver)
        virtual intel_8273_if vif;
        uvm_analysis_port #(intel_8273_item) expected,commands;
        function new(string name,uvm_component parent);
            super.new(name,parent); expected=new("expected",this); commands=new("commands",this);
        endfunction
        function void build_phase(uvm_phase phase);
            if (!uvm_config_db #(virtual intel_8273_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","missing interface")
        endfunction
        task run_phase(uvm_phase phase);
            logic [7:0] observed;
            forever begin
                seq_item_port.get_next_item(req);
                if (req.action==GET || req.action==DATA_GET || req.action==TX_BIT) expected.write(req);
                if (req.action==PUT && req.addr==0) commands.write(req);
                case(req.action)
                    RESET: begin vif.monitor_enable=0; vif.reset(); vif.monitor_enable=1; end
                    PUT: vif.put(req.addr,req.value,req.cycles);
                    GET: vif.get(req.addr,observed,req.cycles);
                    DATA_PUT: vif.data_put(req.value,req.cycles);
                    DATA_GET: vif.data_get(observed,req.cycles);
                    RX_BIT: begin
                        vif.rxd=req.value[0]; vif.rx_tick=1; vif.tick();
                        vif.rx_tick=0; vif.tick(2);
                    end
                    TX_BIT: begin vif.tx_tick=1; vif.tick(); vif.tx_tick=0; vif.tick(2); end
                    WAIT: vif.tick(req.cycles);
                endcase
                seq_item_port.item_done();
            end
        endtask
    endclass
    class intel_8273_monitor extends uvm_component;
        `uvm_component_utils(intel_8273_monitor)
        virtual intel_8273_if vif;
        uvm_analysis_port #(intel_8273_item) actual;
        bit old_read=1;
        function new(string name,uvm_component parent);
            super.new(name,parent); actual=new("actual",this);
        endfunction
        function void build_phase(uvm_phase phase);
            if (!uvm_config_db #(virtual intel_8273_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","missing interface")
        endfunction
        task run_phase(uvm_phase phase);
            intel_8273_item observation;
            forever begin
                @(posedge vif.clk);
                if (vif.monitor_enable && old_read && !vif.rd_n && vif.data_oe) begin
                    observation=intel_8273_item::type_id::create("read_observation");
                    observation.action=vif.rx_dack_n ? GET : DATA_GET;
                    observation.value=vif.data_o; actual.write(observation);
                end
                old_read=vif.rd_n;
                if (vif.monitor_enable && vif.tx_tick) begin
                    #1;
                    observation=intel_8273_item::type_id::create("bit_observation");
                    observation.action=TX_BIT; observation.value={7'b0,vif.txd}; actual.write(observation);
                end
            end
        endtask
    endclass
    class intel_8273_scoreboard extends uvm_component;
        `uvm_component_utils(intel_8273_scoreboard)
        uvm_analysis_imp_expected #(intel_8273_item,intel_8273_scoreboard) expected;
        uvm_analysis_imp_actual #(intel_8273_item,intel_8273_scoreboard) actual;
        bit [15:0] queue[$]; int matched=0;
        function new(string name,uvm_component parent);
            super.new(name,parent); expected=new("expected",this); actual=new("actual",this);
        endfunction
        function void write_expected(intel_8273_item item);
            queue.push_back({8'(item.action),item.value});
        endfunction
        function void write_actual(intel_8273_item item);
            bit [15:0] want;
            if (queue.size()==0) `uvm_error("SCORE","unexpected observation")
            else begin
                want=queue.pop_front();
                if ({8'(item.action),item.value}!==want)
                    `uvm_error("SCORE",$sformatf("expected %04x got kind=%0d data=%02x",want,item.action,item.value))
                else matched++;
            end
        endfunction
        function void check_phase(uvm_phase phase);
            if (queue.size()!=0 || matched!=628)
                `uvm_error("SCORE",$sformatf("matched=%0d remaining=%0d",matched,queue.size()))
            else `uvm_info("SCORE",$sformatf("8273 UVM SCOREBOARD PASSED observations=%0d",matched),UVM_LOW)
        endfunction
    endclass
    class intel_8273_coverage extends uvm_subscriber #(intel_8273_item);
        `uvm_component_utils(intel_8273_coverage)
        bit [7:0] opcode;
        covergroup command_cg;
            option.per_instance=1;
            commands: coverpoint opcode { bins used[]={8'h91,8'ha0,8'hc0,8'hc8,8'h22,8'h23}; }
        endgroup
        function new(string name,uvm_component parent);
            super.new(name,parent); command_cg=new();
        endfunction
        function void write(intel_8273_item item); opcode=item.value; command_cg.sample(); endfunction
    endclass
    class intel_8273_sequence extends uvm_sequence #(intel_8273_item);
        `uvm_object_utils(intel_8273_sequence)
        virtual intel_8273_if vif;
        bit [7:0] body_bytes[0:10];
        bit bits[0:199],bad[0:199];
        int n,wire_n,bad_n;
        function new(string name="intel_8273_sequence"); super.new(name); endfunction
        task send(input action_t action,input bit [7:0] value=0,input bit [1:0] addr=0,input int cycles=1);
            intel_8273_item item=intel_8273_item::type_id::create("item");
            start_item(item); item.action=action; item.value=value; item.addr=addr; item.cycles=cycles; finish_item(item);
        endtask
        task put(input bit [1:0] addr,input bit [7:0] value); send(PUT,value,addr,2); endtask
        task init(input bit bf,nr);
            send(RESET); put(0,8'h91); put(1,bf?8'h24:8'h20);
            if (nr) begin put(0,8'ha0); put(1,1); end
            put(0,8'h22); send(GET,0,1,3);
            put(0,8'h23); send(GET,8'h3f,1,3);
        endtask
        task body;
            int fd,rc,temp,got,fed,count;
            bit line_level,b;
            string filename;
            if (!uvm_config_db #(virtual intel_8273_if)::get(null,"","vif",vif))
                `uvm_fatal("CONFIG","sequence needs interface for protocol polling")
            if (!$value$plusargs("vectors=%s",filename)) filename="design/intel_8273/references/frames.txt";
            fd=$fopen(filename,"r"); if (!fd) `uvm_fatal("VECTORS","cannot open oracle")
            rc=$fscanf(fd,"%d %d %d",n,wire_n,bad_n);
            for(int i=0;i<n;i++) begin rc=$fscanf(fd,"%h",temp); body_bytes[i]=8'(temp); end
            for(int i=0;i<wire_n;i++) begin rc=$fscanf(fd,"%d",temp); bits[i]=1'(temp); end
            for(int i=0;i<bad_n;i++) begin rc=$fscanf(fd,"%d",temp); bad[i]=1'(temp); end
            $fclose(fd);
            for(int nr=0;nr<2;nr++) for(int bf=0;bf<2;bf++) begin
                init(1'(bf),1'(nr)); count=n-(bf?2:0); fed=bf?2:0;
                put(0,8'hc8); put(1,8'(count)); put(1,0);
                if (bf) begin put(1,body_bytes[0]); put(1,body_bytes[1]); end
                send(WAIT,0,0,4); line_level=1;
                for(int i=0;i<wire_n;i++) begin
                    if (vif.tx_drq && fed<n) begin send(DATA_PUT,body_bytes[fed],0,3); fed++; end
                    line_level=nr ? (bits[i]?line_level:!line_level) : bits[i];
                    send(TX_BIT,{7'b0,line_level});
                end
                send(GET,8'h0d,2,3);
                for(int corrupt=0;corrupt<2;corrupt++) begin
                    init(1'(bf),1'(nr)); got=0; line_level=1;
                    put(0,8'hc0); put(1,8'(count)); put(1,0); send(WAIT,0,0,4);
                    for(int i=0;i<(corrupt?bad_n:wire_n);i++) begin
                        b=corrupt?bad[i]:bits[i]; line_level=nr ? (b?line_level:!line_level) : b;
                        send(RX_BIT,{7'b0,line_level});
                        if (vif.rx_drq) begin send(DATA_GET,body_bytes[got+(bf?2:0)],0,3); got++; end
                    end
                    if (got!=count) `uvm_error("COUNT","missing receive data")
                    send(GET,corrupt?8'he3:8'he0,3,3); send(GET,8'(count),3); send(GET,0,3);
                    if (bf) begin send(GET,body_bytes[0],3); send(GET,body_bytes[1],3); end
                end
            end
        endtask
    endclass
    class intel_8273_test extends uvm_test;
        `uvm_component_utils(intel_8273_test)
        intel_8273_driver driver;
        intel_8273_monitor monitor;
        intel_8273_scoreboard scoreboard;
        intel_8273_coverage coverage;
        uvm_sequencer #(intel_8273_item) sequencer;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            driver=intel_8273_driver::type_id::create("driver",this);
            monitor=intel_8273_monitor::type_id::create("monitor",this);
            scoreboard=intel_8273_scoreboard::type_id::create("scoreboard",this);
            coverage=intel_8273_coverage::type_id::create("coverage",this);
            sequencer=new("sequencer",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.expected.connect(scoreboard.expected); monitor.actual.connect(scoreboard.actual);
            driver.commands.connect(coverage.analysis_export);
        endfunction
        task run_phase(uvm_phase phase);
            intel_8273_sequence sequence1=intel_8273_sequence::type_id::create("sequence1");
            phase.raise_objection(this); sequence1.start(sequencer); phase.drop_objection(this);
        endtask
    endclass
endpackage
