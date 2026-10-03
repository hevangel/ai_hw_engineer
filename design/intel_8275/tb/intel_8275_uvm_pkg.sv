package intel_8275_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    typedef enum {RESET,WRITE,READ,TICK,DMA_ON,PEN,OBSERVE,DMA_BYTE,VRETRACE} action_t;
    class intel_8275_item extends uvm_sequence_item;
        `uvm_object_utils(intel_8275_item)
        action_t action;
        bit a0;
        byte unsigned data, expected, mask=8'hff;
        integer count=1;
        bit hrtc,vrtc,vsp,lten,rvv,hlgt;
        bit [6:0] cc;
        bit [3:0] lc;
        function new(string name="intel_8275_item"); super.new(name); endfunction
    endclass

    class intel_8275_sequence extends uvm_sequence#(intel_8275_item);
        `uvm_object_utils(intel_8275_sequence)
        function new(string name="intel_8275_sequence"); super.new(name); endfunction
        task send(action_t action, bit addr=0, byte unsigned data=0,
                  integer count=1, byte unsigned expected=0, mask=8'hff);
            intel_8275_item item=intel_8275_item::type_id::create("stimulus");
            start_item(item); item.action=action; item.a0=addr; item.data=data;
            item.count=count; item.expected=expected; item.mask=mask; finish_item(item);
        endtask
        task body();
            send(RESET); send(READ,1,0,1,0);
            send(WRITE,1,0); send(WRITE,0,3); send(WRITE,0,1);
            send(WRITE,0,8'h11); send(WRITE,0,8'h40);
            send(READ,1,0,1,0);
            send(WRITE,1,8'h23); send(DMA_ON);
            send(TICK,0,0,36); // initial frame, prefetch and status acknowledgement
            send(READ,1,0,1,8'h64,8'h64);
            send(TICK,0,0,108);
            send(READ,1,0,1,8'h64);
            send(WRITE,1,8'hc0); send(TICK,0,0,36);
            send(READ,1,0,1,8'h04);
            send(WRITE,1,8'ha0); send(TICK,0,0,36);
            send(READ,1,0,1,8'h64);
            send(PEN,0,1); send(WRITE,1,8'h60);
            send(READ,0,0,1,0); send(READ,0,0,1,0);
            send(READ,1,0,1,8'h54); send(READ,1,0,1,8'h44);
            send(PEN,0,0); send(WRITE,1,8'h40);
            send(READ,1,0,1,8'h40);
            send(WRITE,0,8'hff); send(READ,1,0,1,8'h48);
            send(READ,1,0,1,8'h40);
            send(WRITE,1,8'h80); send(WRITE,0,255); send(WRITE,0,255);
            send(WRITE,1,8'he0); send(WRITE,1,8'hc0);
        endtask
    endclass

    class intel_8275_driver extends uvm_driver#(intel_8275_item);
        `uvm_component_utils(intel_8275_driver)
        virtual intel_8275_if vif;
        uvm_analysis_port#(intel_8275_item) completed;
        bit dma_enabled=0,busy=0,prev_vrtc=0;
        integer dma_index=0;
        function new(string name,uvm_component parent);
            super.new(name,parent); completed=new("completed",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual intel_8275_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","Missing interface")
        endfunction
        task dma_protocol();
            forever begin
                @(negedge vif.clk);
                if (!vif.rst_n) begin vif.dack_n=1; dma_index=0; prev_vrtc=0; end
                else begin
                    if (vif.vrtc && !prev_vrtc) dma_index=0;
                    prev_vrtc=vif.vrtc;
                    if (!vif.dack_n) vif.dack_n=1;
                    else if (vif.drq && dma_enabled && !busy) begin
                        vif.db_in=8'(65+dma_index%8); dma_index++;
                        vif.dack_n=0;
                    end
                end
            end
        endtask
        task run_phase(uvm_phase phase);
            intel_8275_item item;
            fork dma_protocol(); join_none
            forever begin
                seq_item_port.get_next_item(item);
                case(item.action)
                    RESET: begin
                        busy=1; dma_enabled=0;
                        @(negedge vif.clk); vif.rst_n=0;
                        repeat(3) @(negedge vif.clk);
                        vif.rst_n=1; @(negedge vif.clk); busy=0;
                    end
                    WRITE: begin
                        busy=1; @(negedge vif.clk);
                        vif.a0=item.a0; vif.db_in=item.data; vif.cs_n=0; vif.wr_n=0;
                        @(negedge vif.clk); vif.cs_n=1; vif.wr_n=1;
                        @(negedge vif.clk); busy=0;
                    end
                    READ: begin
                        busy=1; @(negedge vif.clk); vif.a0=item.a0; vif.cs_n=0; vif.rd_n=0;
                        #1; item.data=vif.db_out;
                        @(negedge vif.clk); vif.cs_n=1; vif.rd_n=1;
                        @(negedge vif.clk); busy=0;
                    end
                    TICK: repeat(item.count) begin
                        @(negedge vif.clk); vif.cclk_en=1;
                        @(negedge vif.clk); vif.cclk_en=0;
                        repeat(3) @(negedge vif.clk);
                    end
                    DMA_ON: dma_enabled=1;
                    PEN: begin @(negedge vif.clk); vif.lpen=bit'(item.data); @(negedge vif.clk); end
                    default: `uvm_fatal("PROTOCOL","Invalid driver action")
                endcase
                completed.write(item); seq_item_port.item_done();
            end
        endtask
    endclass

    class intel_8275_monitor extends uvm_monitor;
        `uvm_component_utils(intel_8275_monitor)
        virtual intel_8275_if vif;
        uvm_analysis_port#(intel_8275_item) observed;
        function new(string name,uvm_component parent);
            super.new(name,parent); observed=new("observed",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual intel_8275_if)::get(this,"","vif",vif))
                `uvm_fatal("CONFIG","Missing interface")
        endfunction
        task run_phase(uvm_phase phase);
            bit ack_seen=0,previous_vrtc=0;
            forever begin
                intel_8275_item item;
                @(posedge vif.clk);
                if (vif.vrtc && !previous_vrtc) begin
                    item=intel_8275_item::type_id::create("retrace_observation");
                    item.action=VRETRACE; observed.write(item);
                end
                previous_vrtc=vif.vrtc;
                if (!vif.dack_n && !ack_seen && vif.drq) begin
                    item=intel_8275_item::type_id::create("dma_observation");
                    item.action=DMA_BYTE; item.data=vif.db_in; observed.write(item);
                end
                ack_seen=!vif.dack_n;
                if (vif.rst_n && vif.cclk_en) begin
                    item=intel_8275_item::type_id::create("raster_observation");
                    item.action=OBSERVE; item.hrtc=vif.hrtc; item.vrtc=vif.vrtc;
                    item.lc=vif.lc; item.cc=vif.cc; item.vsp=vif.vsp;
                    item.lten=vif.lten; item.rvv=vif.rvv; item.hlgt=vif.hlgt;
                    observed.write(item);
                end
            end
        endtask
    endclass

    class intel_8275_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(intel_8275_scoreboard)
        uvm_analysis_imp#(intel_8275_item,intel_8275_scoreboard) input_port;
        integer reads=0,cells=0,dmas=0,x=0,row=0,line=0,frames=0,dma_pos=0;
        function new(string name,uvm_component parent);
            super.new(name,parent); input_port=new("input_port",this);
        endfunction
        function void write(intel_8275_item item);
            if(item.action==VRETRACE) dma_pos=0;
            if(item.action==READ) begin
                reads++;
                if ((item.data & item.mask)!=(item.expected & item.mask))
                    `uvm_error("CPU",$sformatf("Expected %02x mask %02x, got %02x",item.expected,item.mask,item.data))
            end
            if(item.action==DMA_BYTE) begin
                dmas++;
                if (item.data != 8'(65+dma_pos%8)) `uvm_error("DMA","DMA stream ordering")
                dma_pos++;
            end
            if(item.action==OBSERVE) begin
                if (item.hrtc!=(x>=4) || item.vrtc!=(row>=2) ||
                    item.lc!=4'(x>=4 ? 1-line : line))
                    `uvm_error("RASTER","Retrace or LC disagrees with independently counted CCLKs")
                if (frames>=2 && x<4 && row<2) begin
                    if (item.vsp || item.lten || item.rvv || item.hlgt ||
                        item.cc!=7'(65+row*4+x))
                        `uvm_error("CELL",$sformatf("Cell %0d,%0d line %0d code %02x vsp=%0b",x,row,line,item.cc,item.vsp))
                    cells++;
                end
                if (x>=4 || row>=2) begin
                    if (!item.vsp || item.lten) `uvm_error("BLANK","Retrace not blanked")
                end
                x++;
                if(x==6) begin x=0; line++; end
                if(line==2) begin line=0; row++; end
                if(row==3) begin row=0; frames++; end
            end
        endfunction
        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if(reads!=13 || cells!=64 || dmas!=48)
                `uvm_error("COUNT",$sformatf("Exact counts expected reads=13 cells=64 DMA=48; got %0d %0d %0d",reads,cells,dmas))
            else `uvm_info("PASS","8275 UVM SCOREBOARD PASSED reads=13 cells=64 DMA=48",UVM_LOW)
        endfunction
    endclass

    class intel_8275_coverage extends uvm_subscriber#(intel_8275_item);
        `uvm_component_utils(intel_8275_coverage)
        integer command_code;
        bit h,v;
        covergroup accesses;
            cp_command: coverpoint command_code { bins commands[]={[0:7]}; }
        endgroup
        covergroup raster;
            cp_h: coverpoint h;
            cp_v: coverpoint v;
            cross cp_h,cp_v;
        endgroup
        function new(string name,uvm_component parent);
            super.new(name,parent); accesses=new; raster=new;
        endfunction
        function void write(intel_8275_item item);
            if(item.action==WRITE && item.a0) begin command_code=item.data>>5; accesses.sample(); end
            if(item.action==OBSERVE) begin h=item.hrtc; v=item.vrtc; raster.sample(); end
        endfunction
    endclass

    class intel_8275_test extends uvm_test;
        `uvm_component_utils(intel_8275_test)
        uvm_sequencer#(intel_8275_item) sequencer;
        intel_8275_driver driver;
        intel_8275_monitor monitor;
        intel_8275_scoreboard scoreboard;
        intel_8275_coverage coverage;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer=new("sequencer",this);
            driver=intel_8275_driver::type_id::create("driver",this);
            monitor=intel_8275_monitor::type_id::create("monitor",this);
            scoreboard=intel_8275_scoreboard::type_id::create("scoreboard",this);
            coverage=intel_8275_coverage::type_id::create("coverage",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.completed.connect(scoreboard.input_port);
            driver.completed.connect(coverage.analysis_export);
            monitor.observed.connect(scoreboard.input_port);
            monitor.observed.connect(coverage.analysis_export);
        endfunction
        task run_phase(uvm_phase phase);
            intel_8275_sequence sequence_item=intel_8275_sequence::type_id::create("sequence_item");
            phase.raise_objection(this); sequence_item.start(sequencer); phase.drop_objection(this);
        endtask
    endclass
endpackage
