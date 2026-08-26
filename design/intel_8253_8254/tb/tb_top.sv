module tb_top;

    logic       clk;
    logic       rst_n;
    logic       cs_n;
    logic       rd_n;
    logic       wr_n;
    logic [1:0] addr;
    logic [7:0] data_i;
    logic [2:0] counter_clk_i;
    logic [2:0] gate_i;

    logic [7:0] data_o_8253;
    logic       data_oe_8253;
    logic [2:0] out_o_8253;
    logic [7:0] data_o_8254;
    logic       data_oe_8254;
    logic [2:0] out_o_8254;

    integer cycle_count;
    integer check_count;
    integer failure_count;
    integer cpu_read_count;
    integer cpu_write_count;
    integer counter_pulse_count;
    integer mode_scenario_count;
    integer alias_scenario_count;
    integer gate_scenario_count;
    integer latch_check_count;
    integer readback_check_count;
    integer bcd_check_count;
    integer phase_check_count;
    integer stress_operation_count;

    intel_8253_8254 #(
        .IS_8254 (1'b0)
    ) dut_8253 (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .addr          (addr),
        .data_i        (data_i),
        .data_o        (data_o_8253),
        .data_oe       (data_oe_8253),
        .counter_clk_i (counter_clk_i),
        .gate_i        (gate_i),
        .out_o         (out_o_8253)
    );

    intel_8253_8254 #(
        .IS_8254 (1'b1)
    ) dut_8254 (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .addr          (addr),
        .data_i        (data_i),
        .data_o        (data_o_8254),
        .data_oe       (data_oe_8254),
        .counter_clk_i (counter_clk_i),
        .gate_i        (gate_i),
        .out_o         (out_o_8254)
    );

    always #5 clk = ~clk;

    function automatic logic [15:0] next_lfsr(
        input logic [15:0] current_value
    );
        begin
            next_lfsr = {
                current_value[14:0],
                current_value[15] ^ current_value[13] ^
                current_value[12] ^ current_value[10]
            };
        end
    endfunction

    task automatic check_condition(
        input logic  condition_value,
        input string description
    );
        begin
            check_count = check_count + 1;
            if (condition_value !== 1'b1) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d: %s", cycle_count, description);
            end
        end
    endtask

    task automatic check_byte(
        input logic [7:0] actual_value,
        input logic [7:0] expected_value,
        input string      description
    );
        begin
            check_count = check_count + 1;
            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d: %s actual=%02h expected=%02h",
                         cycle_count, description, actual_value,
                         expected_value);
            end
        end
    endtask

    task automatic check_common_outputs(input string description);
        begin
            check_condition(out_o_8253 === out_o_8254,
                            {description, ": variant OUT mismatch"});
            check_condition(!$isunknown(out_o_8253),
                            {description, ": 8253 OUT contains X/Z"});
            check_condition(!$isunknown(out_o_8254),
                            {description, ": 8254 OUT contains X/Z"});
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

    task automatic step_cycle;
        begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
        end
    endtask

    task automatic apply_reset;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            set_idle_bus();
            counter_clk_i = 3'b111;
            gate_i = 3'b111;
            step_cycle();
            step_cycle();
            check_condition(out_o_8253 == 3'b111,
                            "8253 reset must drive all OUT signals high");
            check_condition(out_o_8254 == 3'b111,
                            "8254 reset must drive all OUT signals high");
            @(negedge clk);
            rst_n = 1'b1;
            step_cycle();
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
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic cpu_read(
        input  logic [1:0] read_address,
        output logic [7:0] read_value_8253,
        output logic [7:0] read_value_8254
    );
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b0;
            wr_n = 1'b1;
            addr = read_address;
            data_i = 8'h00;
            #1;
            check_condition(data_oe_8253,
                            "8253 counter read must drive data");
            check_condition(data_oe_8254,
                            "8254 counter read must drive data");
            read_value_8253 = data_o_8253;
            read_value_8254 = data_o_8254;
            cpu_read_count = cpu_read_count + 1;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic pulse_counter(
        input logic [1:0] selected_counter
    );
        begin
            @(negedge clk);
            counter_clk_i[selected_counter] = 1'b0;
            step_cycle();
            @(negedge clk);
            counter_clk_i[selected_counter] = 1'b1;
            step_cycle();
            counter_pulse_count = counter_pulse_count + 1;
        end
    endtask

    task automatic sample_gate(
        input logic [1:0] selected_counter,
        input logic       gate_value
    );
        begin
            @(negedge clk);
            gate_i[selected_counter] = gate_value;
            step_cycle();
        end
    endtask

    task automatic trigger_with_clock(
        input logic [1:0] selected_counter
    );
        begin
            @(negedge clk);
            gate_i[selected_counter] = 1'b1;
            counter_clk_i[selected_counter] = 1'b0;
            step_cycle();
            @(negedge clk);
            counter_clk_i[selected_counter] = 1'b1;
            step_cycle();
            counter_pulse_count = counter_pulse_count + 1;
        end
    endtask

    task automatic program_counter(
        input logic [1:0]  selected_counter,
        input logic [2:0]  raw_mode,
        input logic        use_bcd,
        input logic [15:0] programmed_count
    );
        logic [7:0] control_word;
        begin
            control_word = {
                selected_counter, 2'b11, raw_mode, use_bcd
            };
            cpu_write(2'b11, control_word);
            cpu_write(selected_counter, programmed_count[7:0]);
            cpu_write(selected_counter, programmed_count[15:8]);
        end
    endtask

    task automatic latch_counter(
        input logic [1:0] selected_counter
    );
        logic [7:0] latch_word;
        begin
            latch_word = {selected_counter, 2'b00, 4'b0000};
            cpu_write(2'b11, latch_word);
        end
    endtask

    task automatic read_counter_word(
        input  logic [1:0]  selected_counter,
        output logic [15:0] value_8253,
        output logic [15:0] value_8254
    );
        logic [7:0] low_8253;
        logic [7:0] low_8254;
        logic [7:0] high_8253;
        logic [7:0] high_8254;
        begin
            cpu_read(selected_counter, low_8253, low_8254);
            cpu_read(selected_counter, high_8253, high_8254);
            value_8253 = {high_8253, low_8253};
            value_8254 = {high_8254, low_8254};
        end
    endtask

    task automatic run_mode_scenario(
        input logic [1:0] selected_counter,
        input logic [2:0] selected_mode
    );
        integer pulse_index;
        begin
            if ((selected_mode == 3'd1) ||
                (selected_mode == 3'd5)) begin
                sample_gate(selected_counter, 1'b0);
            end else begin
                sample_gate(selected_counter, 1'b1);
            end

            program_counter(selected_counter, selected_mode, 1'b0,
                            16'h0004);

            case (selected_mode)
                3'd0: begin
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 0 programming must drive OUT low");
                    pulse_counter(selected_counter);
                    for (pulse_index = 0; pulse_index < 3;
                         pulse_index = pulse_index + 1) begin
                        pulse_counter(selected_counter);
                        check_condition(
                            !out_o_8253[selected_counter] &&
                            !out_o_8254[selected_counter],
                            "Mode 0 OUT must stay low before terminal count");
                    end
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 0 terminal count must drive OUT high");
                end
                3'd1: begin
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 1 must remain high while armed");
                    trigger_with_clock(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 1 trigger must drive OUT low");
                    for (pulse_index = 0; pulse_index < 3;
                         pulse_index = pulse_index + 1) begin
                        pulse_counter(selected_counter);
                    end
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 1 pulse must last N clocks");
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 1 terminal count must drive OUT high");
                end
                3'd2: begin
                    pulse_counter(selected_counter);
                    pulse_counter(selected_counter);
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 2 must remain high before count one");
                    pulse_counter(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 2 must pulse low for count one");
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 2 must reload high after low pulse");
                end
                3'd3: begin
                    pulse_counter(selected_counter);
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 3 even high phase must last N/2 clocks");
                    pulse_counter(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 3 must enter low phase");
                    pulse_counter(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 3 even low phase must last N/2 clocks");
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 3 must return to high phase");
                end
                3'd4: begin
                    pulse_counter(selected_counter);
                    for (pulse_index = 0; pulse_index < 3;
                         pulse_index = pulse_index + 1) begin
                        pulse_counter(selected_counter);
                    end
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 4 must remain high before terminal");
                    pulse_counter(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 4 terminal count must strobe low");
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 4 low strobe must last one clock");
                end
                default: begin
                    trigger_with_clock(selected_counter);
                    for (pulse_index = 0; pulse_index < 3;
                         pulse_index = pulse_index + 1) begin
                        pulse_counter(selected_counter);
                    end
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 5 must remain high before terminal");
                    pulse_counter(selected_counter);
                    check_condition(!out_o_8253[selected_counter] &&
                                    !out_o_8254[selected_counter],
                                    "Mode 5 terminal count must strobe low");
                    pulse_counter(selected_counter);
                    check_condition(out_o_8253[selected_counter] &&
                                    out_o_8254[selected_counter],
                                    "Mode 5 low strobe must last one clock");
                end
            endcase

            check_common_outputs("directed mode scenario");
            mode_scenario_count = mode_scenario_count + 1;
        end
    endtask

    task automatic run_trigger_lifecycle(
        input logic [2:0] selected_mode
    );
        logic [15:0] value_8253;
        logic [15:0] value_8254;
        begin
            apply_reset();
            sample_gate(0, 1'b0);
            cpu_write(2'b11, {2'b00, 2'b11, selected_mode, 1'b0});
            cpu_write(2'b00, 8'h04);
            sample_gate(0, 1'b1);
            cpu_write(2'b00, 8'h00);
            pulse_counter(0);
            latch_counter(0);
            read_counter_word(0, value_8253, value_8254);
            check_condition((value_8253 == 16'h0000) &&
                            (value_8254 == 16'h0000),
                            "pre-arm GATE rise must not load Mode 1/5");
            check_condition(out_o_8253[0] && out_o_8254[0],
                            "pre-arm GATE rise must leave OUT high");

            sample_gate(0, 1'b0);
            trigger_with_clock(0);
            latch_counter(0);
            read_counter_word(0, value_8253, value_8254);
            check_condition((value_8253 == 16'h0004) &&
                            (value_8254 == 16'h0004),
                            "post-arm GATE rise must load programmed count");
            if (selected_mode == 3'd1) begin
                check_condition(!out_o_8253[0] && !out_o_8254[0],
                                "Mode 1 post-arm trigger must drive OUT low");
            end else begin
                check_condition(out_o_8253[0] && out_o_8254[0],
                                "Mode 5 post-arm trigger must keep OUT high");
            end

            pulse_counter(0);
            sample_gate(0, 1'b0);
            trigger_with_clock(0);
            latch_counter(0);
            read_counter_word(0, value_8253, value_8254);
            check_condition((value_8253 == 16'h0004) &&
                            (value_8254 == 16'h0004),
                            "active Mode 1/5 retrigger must reload count");
            gate_scenario_count = gate_scenario_count + 1;
        end
    endtask

    initial begin
        integer mode_index;
        integer channel_index;
        integer stress_index;
        integer long_pulse_index;
        logic [1:0] selected_counter;
        logic [2:0] selected_mode;
        logic [7:0] read_8253;
        logic [7:0] read_8254;
        logic [15:0] word_8253;
        logic [15:0] word_8254;
        logic [15:0] lfsr;
        logic [15:0] stress_count;

        clk = 1'b0;
        rst_n = 1'b0;
        set_idle_bus();
        counter_clk_i = 3'b111;
        gate_i = 3'b111;

        cycle_count = 0;
        check_count = 0;
        failure_count = 0;
        cpu_read_count = 0;
        cpu_write_count = 0;
        counter_pulse_count = 0;
        mode_scenario_count = 0;
        alias_scenario_count = 0;
        gate_scenario_count = 0;
        latch_check_count = 0;
        readback_check_count = 0;
        bcd_check_count = 0;
        phase_check_count = 0;
        stress_operation_count = 0;

        apply_reset();

        $display("--- All modes on all counters ---");
        for (mode_index = 0; mode_index < 6;
             mode_index = mode_index + 1) begin
            for (channel_index = 0; channel_index < 3;
                 channel_index = channel_index + 1) begin
                run_mode_scenario(channel_index[1:0],
                                  mode_index[2:0]);
            end
        end

        $display("--- Mode aliases and odd Mode 3 ---");
        sample_gate(0, 1'b1);
        program_counter(0, 3'd6, 1'b0, 16'h0004);
        pulse_counter(0);
        pulse_counter(0);
        pulse_counter(0);
        pulse_counter(0);
        check_condition(!out_o_8253[0] && !out_o_8254[0],
                        "Mode encoding 6 must alias Mode 2");
        alias_scenario_count = alias_scenario_count + 1;

        program_counter(0, 3'd7, 1'b0, 16'h0005);
        pulse_counter(0);
        pulse_counter(0);
        pulse_counter(0);
        pulse_counter(0);
        check_condition(!out_o_8253[0] && !out_o_8254[0],
                        "Odd Mode 3 high phase must last three clocks");
        pulse_counter(0);
        check_condition(!out_o_8253[0] && !out_o_8254[0],
                        "Odd Mode 3 low phase must include first low clock");
        pulse_counter(0);
        check_condition(out_o_8253[0] && out_o_8254[0],
                        "Odd Mode 3 low phase must last two clocks");
        alias_scenario_count = alias_scenario_count + 1;

        $display("--- GATE pause, force-high, and restart ---");
        program_counter(0, 3'd0, 1'b0, 16'h0002);
        pulse_counter(0);
        sample_gate(0, 1'b0);
        pulse_counter(0);
        pulse_counter(0);
        check_condition(!out_o_8253[0] && !out_o_8254[0],
                        "Mode 0 GATE low must pause counting");
        sample_gate(0, 1'b1);
        pulse_counter(0);
        pulse_counter(0);
        check_condition(out_o_8253[0] && out_o_8254[0],
                        "Mode 0 must resume after GATE high");
        gate_scenario_count = gate_scenario_count + 1;

        program_counter(1, 3'd2, 1'b0, 16'h0004);
        pulse_counter(1);
        pulse_counter(1);
        sample_gate(1, 1'b0);
        check_condition(out_o_8253[1] && out_o_8254[1],
                        "Mode 2 GATE low must force OUT high");
        trigger_with_clock(1);
        check_condition(out_o_8253[1] && out_o_8254[1],
                        "Mode 2 GATE rise must restart high");
        gate_scenario_count = gate_scenario_count + 1;

        $display("--- Mode 4 GATE-low recovery ---");
        apply_reset();
        sample_gate(0, 1'b1);
        program_counter(0, 3'd4, 1'b0, 16'h0002);
        pulse_counter(0);
        pulse_counter(0);
        pulse_counter(0);
        check_condition(!out_o_8253[0] && !out_o_8254[0],
                        "Mode 4 terminal event must strobe OUT low");
        sample_gate(0, 1'b0);
        pulse_counter(0);
        check_condition(out_o_8253[0] && out_o_8254[0],
                        "Mode 4 strobe must recover with GATE low");
        pulse_counter(0);
        sample_gate(0, 1'b1);
        pulse_counter(0);
        check_condition(out_o_8253[0] && out_o_8254[0],
                        "Mode 4 must remain stopped after strobe recovery");
        gate_scenario_count = gate_scenario_count + 1;

        $display("--- Mode 1/5 trigger lifecycle ---");
        run_trigger_lifecycle(3'd1);
        run_trigger_lifecycle(3'd5);

        $display("--- Counter isolation ---");
        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h0010);
        program_counter(1, 3'd0, 1'b0, 16'h0020);
        program_counter(2, 3'd0, 1'b0, 16'h0030);
        pulse_counter(0);
        pulse_counter(1);
        pulse_counter(2);
        pulse_counter(1);
        latch_counter(0);
        read_counter_word(0, word_8253, word_8254);
        check_condition((word_8253 == 16'h0010) &&
                        (word_8254 == 16'h0010),
                        "counter 0 must ignore counter 1 event");
        latch_counter(1);
        read_counter_word(1, word_8253, word_8254);
        check_condition((word_8253 == 16'h001f) &&
                        (word_8254 == 16'h001f),
                        "counter 1 alone must decrement");
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h0030) &&
                        (word_8254 == 16'h0030),
                        "counter 2 must ignore counter 1 event");
        latch_check_count = latch_check_count + 3;

        $display("--- Count latch and byte formats ---");
        program_counter(0, 3'd0, 1'b0, 16'h1234);
        pulse_counter(0);
        pulse_counter(0);
        latch_counter(0);
        pulse_counter(0);
        latch_counter(0);
        read_counter_word(0, word_8253, word_8254);
        check_condition(word_8253 == 16'h1233,
                        "8253 unread count latch must remain stable");
        check_condition(word_8254 == 16'h1233,
                        "8254 unread count latch must remain stable");
        latch_check_count = latch_check_count + 2;

        cpu_write(2'b11, {2'b10, 2'b01, 3'b000, 1'b0});
        cpu_write(2'b10, 8'hab);
        pulse_counter(2);
        latch_counter(2);
        cpu_read(2'b10, read_8253, read_8254);
        check_byte(read_8253, 8'hab, "8253 LSB-only read");
        check_byte(read_8254, 8'hab, "8254 LSB-only read");
        latch_check_count = latch_check_count + 2;

        cpu_write(2'b11, {2'b10, 2'b10, 3'b000, 1'b0});
        cpu_write(2'b10, 8'h12);
        pulse_counter(2);
        latch_counter(2);
        cpu_read(2'b10, read_8253, read_8254);
        check_byte(read_8253, 8'h12, "8253 MSB-only read");
        check_byte(read_8254, 8'h12, "8254 MSB-only read");
        latch_check_count = latch_check_count + 2;

        $display("--- 8254 status/count read-back ---");
        apply_reset();
        cpu_write(2'b11, {2'b01, 2'b11, 3'b111, 1'b1});
        cpu_write(2'b11, 8'hea);
        cpu_read(2'b01, read_8253, read_8254);
        check_byte(read_8254, 8'hff,
                   "8254 status must report OUT/null/format/mode/BCD");
        readback_check_count = readback_check_count + 1;

        cpu_write(2'b01, 8'h05);
        cpu_write(2'b01, 8'h00);
        pulse_counter(1);
        cpu_write(2'b11, 8'hca);
        cpu_read(2'b01, read_8253, read_8254);
        check_byte(read_8254, 8'hbf,
                   "8254 read-back status must clear null count");
        cpu_read(2'b01, read_8253, read_8254);
        check_byte(read_8254, 8'h05,
                   "8254 read-back count must return LSB after status");
        cpu_read(2'b01, read_8253, read_8254);
        check_byte(read_8254, 8'h00,
                   "8254 read-back count must return MSB second");
        readback_check_count = readback_check_count + 3;

        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h1234);
        pulse_counter(0);
        cpu_write(2'b11, 8'hdc);
        pulse_counter(0);
        cpu_write(2'b11, 8'hdc);
        cpu_read(2'b00, read_8253, read_8254);
        check_byte(read_8254, 8'h34,
                   "8254 count-only read-back must preserve snapshot LSB");
        cpu_read(2'b00, read_8253, read_8254);
        check_byte(read_8254, 8'h12,
                   "8254 unread read-back latch must preserve snapshot MSB");
        readback_check_count = readback_check_count + 2;

        $display("--- 8253 read-back rejection ---");
        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h0010);
        pulse_counter(0);
        cpu_write(2'b11, 8'hdc);
        pulse_counter(0);
        latch_counter(0);
        read_counter_word(0, word_8253, word_8254);
        check_condition(word_8253 == 16'h000f,
                        "8253 must ignore read-back command");
        readback_check_count = readback_check_count + 1;

        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h1234);
        pulse_counter(0);
        cpu_read(2'b00, read_8253, read_8254);
        check_byte(read_8253, 8'h34,
                   "8253 direct read must begin with LSB");
        cpu_write(2'b11, 8'hdc);
        cpu_read(2'b00, read_8253, read_8254);
        check_byte(read_8253, 8'h12,
                   "8253 read-back rejection must preserve shared phase");
        readback_check_count = readback_check_count + 2;

        $display("--- Binary-coded-decimal counting ---");
        apply_reset();
        program_counter(2, 3'd0, 1'b1, 16'h0010);
        pulse_counter(2);
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition(word_8253 == 16'h0009,
                        "8253 BCD decrement must borrow 0010 to 0009");
        check_condition(word_8254 == 16'h0009,
                        "8254 BCD decrement must borrow 0010 to 0009");
        bcd_check_count = bcd_check_count + 2;

        program_counter(2, 3'd0, 1'b1, 16'h0002);
        pulse_counter(2);
        pulse_counter(2);
        pulse_counter(2);
        check_condition(out_o_8253[2] && out_o_8254[2],
                        "BCD terminal count must drive Mode 0 OUT high");
        bcd_check_count = bcd_check_count + 1;

        apply_reset();
        program_counter(2, 3'd3, 1'b1, 16'h0011);
        pulse_counter(2);
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h0010) &&
                        (word_8254 == 16'h0010),
                        "BCD Mode 3 odd high tick must subtract one");
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h0008) &&
                        (word_8254 == 16'h0008),
                        "BCD Mode 3 ordinary tick must subtract two");
        pulse_counter(2);
        pulse_counter(2);
        pulse_counter(2);
        pulse_counter(2);
        check_condition(!out_o_8253[2] && !out_o_8254[2],
                        "BCD Mode 3 count 11 must enter low phase");
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h0008) &&
                        (word_8254 == 16'h0008),
                        "BCD Mode 3 odd low tick must subtract three");
        bcd_check_count = bcd_check_count + 4;

        program_counter(2, 3'd3, 1'b1, 16'h0003);
        pulse_counter(2);
        pulse_counter(2);
        pulse_counter(2);
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h0000) &&
                        (word_8254 == 16'h0000) &&
                        !out_o_8253[2] && !out_o_8254[2],
                        "BCD Mode 3 odd low tick may reach transient zero");
        pulse_counter(2);
        check_condition(out_o_8253[2] && out_o_8254[2],
                        "BCD Mode 3 transient zero must toggle next phase");
        bcd_check_count = bcd_check_count + 2;

        program_counter(2, 3'd3, 1'b1, 16'h0000);
        pulse_counter(2);
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'h9998) &&
                        (word_8254 == 16'h9998) &&
                        out_o_8253[2] && out_o_8254[2],
                        "BCD Mode 3 zero image must begin 10000-count phase");
        for (long_pulse_index = 0; long_pulse_index < 4998;
             long_pulse_index = long_pulse_index + 1) begin
            pulse_counter(2);
        end
        check_condition(out_o_8253[2] && out_o_8254[2],
                        "BCD Mode 3 zero high phase must last 5000 clocks");
        pulse_counter(2);
        check_condition(!out_o_8253[2] && !out_o_8254[2],
                        "BCD Mode 3 zero must enter low phase");
        for (long_pulse_index = 0; long_pulse_index < 4999;
             long_pulse_index = long_pulse_index + 1) begin
            pulse_counter(2);
        end
        check_condition(!out_o_8253[2] && !out_o_8254[2],
                        "BCD Mode 3 zero low phase must last 5000 clocks");
        pulse_counter(2);
        check_condition(out_o_8253[2] && out_o_8254[2],
                        "BCD Mode 3 zero must return to high phase");
        bcd_check_count = bcd_check_count + 5;

        program_counter(2, 3'd3, 1'b0, 16'h0000);
        pulse_counter(2);
        pulse_counter(2);
        latch_counter(2);
        read_counter_word(2, word_8253, word_8254);
        check_condition((word_8253 == 16'hfffe) &&
                        (word_8254 == 16'hfffe) &&
                        out_o_8253[2] && out_o_8254[2],
                        "binary Mode 3 zero image must represent 65536");
        bcd_check_count = bcd_check_count + 1;

        $display("--- Variant byte-phase behavior ---");
        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h1234);
        pulse_counter(0);
        cpu_read(2'b00, read_8253, read_8254);
        check_byte(read_8253, 8'h34, "8253 direct LSB before interleave");
        check_byte(read_8254, 8'h34, "8254 direct LSB before interleave");
        cpu_write(2'b00, 8'hab);
        pulse_counter(0);
        latch_counter(0);
        read_counter_word(0, word_8253, word_8254);
        check_condition(word_8253 == 16'hab34,
                        "8253 read must redirect shared-phase write to MSB");
        check_condition(word_8254 == 16'h1234,
                        "8254 read phase must not complete an LSB write");
        phase_check_count = phase_check_count + 2;

        $display("--- Invalid bus behavior ---");
        apply_reset();
        program_counter(0, 3'd0, 1'b0, 16'h0020);
        pulse_counter(0);
        @(negedge clk);
        cs_n = 1'b0;
        rd_n = 1'b0;
        wr_n = 1'b0;
        addr = 2'b00;
        data_i = 8'hff;
        #1;
        check_condition(!data_oe_8253 && !data_oe_8254,
                        "simultaneous read/write must not drive data");
        step_cycle();
        @(negedge clk);
        cs_n = 1'b0;
        rd_n = 1'b0;
        wr_n = 1'b1;
        addr = 2'b11;
        #1;
        check_condition(!data_oe_8253 && !data_oe_8254,
                        "control-address read must leave data undriven");
        step_cycle();
        @(negedge clk);
        set_idle_bus();
        step_cycle();
        latch_counter(0);
        read_counter_word(0, word_8253, word_8254);
        check_condition((word_8253 == 16'h0020) &&
                        (word_8254 == 16'h0020),
                        "invalid bus controls must not mutate counter state");
        latch_check_count = latch_check_count + 1;

        $display("--- Deterministic common-mode stress ---");
        apply_reset();
        $display("Pseudorandom seed: 0x8254, operations: 64");
        lfsr = 16'h8254;
        for (stress_index = 0; stress_index < 64;
             stress_index = stress_index + 1) begin
            lfsr = next_lfsr(lfsr);
            selected_counter = lfsr[1:0];
            if (selected_counter == 2'b11) begin
                selected_counter = 2'b00;
            end
            selected_mode = lfsr[4:2];
            if (selected_mode >= 3'd6) begin
                selected_mode = selected_mode - 3'd6;
            end
            stress_count = 16'd2 + {13'd0, lfsr[7:5]};
            if ((selected_mode == 3'd1) ||
                (selected_mode == 3'd5)) begin
                sample_gate(selected_counter, 1'b0);
            end else begin
                sample_gate(selected_counter, 1'b1);
            end
            program_counter(selected_counter, selected_mode, 1'b0,
                            stress_count);
            if ((selected_mode == 3'd1) ||
                (selected_mode == 3'd5)) begin
                trigger_with_clock(selected_counter);
            end else begin
                pulse_counter(selected_counter);
            end
            if (lfsr[8]) begin
                pulse_counter(selected_counter);
            end
            check_common_outputs("deterministic stress");
            stress_operation_count = stress_operation_count + 1;
        end

        check_condition(mode_scenario_count == 18,
                        "all six modes on all three counters required");
        check_condition(alias_scenario_count == 2,
                        "both mode aliases required");
        check_condition(gate_scenario_count == 5,
                        "pause, recovery, and trigger GATE scenarios required");
        check_condition(latch_check_count == 10,
                        "latch, isolation, format, and invalid-bus checks required");
        check_condition(readback_check_count == 9,
                        "all read-back forms and 8253 rejection checks required");
        check_condition(bcd_check_count == 15,
                        "BCD borrow, Mode 3, and zero-image checks required");
        check_condition(phase_check_count == 2,
                        "variant byte-phase checks required");
        check_condition(stress_operation_count == 64,
                        "all deterministic stress operations required");

        $display("8253/8254 simulation result: %0d cycles, %0d checks",
                 cycle_count, check_count);
        $display("CPU reads: %0d, CPU writes: %0d, counter pulses: %0d",
                 cpu_read_count, cpu_write_count, counter_pulse_count);
        $display("Mode/channel scenarios: %0d, aliases: %0d, GATE: %0d",
                 mode_scenario_count, alias_scenario_count,
                 gate_scenario_count);
        $display({"Latch checks: %0d, read-back checks: %0d, ",
                  "BCD checks: %0d, phase checks: %0d"},
                 latch_check_count, readback_check_count,
                 bcd_check_count, phase_check_count);
        $display("Stress operations: %0d", stress_operation_count);
        $display("Failures: %0d", failure_count);

        if (failure_count == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "TEST FAILED with %0d failures", failure_count);
        end
    end

endmodule
