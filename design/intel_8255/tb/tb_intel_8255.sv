`timescale 1ns/1ps

module tb_intel_8255;

    logic       clk;
    logic       reset;
    logic       cs_n;
    logic       rd_n;
    logic       wr_n;
    logic [1:0] addr;
    logic [7:0] data_i;
    logic [7:0] data_o;
    logic       data_oe;
    logic [7:0] port_a_i;
    logic [7:0] port_a_o;
    logic [7:0] port_a_oe;
    logic [7:0] port_b_i;
    logic [7:0] port_b_o;
    logic [7:0] port_b_oe;
    logic [7:0] port_c_i;
    logic [7:0] port_c_o;
    logic [7:0] port_c_oe;

    logic [7:0] ref_control_word;
    logic [7:0] ref_port_a_output;
    logic [7:0] ref_port_b_output;
    logic [7:0] ref_port_c_output;
    logic [7:0] ref_port_a_input;
    logic [7:0] ref_port_b_input;
    logic       ref_ibf_a;
    logic       ref_ibf_b;
    logic       ref_obf_a_n;
    logic       ref_obf_b_n;
    logic       ref_inte_a_input;
    logic       ref_inte_a_output;
    logic       ref_inte_b;
    logic       ref_previous_pc2;
    logic       ref_previous_pc4;
    logic       ref_previous_pc6;

    logic [7:0] ref_data_o;
    logic       ref_data_oe;
    logic [7:0] ref_port_a_o;
    logic [7:0] ref_port_a_oe;
    logic [7:0] ref_port_b_o;
    logic [7:0] ref_port_b_oe;
    logic [7:0] ref_port_c_o;
    logic [7:0] ref_port_c_oe;
    logic [7:0] ref_port_c_read;
    logic       ref_intr_a;
    logic       ref_intr_b;

    integer cycle_count;
    integer interface_check_count;
    integer field_check_count;
    integer failure_count;
    integer cpu_read_count;
    integer cpu_write_count;
    integer mode_set_count;
    integer direction_config_count;
    integer bsr_action_count;
    integer mode1_scenario_count;
    integer mode2_scenario_count;
    integer handshake_fall_count;

    intel_8255 dut (
        .clk       (clk),
        .reset     (reset),
        .cs_n      (cs_n),
        .rd_n      (rd_n),
        .wr_n      (wr_n),
        .addr      (addr),
        .data_i    (data_i),
        .data_o    (data_o),
        .data_oe   (data_oe),
        .port_a_i  (port_a_i),
        .port_a_o  (port_a_o),
        .port_a_oe (port_a_oe),
        .port_b_i  (port_b_i),
        .port_b_o  (port_b_o),
        .port_b_oe (port_b_oe),
        .port_c_i  (port_c_i),
        .port_c_o  (port_c_o),
        .port_c_oe (port_c_oe)
    );

    always #5 clk = ~clk;

    function automatic logic [1:0] model_group_a_mode(
        input logic [2:0] mode_bits
    );
        begin
            if (!mode_bits[2]) begin
                model_group_a_mode = 2'd0;
            end else if (mode_bits[1]) begin
                model_group_a_mode = 2'd2;
            end else if (mode_bits[0]) begin
                model_group_a_mode = 2'd1;
            end else begin
                model_group_a_mode = 2'd0;
            end
        end
    endfunction

    function automatic logic [15:0] next_lfsr(
        input logic [15:0] current_value
    );
        begin
            next_lfsr = {current_value[14:0],
                         current_value[15] ^ current_value[13] ^
                         current_value[12] ^ current_value[10]};
        end
    endfunction

    task automatic model_step;
        logic [1:0] group_a_mode;
        logic       group_b_mode;
        logic       group_a_input_handshake;
        logic       group_a_output_handshake;
        logic       group_b_input_handshake;
        logic       group_b_output_handshake;
        logic       bus_read;
        logic       bus_write;
        begin
            group_a_mode = model_group_a_mode(ref_control_word[7:5]);
            group_b_mode = ref_control_word[2];
            group_a_input_handshake = (group_a_mode == 2'd2) ||
                                      ((group_a_mode == 2'd1) &&
                                       ref_control_word[4]);
            group_a_output_handshake = (group_a_mode == 2'd2) ||
                                       ((group_a_mode == 2'd1) &&
                                        !ref_control_word[4]);
            group_b_input_handshake = group_b_mode && ref_control_word[1];
            group_b_output_handshake = group_b_mode && !ref_control_word[1];
            bus_read = !cs_n && !rd_n && wr_n;
            bus_write = !cs_n && rd_n && !wr_n;

            if (reset) begin
                ref_control_word = 8'h9b;
                ref_port_a_output = 8'h00;
                ref_port_b_output = 8'h00;
                ref_port_c_output = 8'h00;
                ref_port_a_input = 8'h00;
                ref_port_b_input = 8'h00;
                ref_ibf_a = 1'b0;
                ref_ibf_b = 1'b0;
                ref_obf_a_n = 1'b1;
                ref_obf_b_n = 1'b1;
                ref_inte_a_input = 1'b0;
                ref_inte_a_output = 1'b0;
                ref_inte_b = 1'b0;
                ref_previous_pc2 = port_c_i[2];
                ref_previous_pc4 = port_c_i[4];
                ref_previous_pc6 = port_c_i[6];
            end else if (bus_write && (addr == 2'b11) && data_i[7]) begin
                ref_control_word = data_i;
                ref_port_a_output = 8'h00;
                ref_port_b_output = 8'h00;
                ref_port_c_output = 8'h00;
                ref_port_a_input = 8'h00;
                ref_port_b_input = 8'h00;
                ref_ibf_a = 1'b0;
                ref_ibf_b = 1'b0;
                ref_obf_a_n = 1'b1;
                ref_obf_b_n = 1'b1;
                ref_inte_a_input = 1'b0;
                ref_inte_a_output = 1'b0;
                ref_inte_b = 1'b0;
                ref_previous_pc2 = port_c_i[2];
                ref_previous_pc4 = port_c_i[4];
                ref_previous_pc6 = port_c_i[6];
            end else begin
                if (group_a_input_handshake && ref_previous_pc4 &&
                    !port_c_i[4]) begin
                    ref_port_a_input = port_a_i;
                    ref_ibf_a = 1'b1;
                end
                if (group_a_output_handshake && ref_previous_pc6 &&
                    !port_c_i[6]) begin
                    ref_obf_a_n = 1'b1;
                end
                if (group_b_input_handshake && ref_previous_pc2 &&
                    !port_c_i[2]) begin
                    ref_port_b_input = port_b_i;
                    ref_ibf_b = 1'b1;
                end
                if (group_b_output_handshake && ref_previous_pc2 &&
                    !port_c_i[2]) begin
                    ref_obf_b_n = 1'b1;
                end

                if (bus_write) begin
                    case (addr)
                        2'b00: begin
                            if ((group_a_mode == 2'd2) ||
                                !ref_control_word[4]) begin
                                ref_port_a_output = data_i;
                                if (group_a_output_handshake) begin
                                    ref_obf_a_n = 1'b0;
                                end
                            end
                        end
                        2'b01: begin
                            if (!ref_control_word[1]) begin
                                ref_port_b_output = data_i;
                                if (group_b_output_handshake) begin
                                    ref_obf_b_n = 1'b0;
                                end
                            end
                        end
                        2'b10: begin
                            ref_port_c_output = data_i;
                        end
                        default: begin
                            if (!data_i[7]) begin
                                ref_port_c_output[data_i[3:1]] = data_i[0];
                                if (group_a_input_handshake &&
                                    (data_i[3:1] == 3'd4)) begin
                                    ref_inte_a_input = data_i[0];
                                end
                                if (group_a_output_handshake &&
                                    (data_i[3:1] == 3'd6)) begin
                                    ref_inte_a_output = data_i[0];
                                end
                                if (group_b_mode &&
                                    (data_i[3:1] == 3'd2)) begin
                                    ref_inte_b = data_i[0];
                                end
                            end
                        end
                    endcase
                end

                if (bus_read) begin
                    if ((addr == 2'b00) && group_a_input_handshake) begin
                        ref_ibf_a = 1'b0;
                    end
                    if ((addr == 2'b01) && group_b_input_handshake) begin
                        ref_ibf_b = 1'b0;
                    end
                end

                ref_previous_pc2 = port_c_i[2];
                ref_previous_pc4 = port_c_i[4];
                ref_previous_pc6 = port_c_i[6];
            end
        end
    endtask

    always_comb begin
        logic [1:0] group_a_mode;
        logic       group_b_mode;
        logic       group_a_input_handshake;
        logic       group_a_output_handshake;
        logic       group_b_input_handshake;
        logic       group_b_output_handshake;
        logic       bus_read;

        group_a_mode = model_group_a_mode(ref_control_word[7:5]);
        group_b_mode = ref_control_word[2];
        group_a_input_handshake = (group_a_mode == 2'd2) ||
                                  ((group_a_mode == 2'd1) &&
                                   ref_control_word[4]);
        group_a_output_handshake = (group_a_mode == 2'd2) ||
                                   ((group_a_mode == 2'd1) &&
                                    !ref_control_word[4]);
        group_b_input_handshake = group_b_mode && ref_control_word[1];
        group_b_output_handshake = group_b_mode && !ref_control_word[1];
        bus_read = !cs_n && !rd_n && wr_n;

        ref_intr_a = (group_a_input_handshake && ref_inte_a_input &&
                      ref_ibf_a && port_c_i[4]) ||
                     (group_a_output_handshake && ref_inte_a_output &&
                      ref_obf_a_n && port_c_i[6]);
        ref_intr_b = (group_b_input_handshake && ref_inte_b &&
                      ref_ibf_b && port_c_i[2]) ||
                     (group_b_output_handshake && ref_inte_b &&
                      ref_obf_b_n && port_c_i[2]);

        ref_port_a_o = ref_port_a_output;
        ref_port_b_o = ref_port_b_output;
        ref_port_c_o = ref_port_c_output;
        if (group_a_mode == 2'd2) begin
            ref_port_a_oe = {8{!port_c_i[6]}};
        end else begin
            ref_port_a_oe = ref_control_word[4] ? 8'h00 : 8'hff;
        end
        ref_port_b_oe = ref_control_word[1] ? 8'h00 : 8'hff;

        ref_port_c_oe[7:4] = ref_control_word[3] ? 4'h0 : 4'hf;
        ref_port_c_oe[3:0] = ref_control_word[0] ? 4'h0 : 4'hf;
        ref_port_c_read[7:4] = ref_control_word[3] ?
                                    port_c_i[7:4] : ref_port_c_output[7:4];
        ref_port_c_read[3:0] = ref_control_word[0] ?
                                    port_c_i[3:0] : ref_port_c_output[3:0];

        if (group_a_mode == 2'd1) begin
            ref_port_c_o[3] = ref_intr_a;
            ref_port_c_oe[3] = 1'b1;
            ref_port_c_read[3] = ref_intr_a;
            if (ref_control_word[4]) begin
                ref_port_c_oe[4] = 1'b0;
                ref_port_c_o[5] = ref_ibf_a;
                ref_port_c_oe[5] = 1'b1;
                ref_port_c_read[4] = port_c_i[4];
                ref_port_c_read[5] = ref_ibf_a;
            end else begin
                ref_port_c_oe[6] = 1'b0;
                ref_port_c_o[7] = ref_obf_a_n;
                ref_port_c_oe[7] = 1'b1;
                ref_port_c_read[6] = port_c_i[6];
                ref_port_c_read[7] = ref_obf_a_n;
            end
        end else if (group_a_mode == 2'd2) begin
            ref_port_c_o[3] = ref_intr_a;
            ref_port_c_oe[3] = 1'b1;
            ref_port_c_oe[4] = 1'b0;
            ref_port_c_o[5] = ref_ibf_a;
            ref_port_c_oe[5] = 1'b1;
            ref_port_c_oe[6] = 1'b0;
            ref_port_c_o[7] = ref_obf_a_n;
            ref_port_c_oe[7] = 1'b1;
            ref_port_c_read[3] = ref_intr_a;
            ref_port_c_read[4] = port_c_i[4];
            ref_port_c_read[5] = ref_ibf_a;
            ref_port_c_read[6] = port_c_i[6];
            ref_port_c_read[7] = ref_obf_a_n;
        end

        if (group_b_mode) begin
            ref_port_c_o[0] = ref_intr_b;
            ref_port_c_oe[0] = 1'b1;
            ref_port_c_oe[2] = 1'b0;
            ref_port_c_read[0] = ref_intr_b;
            ref_port_c_read[2] = port_c_i[2];
            if (ref_control_word[1]) begin
                ref_port_c_o[1] = ref_ibf_b;
                ref_port_c_read[1] = ref_ibf_b;
            end else begin
                ref_port_c_o[1] = ref_obf_b_n;
                ref_port_c_read[1] = ref_obf_b_n;
            end
            ref_port_c_oe[1] = 1'b1;
        end

        ref_data_o = 8'h00;
        ref_data_oe = 1'b0;
        if (bus_read) begin
            case (addr)
                2'b00: begin
                    ref_data_oe = 1'b1;
                    if (group_a_input_handshake) begin
                        ref_data_o = ref_port_a_input;
                    end else if (ref_control_word[4]) begin
                        ref_data_o = port_a_i;
                    end else begin
                        ref_data_o = ref_port_a_output;
                    end
                end
                2'b01: begin
                    ref_data_oe = 1'b1;
                    if (group_b_input_handshake) begin
                        ref_data_o = ref_port_b_input;
                    end else if (ref_control_word[1]) begin
                        ref_data_o = port_b_i;
                    end else begin
                        ref_data_o = ref_port_b_output;
                    end
                end
                2'b10: begin
                    ref_data_o = ref_port_c_read;
                    ref_data_oe = 1'b1;
                end
                default: begin
                    ref_data_o = 8'h00;
                    ref_data_oe = 1'b0;
                end
            endcase
        end
    end

    task automatic record_mismatch(
        input string      field_name,
        input logic [7:0] actual_value,
        input logic [7:0] expected_value
    );
        begin
            field_check_count = field_check_count + 1;
            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d %s: actual=%02h expected=%02h",
                         cycle_count, field_name, actual_value,
                         expected_value);
            end
        end
    endtask

    task automatic check_outputs;
        begin
            interface_check_count = interface_check_count + 1;
            record_mismatch("data_o", data_o, ref_data_o);
            record_mismatch("data_oe", {7'h00, data_oe},
                            {7'h00, ref_data_oe});
            record_mismatch("port_a_o", port_a_o, ref_port_a_o);
            record_mismatch("port_a_oe", port_a_oe, ref_port_a_oe);
            record_mismatch("port_b_o", port_b_o, ref_port_b_o);
            record_mismatch("port_b_oe", port_b_oe, ref_port_b_oe);
            record_mismatch("port_c_o", port_c_o, ref_port_c_o);
            record_mismatch("port_c_oe", port_c_oe, ref_port_c_oe);
        end
    endtask

    task automatic check_condition(
        input logic  condition_value,
        input string description
    );
        begin
            field_check_count = field_check_count + 1;
            if (condition_value !== 1'b1) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d: %s", cycle_count, description);
            end
        end
    endtask

    task automatic step_cycle;
        begin
            model_step();
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            check_outputs();
        end
    endtask

    task automatic set_idle_bus;
        begin
            cs_n = 1'b1;
            rd_n = 1'b1;
            wr_n = 1'b1;
            addr = 2'b00;
            data_i = 8'h00;
        end
    endtask

    task automatic cpu_write(
        input logic [1:0] write_address,
        input logic [7:0] write_value
    );
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b1;
            wr_n = 1'b0;
            addr = write_address;
            data_i = write_value;
            cpu_write_count = cpu_write_count + 1;
            if ((write_address == 2'b11) && write_value[7]) begin
                mode_set_count = mode_set_count + 1;
            end
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic cpu_read(
        input  logic [1:0] read_address,
        output logic [7:0] read_value
    );
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b0;
            wr_n = 1'b1;
            addr = read_address;
            data_i = 8'h00;
            cpu_read_count = cpu_read_count + 1;
            step_cycle();
            read_value = data_o;
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic pulse_port_c(input logic [2:0] bit_number);
        begin
            @(negedge clk);
            port_c_i[bit_number] = 1'b1;
            step_cycle();
            @(negedge clk);
            port_c_i[bit_number] = 1'b0;
            handshake_fall_count = handshake_fall_count + 1;
            step_cycle();
            @(negedge clk);
            port_c_i[bit_number] = 1'b1;
            step_cycle();
        end
    endtask

    task automatic invalid_bus_cycle;
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b0;
            wr_n = 1'b0;
            addr = 2'b00;
            data_i = 8'hff;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    initial begin
        integer direction_index;
        integer bit_index;
        integer random_index;
        logic [2:0] selected_bit;
        logic [7:0] control_value;
        logic [7:0] read_value;
        logic [15:0] lfsr;

        clk = 1'b0;
        reset = 1'b1;
        set_idle_bus();
        port_a_i = 8'h00;
        port_b_i = 8'h00;
        port_c_i = 8'hff;

        cycle_count = 0;
        interface_check_count = 0;
        field_check_count = 0;
        failure_count = 0;
        cpu_read_count = 0;
        cpu_write_count = 0;
        mode_set_count = 0;
        direction_config_count = 0;
        bsr_action_count = 0;
        mode1_scenario_count = 0;
        mode2_scenario_count = 0;
        handshake_fall_count = 0;

        step_cycle();
        step_cycle();
        check_condition(port_a_oe == 8'h00,
                        "reset must release Port A");
        check_condition(port_b_oe == 8'h00,
                        "reset must release Port B");
        check_condition(port_c_oe == 8'h00,
                        "reset must release Port C");

        @(negedge clk);
        reset = 1'b0;
        step_cycle();

        $display("--- Mode 0 direction and data tests ---");
        for (direction_index = 0; direction_index < 16;
             direction_index = direction_index + 1) begin
            control_value = 8'h80;
            control_value[4] = direction_index[3];
            control_value[3] = direction_index[2];
            control_value[1] = direction_index[1];
            control_value[0] = direction_index[0];
            cpu_write(2'b11, control_value);
            cpu_write(2'b00, 8'ha5 ^ direction_index[7:0]);
            cpu_write(2'b01, 8'h5a ^ direction_index[7:0]);
            cpu_write(2'b10, 8'h3c ^ direction_index[7:0]);
            @(negedge clk);
            port_a_i = 8'hc0 | direction_index[7:0];
            port_b_i = 8'h30 | direction_index[7:0];
            port_c_i = 8'hf0 ^ direction_index[7:0];
            step_cycle();
            cpu_read(2'b00, read_value);
            cpu_read(2'b01, read_value);
            cpu_read(2'b10, read_value);
            direction_config_count = direction_config_count + 1;
        end

        $display("--- Bit Set/Reset tests ---");
        cpu_write(2'b11, 8'h80);
        cpu_write(2'b10, 8'h00);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            cpu_write(2'b11, {4'h0, bit_index[2:0], 1'b1});
            check_condition(port_c_o[bit_index] == 1'b1,
                            "BSR set must drive selected Port C bit");
            bsr_action_count = bsr_action_count + 1;
            cpu_write(2'b11, {4'h0, bit_index[2:0], 1'b0});
            check_condition(port_c_o[bit_index] == 1'b0,
                            "BSR reset must clear selected Port C bit");
            bsr_action_count = bsr_action_count + 1;
        end

        $display("--- Mode 1 Group A input ---");
        port_c_i = 8'hff;
        cpu_write(2'b11, 8'hbb);
        cpu_write(2'b11, 8'h09);
        port_a_i = 8'ha5;
        pulse_port_c(4);
        check_condition(port_c_oe[5] && port_c_o[5],
                        "Mode 1 A input must set IBF_A");
        check_condition(port_c_oe[3] && port_c_o[3],
                        "Mode 1 A input must assert INTR_A");
        cpu_read(2'b00, read_value);
        check_condition(read_value == 8'ha5,
                        "Mode 1 A input read must return latched byte");
        check_condition(!port_c_o[5] && !port_c_o[3],
                        "Mode 1 A input read must clear IBF_A and INTR_A");
        mode1_scenario_count = mode1_scenario_count + 1;

        $display("--- Mode 1 Group A output ---");
        port_c_i = 8'hff;
        cpu_write(2'b11, 8'hab);
        cpu_write(2'b11, 8'h0d);
        cpu_write(2'b00, 8'h3c);
        check_condition(port_a_o == 8'h3c && port_a_oe == 8'hff,
                        "Mode 1 A output must drive written data");
        check_condition(!port_c_o[7] && !port_c_o[3],
                        "Mode 1 A output write must assert OBF_A_n");
        pulse_port_c(6);
        check_condition(port_c_o[7] && port_c_o[3],
                        "Mode 1 A acknowledge must assert INTR_A");
        mode1_scenario_count = mode1_scenario_count + 1;

        $display("--- Mode 1 Group B input ---");
        port_c_i = 8'hff;
        cpu_write(2'b11, 8'h9f);
        cpu_write(2'b11, 8'h05);
        port_b_i = 8'h69;
        pulse_port_c(2);
        check_condition(port_c_o[1] && port_c_o[0],
                        "Mode 1 B input must set IBF_B and INTR_B");
        cpu_read(2'b01, read_value);
        check_condition(read_value == 8'h69,
                        "Mode 1 B input read must return latched byte");
        check_condition(!port_c_o[1] && !port_c_o[0],
                        "Mode 1 B input read must clear status");
        mode1_scenario_count = mode1_scenario_count + 1;

        $display("--- Mode 1 Group B output ---");
        port_c_i = 8'hff;
        cpu_write(2'b11, 8'h9d);
        cpu_write(2'b11, 8'h05);
        cpu_write(2'b01, 8'h96);
        check_condition(port_b_o == 8'h96 && port_b_oe == 8'hff,
                        "Mode 1 B output must drive written data");
        check_condition(!port_c_o[1] && !port_c_o[0],
                        "Mode 1 B output write must assert OBF_B_n");
        pulse_port_c(2);
        check_condition(port_c_o[1] && port_c_o[0],
                        "Mode 1 B acknowledge must assert INTR_B");
        mode1_scenario_count = mode1_scenario_count + 1;

        $display("--- Mode 2 bidirectional Port A ---");
        port_c_i = 8'hff;
        cpu_write(2'b11, 8'hcb);
        cpu_write(2'b11, 8'h09);
        cpu_write(2'b11, 8'h0d);
        cpu_write(2'b00, 8'h5a);
        check_condition(port_a_o == 8'h5a && port_a_oe == 8'h00,
                        "Mode 2 must release Port A while ACK_A_n is high");
        check_condition(!port_c_o[7],
                        "Mode 2 output write must assert OBF_A_n");
        mode2_scenario_count = mode2_scenario_count + 1;
        port_a_i = 8'hc3;
        pulse_port_c(4);
        check_condition(port_c_o[5] && port_a_oe == 8'h00,
                        "Mode 2 input may be pending on a released bus");
        mode2_scenario_count = mode2_scenario_count + 1;
        cpu_read(2'b00, read_value);
        check_condition(read_value == 8'hc3,
                        "Mode 2 read must return input latch");
        check_condition(port_a_oe == 8'h00,
                        "Mode 2 read must leave ACK-controlled bus released");
        @(negedge clk);
        port_c_i[6] = 1'b1;
        step_cycle();
        @(negedge clk);
        port_c_i[6] = 1'b0;
        handshake_fall_count = handshake_fall_count + 1;
        step_cycle();
        check_condition(port_a_oe == 8'hff && port_a_o == 8'h5a,
                        "Low ACK_A_n must enable Mode 2 output data");
        @(negedge clk);
        port_c_i[6] = 1'b1;
        step_cycle();
        check_condition(port_a_oe == 8'h00 && port_c_o[7],
                        "High ACK_A_n must release Port A after transfer");
        mode2_scenario_count = mode2_scenario_count + 1;

        $display("--- Mode 2 handshake stress ---");
        for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
            cpu_write(2'b00, 8'h40 + bit_index[7:0]);
            port_a_i = 8'h80 + bit_index[7:0];
            pulse_port_c(4);
            cpu_read(2'b00, read_value);
            pulse_port_c(6);
        end

        $display("--- Invalid bus and control-read tests ---");
        invalid_bus_cycle();
        cpu_read(2'b11, read_value);
        check_condition(!data_oe,
                        "control-address read must leave CPU data undriven");

        $display("--- Deterministic pseudorandom regression ---");
        $display("Pseudorandom seed: 0x1ace, operations: 1024");
        lfsr = 16'h1ace;
        for (random_index = 0; random_index < 1024;
             random_index = random_index + 1) begin
            lfsr = next_lfsr(lfsr);
            case (lfsr[2:0])
                3'd0: cpu_write(2'b11, lfsr[7:0] | 8'h80);
                3'd1: cpu_write(2'b11, lfsr[7:0] & 8'h7f);
                3'd2: begin
                    if (lfsr[9:8] == 2'b11) begin
                        cpu_write(2'b10, lfsr[7:0]);
                    end else begin
                        cpu_write(lfsr[9:8], lfsr[7:0]);
                    end
                end
                3'd3: begin
                    if (lfsr[9:8] == 2'b11) begin
                        cpu_read(2'b10, read_value);
                    end else begin
                        cpu_read(lfsr[9:8], read_value);
                    end
                end
                3'd4: begin
                    @(negedge clk);
                    port_a_i = lfsr[7:0];
                    port_b_i = lfsr[15:8];
                    step_cycle();
                end
                3'd5: begin
                    case (lfsr[9:8])
                        2'd0: selected_bit = 2;
                        2'd1: selected_bit = 4;
                        default: selected_bit = 6;
                    endcase
                    @(negedge clk);
                    if (port_c_i[selected_bit]) begin
                        handshake_fall_count = handshake_fall_count + 1;
                    end
                    port_c_i[selected_bit] = !port_c_i[selected_bit];
                    step_cycle();
                end
                3'd6: invalid_bus_cycle();
                default: begin
                    @(negedge clk);
                    set_idle_bus();
                    step_cycle();
                end
            endcase
        end

        check_condition(direction_config_count == 16,
                        "all 16 Mode 0 direction combinations required");
        check_condition(bsr_action_count == 16,
                        "all BSR set/reset selections required");
        check_condition(mode1_scenario_count == 4,
                        "all four Mode 1 group/direction scenarios required");
        check_condition(mode2_scenario_count == 3,
                        "Mode 2 input/output/overlap scenarios required");
        check_condition(mode_set_count >= 20,
                        "at least 20 mode-set writes required");
        check_condition(cpu_read_count >= 100,
                        "at least 100 CPU reads required");
        check_condition(cpu_write_count >= 100,
                        "at least 100 CPU writes required");
        check_condition(handshake_fall_count >= 20,
                        "at least 20 handshake falling edges required");
        check_condition(interface_check_count >= 500,
                        "at least 500 whole-interface comparisons required");

        $display("8255 simulation result: %0d cycles, %0d interface checks, %0d field checks",
                 cycle_count, interface_check_count, field_check_count);
        $display("CPU reads: %0d, CPU writes: %0d, mode-set writes: %0d",
                 cpu_read_count, cpu_write_count, mode_set_count);
        $display({"Mode 0 directions: %0d, BSR actions: %0d, ",
                  "Mode 1 scenarios: %0d, Mode 2 scenarios: %0d"},
                 direction_config_count, bsr_action_count,
                 mode1_scenario_count, mode2_scenario_count);
        $display("Handshake falling edges: %0d", handshake_fall_count);
        $display("Failures: %0d", failure_count);

        if (failure_count == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "TEST FAILED with %0d failures", failure_count);
        end
    end

endmodule
