`timescale 1ns/1ps

package alu_74181_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class alu_74181_item extends uvm_sequence_item;
        rand logic [3:0] a;
        rand logic [3:0] b;
        rand logic [3:0] s;
        rand logic       m;
        rand logic       cn;
        logic [3:0]      f;
        logic            cn4;
        logic            a_eq_b;
        logic            p_bar;
        logic            g_bar;

        `uvm_object_utils_begin(alu_74181_item)
            `uvm_field_int(a, UVM_DEFAULT)
            `uvm_field_int(b, UVM_DEFAULT)
            `uvm_field_int(s, UVM_DEFAULT)
            `uvm_field_int(m, UVM_DEFAULT)
            `uvm_field_int(cn, UVM_DEFAULT)
            `uvm_field_int(f, UVM_DEFAULT)
            `uvm_field_int(cn4, UVM_DEFAULT)
            `uvm_field_int(a_eq_b, UVM_DEFAULT)
            `uvm_field_int(p_bar, UVM_DEFAULT)
            `uvm_field_int(g_bar, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "alu_74181_item");
            super.new(name);
        endfunction
    endclass

    class alu_74181_all_modes_sequence extends uvm_sequence #(alu_74181_item);
        `uvm_object_utils(alu_74181_all_modes_sequence)

        function new(string name = "alu_74181_all_modes_sequence");
            super.new(name);
        endfunction

        task body();
            alu_74181_item request;
            for (int mode_value = 0; mode_value < 2; mode_value++) begin
                for (int select_value = 0; select_value < 16; select_value++) begin
                    for (int carry_value = 0; carry_value < 2; carry_value++) begin
                        request = alu_74181_item::type_id::create("request");
                        start_item(request);
                        request.m = mode_value[0];
                        request.s = select_value[3:0];
                        request.cn = carry_value[0];
                        request.a = (select_value * 7 + mode_value * 3 + carry_value * 5) & 4'hf;
                        request.b = (select_value * 11 + mode_value * 5 + carry_value * 3) & 4'hf;
                        finish_item(request);
                    end
                end
            end
        endtask
    endclass

    class alu_74181_sequencer extends uvm_sequencer #(alu_74181_item);
        `uvm_component_utils(alu_74181_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class alu_74181_driver extends uvm_driver #(alu_74181_item);
        `uvm_component_utils(alu_74181_driver)
        virtual alu_74181_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_74181_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "alu_74181_if was not configured")
            end
        endfunction

        task run_phase(uvm_phase phase);
            alu_74181_item request;
            vif.valid <= 1'b0;
            vif.a <= '0;
            vif.b <= '0;
            vif.s <= '0;
            vif.m <= 1'b0;
            vif.cn <= 1'b0;
            forever begin
                seq_item_port.get_next_item(request);
                @(negedge vif.clk);
                vif.a <= request.a;
                vif.b <= request.b;
                vif.s <= request.s;
                vif.m <= request.m;
                vif.cn <= request.cn;
                vif.valid <= 1'b1;
                @(posedge vif.clk);
                seq_item_port.item_done();
                @(negedge vif.clk);
                vif.valid <= 1'b0;
            end
        endtask
    endclass

    class alu_74181_monitor extends uvm_monitor;
        `uvm_component_utils(alu_74181_monitor)
        virtual alu_74181_if vif;
        uvm_analysis_port #(alu_74181_item) analysis_port;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_74181_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "alu_74181_if was not configured")
            end
        endfunction

        task run_phase(uvm_phase phase);
            alu_74181_item observed;
            forever begin
                @(posedge vif.clk);
                if (vif.valid) begin
                    observed = alu_74181_item::type_id::create("observed");
                    observed.a = vif.a;
                    observed.b = vif.b;
                    observed.s = vif.s;
                    observed.m = vif.m;
                    observed.cn = vif.cn;
                    observed.f = vif.f;
                    observed.cn4 = vif.cn4;
                    observed.a_eq_b = vif.a_eq_b;
                    observed.p_bar = vif.p_bar;
                    observed.g_bar = vif.g_bar;
                    analysis_port.write(observed);
                end
            end
        endtask
    endclass

    class alu_74181_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(alu_74181_scoreboard)
        uvm_analysis_imp #(alu_74181_item, alu_74181_scoreboard) analysis_export;
        int checked_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
            checked_count = 0;
        endfunction

        function automatic logic [3:0] reference_logic(
            input logic [3:0] value_a,
            input logic [3:0] value_b,
            input logic [3:0] select
        );
            case (select)
                4'h0: reference_logic = ~value_a;
                4'h1: reference_logic = ~(value_a | value_b);
                4'h2: reference_logic = ~value_a & value_b;
                4'h3: reference_logic = 4'h0;
                4'h4: reference_logic = ~(value_a & value_b);
                4'h5: reference_logic = ~value_b;
                4'h6: reference_logic = value_a ^ value_b;
                4'h7: reference_logic = value_a & ~value_b;
                4'h8: reference_logic = ~value_a | value_b;
                4'h9: reference_logic = ~(value_a ^ value_b);
                4'ha: reference_logic = value_b;
                4'hb: reference_logic = value_a & value_b;
                4'hc: reference_logic = 4'hf;
                4'hd: reference_logic = value_a | ~value_b;
                4'he: reference_logic = value_a | value_b;
                4'hf: reference_logic = value_a;
                default: reference_logic = 4'hx;
            endcase
        endfunction

        function automatic logic [4:0] reference_arithmetic(
            input logic [3:0] value_a,
            input logic [3:0] value_b,
            input logic [3:0] select,
            input logic       carry_n
        );
            logic [4:0] base_value;
            case (select)
                4'h0: base_value = {1'b0, value_a};
                4'h1: base_value = {1'b0, value_a | value_b};
                4'h2: base_value = {1'b0, value_a | ~value_b};
                4'h3: base_value = 5'h0f;
                4'h4: base_value = {1'b0, value_a} + {1'b0, value_a & ~value_b};
                4'h5: base_value = {1'b0, value_a | value_b} +
                                     {1'b0, value_a & ~value_b};
                4'h6: base_value = {1'b0, value_a} + {1'b0, ~value_b};
                4'h7: base_value = {1'b0, value_a & ~value_b} + 5'h0f;
                4'h8: base_value = {1'b0, value_a} + {1'b0, value_a & value_b};
                4'h9: base_value = {1'b0, value_a} + {1'b0, value_b};
                4'ha: base_value = {1'b0, value_a | ~value_b} +
                                     {1'b0, value_a & value_b};
                4'hb: base_value = {1'b0, value_a & value_b} + 5'h0f;
                4'hc: base_value = {1'b0, value_a} + {1'b0, value_a};
                4'hd: base_value = {1'b0, value_a | value_b} + {1'b0, value_a};
                4'he: base_value = {1'b0, value_a | ~value_b} + {1'b0, value_a};
                4'hf: base_value = {1'b0, value_a} + 5'h0f;
                default: base_value = 5'hxx;
            endcase
            reference_arithmetic = base_value + {4'b0000, ~carry_n};
        endfunction

        function automatic logic [3:0] reference_x(
            input logic [3:0] value_a,
            input logic [3:0] value_b,
            input logic [1:0] select_low
        );
            case (select_low)
                2'b00: reference_x = value_a;
                2'b01: reference_x = value_a | value_b;
                2'b10: reference_x = value_a | ~value_b;
                2'b11: reference_x = 4'hf;
                default: reference_x = 4'hx;
            endcase
        endfunction

        function automatic logic [3:0] reference_y(
            input logic [3:0] value_a,
            input logic [3:0] value_b,
            input logic [1:0] select_high
        );
            case (select_high)
                2'b00: reference_y = 4'h0;
                2'b01: reference_y = value_a & ~value_b;
                2'b10: reference_y = value_a & value_b;
                2'b11: reference_y = value_a;
                default: reference_y = 4'hx;
            endcase
        endfunction

        function void write(alu_74181_item observed);
            logic [4:0] arithmetic_result;
            logic [3:0] expected_f;
            logic [3:0] expected_x;
            logic [3:0] expected_y;
            logic       expected_cn4;
            logic       expected_a_eq_b;
            logic       expected_p_bar;
            logic       expected_g_bar;

            arithmetic_result = reference_arithmetic(
                observed.a, observed.b, observed.s, observed.cn);
            expected_f = observed.m ?
                reference_logic(observed.a, observed.b, observed.s) :
                arithmetic_result[3:0];
            expected_x = reference_x(observed.a, observed.b, observed.s[1:0]);
            expected_y = reference_y(observed.a, observed.b, observed.s[3:2]);
            expected_cn4 = observed.m ? 1'b1 : ~arithmetic_result[4];
            expected_a_eq_b = &expected_f;
            expected_p_bar = ~&expected_x;
            expected_g_bar = ~(expected_y[3] |
                               (expected_x[3] & expected_y[2]) |
                               (expected_x[3] & expected_x[2] & expected_y[1]) |
                               (expected_x[3] & expected_x[2] &
                                expected_x[1] & expected_y[0]));

            checked_count++;
            if ({observed.f, observed.cn4, observed.a_eq_b,
                 observed.p_bar, observed.g_bar} !==
                {expected_f, expected_cn4, expected_a_eq_b,
                 expected_p_bar, expected_g_bar}) begin
                `uvm_error("MISMATCH",
                    $sformatf("A=%h B=%h S=%h M=%b Cn=%b actual=%h%b%b%b%b expected=%h%b%b%b%b",
                              observed.a, observed.b, observed.s, observed.m, observed.cn,
                              observed.f, observed.cn4, observed.a_eq_b,
                              observed.p_bar, observed.g_bar,
                              expected_f, expected_cn4, expected_a_eq_b,
                              expected_p_bar, expected_g_bar))
            end
        endfunction

        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (checked_count != 64) begin
                `uvm_error("COUNT",
                           $sformatf("Expected 64 transactions, checked %0d", checked_count))
            end
            `uvm_info("SUMMARY", $sformatf("Checked %0d selector/mode/carry transactions",
                                           checked_count), UVM_LOW)
        endfunction
    endclass

    class alu_74181_env extends uvm_env;
        `uvm_component_utils(alu_74181_env)
        alu_74181_sequencer  sequencer;
        alu_74181_driver     driver;
        alu_74181_monitor    monitor;
        alu_74181_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = alu_74181_sequencer::type_id::create("sequencer", this);
            driver = alu_74181_driver::type_id::create("driver", this);
            monitor = alu_74181_monitor::type_id::create("monitor", this);
            scoreboard = alu_74181_scoreboard::type_id::create("scoreboard", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.analysis_port.connect(scoreboard.analysis_export);
        endfunction
    endclass

    class alu_74181_all_modes_test extends uvm_test;
        `uvm_component_utils(alu_74181_all_modes_test)
        alu_74181_env env;
        virtual alu_74181_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = alu_74181_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual alu_74181_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "alu_74181_if was not configured")
            end
        endfunction

        task run_phase(uvm_phase phase);
            alu_74181_all_modes_sequence sequence_h;
            phase.raise_objection(this);
            sequence_h = alu_74181_all_modes_sequence::type_id::create("sequence_h");
            sequence_h.start(env.sequencer);
            repeat (2) @(posedge vif.clk);
            phase.drop_objection(this);
        endtask
    endclass

endpackage
