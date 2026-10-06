`timescale 1ns/1ps
package amd_am9517_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    typedef enum {BUS_WRITE, BUS_READ, SET_REQUEST, SET_READY, WAIT_CYCLES,
                  RESET_CHIP, EXPECT_DMA, OBSERVE_DMA} action_t;

    class amd_am9517_item extends uvm_sequence_item;
        `uvm_object_utils(amd_am9517_item)
        action_t action;
        logic [3:0] offset;
        logic [7:0] value, actual;
        logic [15:0] address;
        logic [1:0] channel, direction;
        int cycles = 1;
        function new(string name = "amd_am9517_item"); super.new(name); endfunction
    endclass

    class amd_am9517_driver extends uvm_driver #(amd_am9517_item);
        `uvm_component_utils(amd_am9517_driver)
        virtual amd_am9517_if vif;
        uvm_analysis_port #(amd_am9517_item) completed;
        function new(string name, uvm_component parent);
            super.new(name, parent); completed = new("completed", this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual amd_am9517_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Missing 8237 interface")
        endfunction
        task run_phase(uvm_phase phase);
            amd_am9517_item item;
            forever begin
                seq_item_port.get_next_item(item);
                if (item.action == EXPECT_DMA) completed.write(item);
                else begin
                    @(negedge vif.clk);
                    case (item.action)
                        RESET_CHIP: begin
                            vif.rst_n = 0; vif.dreq = 0; vif.ready = 1;
                            repeat (2) @(posedge vif.clk);
                            @(negedge vif.clk); vif.rst_n = 1;
                        end
                        BUS_WRITE, BUS_READ: begin
                            vif.reg_addr = item.offset; vif.cpu_data = item.value;
                            vif.cs_n = 0; vif.ior_n = item.action != BUS_READ;
                            vif.iow_n = item.action != BUS_WRITE;
                            #1;
                            if (item.action == BUS_READ) item.actual = vif.data_o;
                            @(posedge vif.clk);
                            @(negedge vif.clk); vif.cs_n = 1; vif.ior_n = 1; vif.iow_n = 1;
                            if (item.action == BUS_READ) completed.write(item);
                        end
                        SET_REQUEST: vif.dreq = item.value[3:0];
                        SET_READY: vif.ready = item.value[0];
                        WAIT_CYCLES: repeat (item.cycles) @(posedge vif.clk);
                        default: begin end
                    endcase
                end
                seq_item_port.item_done();
            end
        endtask
    endclass

    class amd_am9517_monitor extends uvm_monitor;
        `uvm_component_utils(amd_am9517_monitor)
        virtual amd_am9517_if vif;
        uvm_analysis_port #(amd_am9517_item) observed;
        function new(string name, uvm_component parent);
            super.new(name, parent); observed = new("observed", this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual amd_am9517_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Missing 8237 interface")
        endfunction
        task run_phase(uvm_phase phase);
            amd_am9517_item item;
            forever begin
                @(posedge vif.clk);
                if (vif.rst_n && vif.transfer_valid) begin
                    item = amd_am9517_item::type_id::create("observation");
                    item.action = OBSERVE_DMA; item.channel = vif.transfer_channel;
                    item.address = vif.dma_addr;
                    item.direction = !vif.memw_n ? 1 : (!vif.memr_n ? 2 : 0);
                    item.actual = vif.data_i;
                    observed.write(item);
                end
            end
        endtask
    endclass

    class amd_am9517_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(amd_am9517_scoreboard)
        uvm_analysis_imp #(amd_am9517_item, amd_am9517_scoreboard) input_port;
        amd_am9517_item expected[$];
        int dma_checks = 0, read_checks = 0;
        function new(string name, uvm_component parent);
            super.new(name, parent); input_port = new("input_port", this);
        endfunction
        function void write(amd_am9517_item item);
            amd_am9517_item exp_item;
            if (item.action == EXPECT_DMA) expected.push_back(item);
            else if (item.action == BUS_READ) begin
                read_checks++;
                if (item.actual !== item.value)
                    `uvm_error("REGISTER", $sformatf("offset=%h expected=%h actual=%h", item.offset, item.value, item.actual))
            end else if (item.action == OBSERVE_DMA) begin
                if (expected.size() == 0) `uvm_error("EXTRA", "Unexpected DMA transfer")
                else begin
                    exp_item = expected.pop_front(); dma_checks++;
                    if (item.channel !== exp_item.channel || item.address !== exp_item.address ||
                        item.direction !== exp_item.direction ||
                        (item.direction != 0 && item.actual !== exp_item.value))
                        `uvm_error("DMA", $sformatf("expected ch=%d addr=%h type=%d data=%h actual ch=%d addr=%h type=%d data=%h",
                            exp_item.channel, exp_item.address, exp_item.direction, exp_item.value,
                            item.channel, item.address, item.direction, item.actual))
                end
            end
        endfunction
        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (expected.size() != 0 || dma_checks != 144 || read_checks != 216)
                `uvm_error("MISSING", $sformatf("pending=%0d dma=%0d reads=%0d", expected.size(), dma_checks, read_checks))
        endfunction
    endclass

    class amd_am9517_coverage extends uvm_subscriber #(amd_am9517_item);
        `uvm_component_utils(amd_am9517_coverage)
        logic [1:0] sampled_channel, sampled_direction;
        covergroup transfers;
            option.per_instance = 1;
            channels: coverpoint sampled_channel;
            directions: coverpoint sampled_direction { bins legal[] = {[0:2]}; }
            channel_direction: cross channels, directions;
        endgroup
        function new(string name, uvm_component parent);
            super.new(name, parent); transfers = new;
        endfunction
        function void write(amd_am9517_item item);
            sampled_channel = item.channel; sampled_direction = item.direction;
            transfers.sample();
        endfunction
        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COVERAGE", $sformatf("Am9517 channel/direction coverage %0.1f%%", transfers.get_inst_coverage()), UVM_LOW)
        endfunction
    endclass

    class amd_am9517_sequence extends uvm_sequence #(amd_am9517_item);
        `uvm_object_utils(amd_am9517_sequence)
        function new(string name = "amd_am9517_sequence"); super.new(name); endfunction
        task send(action_t action, logic [3:0] offset = 0, logic [7:0] value = 0, int cycles = 1);
            amd_am9517_item item;
            item = amd_am9517_item::type_id::create("bus_item");
            start_item(item); item.action = action; item.offset = offset;
            item.value = value; item.cycles = cycles; finish_item(item);
        endtask
        task word_write(logic [3:0] offset, logic [15:0] value);
            send(BUS_WRITE, 12); send(BUS_WRITE, offset, value[7:0]); send(BUS_WRITE, offset, value[15:8]);
        endtask
        task word_read(logic [3:0] offset, logic [15:0] value);
            send(BUS_WRITE, 12); send(BUS_READ, offset, value[7:0]); send(BUS_READ, offset, value[15:8]);
        endtask
        task body();
            logic [15:0] address;
            logic [7:0] mode;
            amd_am9517_item expected;
            for (int service = 0; service < 3; service++) begin
                for (int direction = 0; direction < 3; direction++) begin
                    for (int ch = 0; ch < 4; ch++) begin
                        send(RESET_CHIP);
                        address = 16'h4000+16'(ch*256+direction*16);
                        word_write(4'(2*ch), address); word_write(4'(2*ch+1), 3);
                        mode = (8'(service)<<6) | (8'(direction)<<2) | 8'(ch);
                        send(BUS_WRITE, 11, mode);
                        if (service != 2) send(BUS_WRITE, 10, 8'(ch));
                        for (int i = 0; i < 4; i++) begin
                            expected = amd_am9517_item::type_id::create("expected");
                            start_item(expected); expected.action = EXPECT_DMA;
                            expected.channel = 2'(ch); expected.address = address+16'(i);
                            expected.direction = 2'(direction);
                            expected.value = direction == 1 ? 8'(32+ch) :
                                             8'(expected.address ^ (expected.address >> 8) ^ 16'ha5);
                            finish_item(expected);
                        end
                        send(SET_READY, 0, 0);
                        if (service == 2) send(BUS_WRITE, 9, 8'(4+ch));
                        else send(SET_REQUEST, 0, 8'(1<<ch));
                        send(WAIT_CYCLES, 0, 0, 10); send(SET_READY, 0, 1);
                        send(WAIT_CYCLES, 0, 0, 80); send(SET_REQUEST, 0, 0);
                        send(WAIT_CYCLES, 0, 0, 5);
                        word_read(4'(2*ch), address+4); word_read(4'(2*ch+1), 16'hffff);
                        send(BUS_READ, 8, 8'(1<<ch)); send(BUS_READ, 8, 0);
                    end
                end
            end
        endtask
    endclass

    class amd_am9517_test extends uvm_test;
        `uvm_component_utils(amd_am9517_test)
        uvm_sequencer #(amd_am9517_item) sequencer;
        amd_am9517_driver driver;
        amd_am9517_monitor monitor;
        amd_am9517_scoreboard scoreboard;
        amd_am9517_coverage coverage_collector;
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = new("sequencer", this);
            driver = amd_am9517_driver::type_id::create("driver", this);
            monitor = amd_am9517_monitor::type_id::create("monitor", this);
            scoreboard = amd_am9517_scoreboard::type_id::create("scoreboard", this);
            coverage_collector = amd_am9517_coverage::type_id::create("coverage_collector", this);
        endfunction
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            driver.completed.connect(scoreboard.input_port);
            monitor.observed.connect(scoreboard.input_port);
            monitor.observed.connect(coverage_collector.analysis_export);
        endfunction
        task run_phase(uvm_phase phase);
            amd_am9517_sequence stimulus;
            phase.raise_objection(this);
            stimulus = amd_am9517_sequence::type_id::create("stimulus");
            stimulus.start(sequencer);
            phase.drop_objection(this);
        endtask
        function void report_phase(uvm_phase phase);
            uvm_report_server server;
            super.report_phase(phase); server = uvm_report_server::get_server();
            if (server.get_severity_count(UVM_ERROR) == 0 && server.get_severity_count(UVM_FATAL) == 0)
                `uvm_info("PASS", "Am9517 UVM PASSED", UVM_NONE)
            else `uvm_fatal("FAIL", "Am9517 UVM regression failed")
        endfunction
    endclass
endpackage
