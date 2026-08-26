module intel_8255_props (
    input logic       clk,
    input logic       reset,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    input logic [7:0] data_o,
    input logic       data_oe,
    input logic [7:0] port_a_i,
    input logic [7:0] port_a_o,
    input logic [7:0] port_a_oe,
    input logic [7:0] port_b_i,
    input logic [7:0] port_b_o,
    input logic [7:0] port_b_oe,
    input logic [7:0] port_c_i,
    input logic [7:0] port_c_o,
    input logic [7:0] port_c_oe,
    input logic [7:0] control_word,
    input logic [7:0] port_a_output_latch,
    input logic [7:0] port_b_output_latch,
    input logic [7:0] port_c_output_latch,
    input logic [7:0] port_a_input_latch,
    input logic [7:0] port_b_input_latch,
    input logic       ibf_a,
    input logic       ibf_b,
    input logic       obf_a_n,
    input logic       obf_b_n,
    input logic       inte_a_input,
    input logic       inte_a_output,
    input logic       inte_b,
    input logic       previous_pc2,
    input logic       previous_pc4,
    input logic       previous_pc6
);

    logic [1:0] group_a_mode;
    logic       group_b_mode;
    logic       group_a_input_handshake;
    logic       group_a_output_handshake;
    logic       group_b_input_handshake;
    logic       group_b_output_handshake;
    logic       intr_a;
    logic       intr_b;
    logic       bus_read;
    logic       bus_write;

    logic [7:0] expected_data_o;
    logic       expected_data_oe;
    logic [7:0] expected_port_a_o;
    logic [7:0] expected_port_a_oe;
    logic [7:0] expected_port_b_o;
    logic [7:0] expected_port_b_oe;
    logic [7:0] expected_port_c_o;
    logic [7:0] expected_port_c_oe;
    logic [7:0] expected_port_c_read;

    logic       a_capture_event;
    logic       b_capture_event;
    logic       a_ack_event;
    logic       b_ack_event;
    logic       a_read_event;
    logic       b_read_event;
    logic       a_write_event;
    logic       b_write_event;
    logic       bsr_write_event;
    logic       mode_set_event;

    function automatic logic [7:0] bsr_updated_value(
        input logic [7:0] original_value,
        input logic [2:0] bit_number,
        input logic       bit_value
    );
        logic [7:0] result;
        begin
            result = original_value;
            result[bit_number] = bit_value;
            bsr_updated_value = result;
        end
    endfunction

    assign group_a_mode = (!control_word[7]) ? 2'd0 :
                          (control_word[6] ? 2'd2 :
                           (control_word[5] ? 2'd1 : 2'd0));
    assign group_b_mode = control_word[2];
    assign group_a_input_handshake = (group_a_mode == 2'd2) ||
                                     ((group_a_mode == 2'd1) &&
                                      control_word[4]);
    assign group_a_output_handshake = (group_a_mode == 2'd2) ||
                                      ((group_a_mode == 2'd1) &&
                                       !control_word[4]);
    assign group_b_input_handshake = group_b_mode && control_word[1];
    assign group_b_output_handshake = group_b_mode && !control_word[1];

    assign intr_a = (group_a_input_handshake && inte_a_input &&
                     ibf_a && port_c_i[4]) ||
                    (group_a_output_handshake && inte_a_output &&
                     obf_a_n && port_c_i[6]);
    assign intr_b = (group_b_input_handshake && inte_b &&
                     ibf_b && port_c_i[2]) ||
                    (group_b_output_handshake && inte_b &&
                     obf_b_n && port_c_i[2]);
    assign bus_read = !cs_n && !rd_n && wr_n;
    assign bus_write = !cs_n && rd_n && !wr_n;

    assign mode_set_event = bus_write && (addr == 2'b11) && data_i[7];
    assign bsr_write_event = bus_write && (addr == 2'b11) && !data_i[7];
    assign a_capture_event = group_a_input_handshake && previous_pc4 &&
                             !port_c_i[4];
    assign b_capture_event = group_b_input_handshake && previous_pc2 &&
                             !port_c_i[2];
    assign a_ack_event = group_a_output_handshake && previous_pc6 &&
                         !port_c_i[6];
    assign b_ack_event = group_b_output_handshake && previous_pc2 &&
                         !port_c_i[2];
    assign a_read_event = bus_read && (addr == 2'b00) &&
                          group_a_input_handshake;
    assign b_read_event = bus_read && (addr == 2'b01) &&
                          group_b_input_handshake;
    assign a_write_event = bus_write && (addr == 2'b00) &&
                           ((group_a_mode == 2'd2) || !control_word[4]);
    assign b_write_event = bus_write && (addr == 2'b01) &&
                           !control_word[1];

    always_comb begin
        expected_port_a_o = port_a_output_latch;
        expected_port_b_o = port_b_output_latch;
        expected_port_c_o = port_c_output_latch;

        if (group_a_mode == 2'd2) begin
            expected_port_a_oe = {8{!port_c_i[6]}};
        end else begin
            expected_port_a_oe = control_word[4] ? 8'h00 : 8'hff;
        end
        expected_port_b_oe = control_word[1] ? 8'h00 : 8'hff;

        expected_port_c_oe[7:4] = control_word[3] ? 4'h0 : 4'hf;
        expected_port_c_oe[3:0] = control_word[0] ? 4'h0 : 4'hf;
        expected_port_c_read[7:4] = control_word[3] ?
                                         port_c_i[7:4] :
                                         port_c_output_latch[7:4];
        expected_port_c_read[3:0] = control_word[0] ?
                                         port_c_i[3:0] :
                                         port_c_output_latch[3:0];

        if (group_a_mode == 2'd1) begin
            expected_port_c_o[3] = intr_a;
            expected_port_c_oe[3] = 1'b1;
            expected_port_c_read[3] = intr_a;
            if (control_word[4]) begin
                expected_port_c_oe[4] = 1'b0;
                expected_port_c_o[5] = ibf_a;
                expected_port_c_oe[5] = 1'b1;
                expected_port_c_read[4] = port_c_i[4];
                expected_port_c_read[5] = ibf_a;
            end else begin
                expected_port_c_oe[6] = 1'b0;
                expected_port_c_o[7] = obf_a_n;
                expected_port_c_oe[7] = 1'b1;
                expected_port_c_read[6] = port_c_i[6];
                expected_port_c_read[7] = obf_a_n;
            end
        end else if (group_a_mode == 2'd2) begin
            expected_port_c_o[3] = intr_a;
            expected_port_c_oe[3] = 1'b1;
            expected_port_c_oe[4] = 1'b0;
            expected_port_c_o[5] = ibf_a;
            expected_port_c_oe[5] = 1'b1;
            expected_port_c_oe[6] = 1'b0;
            expected_port_c_o[7] = obf_a_n;
            expected_port_c_oe[7] = 1'b1;
            expected_port_c_read[3] = intr_a;
            expected_port_c_read[4] = port_c_i[4];
            expected_port_c_read[5] = ibf_a;
            expected_port_c_read[6] = port_c_i[6];
            expected_port_c_read[7] = obf_a_n;
        end

        if (group_b_mode) begin
            expected_port_c_o[0] = intr_b;
            expected_port_c_oe[0] = 1'b1;
            expected_port_c_oe[2] = 1'b0;
            expected_port_c_read[0] = intr_b;
            expected_port_c_read[2] = port_c_i[2];
            expected_port_c_o[1] = control_word[1] ? ibf_b : obf_b_n;
            expected_port_c_read[1] = control_word[1] ? ibf_b : obf_b_n;
            expected_port_c_oe[1] = 1'b1;
        end

        expected_data_o = 8'h00;
        expected_data_oe = 1'b0;
        if (bus_read) begin
            case (addr)
                2'b00: begin
                    expected_data_oe = 1'b1;
                    if (group_a_input_handshake) begin
                        expected_data_o = port_a_input_latch;
                    end else if (control_word[4]) begin
                        expected_data_o = port_a_i;
                    end else begin
                        expected_data_o = port_a_output_latch;
                    end
                end
                2'b01: begin
                    expected_data_oe = 1'b1;
                    if (group_b_input_handshake) begin
                        expected_data_o = port_b_input_latch;
                    end else if (control_word[1]) begin
                        expected_data_o = port_b_i;
                    end else begin
                        expected_data_o = port_b_output_latch;
                    end
                end
                2'b10: begin
                    expected_data_o = expected_port_c_read;
                    expected_data_oe = 1'b1;
                end
                default: begin
                    expected_data_o = 8'h00;
                    expected_data_oe = 1'b0;
                end
            endcase
        end

        assert ({data_o, data_oe} ==
                {expected_data_o, expected_data_oe});
        assert ({port_a_o, port_a_oe, port_b_o, port_b_oe,
                 port_c_o, port_c_oe} ==
                {expected_port_a_o, expected_port_a_oe,
                 expected_port_b_o, expected_port_b_oe,
                 expected_port_c_o, expected_port_c_oe});
        assert (!(data_oe && (!cs_n && !rd_n && !wr_n)));
        if (bus_read && (addr == 2'b11)) begin
            assert (!data_oe);
        end
        if (group_a_mode == 2'd2) begin
            assert (port_a_oe == {8{!port_c_i[6]}});
        end
    end

    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (reset);
        end else begin
            if ($past(reset)) begin
                assert (control_word == 8'h9b);
                assert (port_a_output_latch == 8'h00);
                assert (port_b_output_latch == 8'h00);
                assert (port_c_output_latch == 8'h00);
                assert (port_a_input_latch == 8'h00);
                assert (port_b_input_latch == 8'h00);
                assert (!ibf_a && !ibf_b);
                assert (obf_a_n && obf_b_n);
                assert (!inte_a_input && !inte_a_output && !inte_b);
                assert (previous_pc2 == $past(port_c_i[2]));
                assert (previous_pc4 == $past(port_c_i[4]));
                assert (previous_pc6 == $past(port_c_i[6]));
            end else if ($past(mode_set_event)) begin
                assert (control_word == $past(data_i));
                assert (port_a_output_latch == 8'h00);
                assert (port_b_output_latch == 8'h00);
                assert (port_c_output_latch == 8'h00);
                assert (port_a_input_latch == 8'h00);
                assert (port_b_input_latch == 8'h00);
                assert (!ibf_a && !ibf_b);
                assert (obf_a_n && obf_b_n);
                assert (!inte_a_input && !inte_a_output && !inte_b);
                assert (previous_pc2 == $past(port_c_i[2]));
                assert (previous_pc4 == $past(port_c_i[4]));
                assert (previous_pc6 == $past(port_c_i[6]));
            end else begin
                assert (control_word == $past(control_word));
                assert (previous_pc2 == $past(port_c_i[2]));
                assert (previous_pc4 == $past(port_c_i[4]));
                assert (previous_pc6 == $past(port_c_i[6]));

                if ($past(a_capture_event)) begin
                    assert (port_a_input_latch == $past(port_a_i));
                end else begin
                    assert (port_a_input_latch ==
                            $past(port_a_input_latch));
                end
                if ($past(b_capture_event)) begin
                    assert (port_b_input_latch == $past(port_b_i));
                end else begin
                    assert (port_b_input_latch ==
                            $past(port_b_input_latch));
                end

                if ($past(a_read_event)) begin
                    assert (!ibf_a);
                end else if ($past(a_capture_event)) begin
                    assert (ibf_a);
                end else begin
                    assert (ibf_a == $past(ibf_a));
                end
                if ($past(b_read_event)) begin
                    assert (!ibf_b);
                end else if ($past(b_capture_event)) begin
                    assert (ibf_b);
                end else begin
                    assert (ibf_b == $past(ibf_b));
                end

                if ($past(a_write_event)) begin
                    assert (port_a_output_latch == $past(data_i));
                end else begin
                    assert (port_a_output_latch ==
                            $past(port_a_output_latch));
                end
                if ($past(b_write_event)) begin
                    assert (port_b_output_latch == $past(data_i));
                end else begin
                    assert (port_b_output_latch ==
                            $past(port_b_output_latch));
                end

                if ($past(a_write_event &&
                          group_a_output_handshake)) begin
                    assert (!obf_a_n);
                end else if ($past(a_ack_event)) begin
                    assert (obf_a_n);
                end else begin
                    assert (obf_a_n == $past(obf_a_n));
                end
                if ($past(b_write_event &&
                          group_b_output_handshake)) begin
                    assert (!obf_b_n);
                end else if ($past(b_ack_event)) begin
                    assert (obf_b_n);
                end else begin
                    assert (obf_b_n == $past(obf_b_n));
                end

                if ($past(bus_write && (addr == 2'b10))) begin
                    assert (port_c_output_latch == $past(data_i));
                end else if ($past(bsr_write_event)) begin
                    assert (port_c_output_latch ==
                            bsr_updated_value(
                                $past(port_c_output_latch),
                                $past(data_i[3:1]), $past(data_i[0])));
                end else begin
                    assert (port_c_output_latch ==
                            $past(port_c_output_latch));
                end

                if ($past(bsr_write_event &&
                          group_a_input_handshake &&
                          (data_i[3:1] == 3'd4))) begin
                    assert (inte_a_input == $past(data_i[0]));
                end else begin
                    assert (inte_a_input == $past(inte_a_input));
                end
                if ($past(bsr_write_event &&
                          group_a_output_handshake &&
                          (data_i[3:1] == 3'd6))) begin
                    assert (inte_a_output == $past(data_i[0]));
                end else begin
                    assert (inte_a_output == $past(inte_a_output));
                end
                if ($past(bsr_write_event && group_b_mode &&
                          (data_i[3:1] == 3'd2))) begin
                    assert (inte_b == $past(data_i[0]));
                end else begin
                    assert (inte_b == $past(inte_b));
                end
            end
        end
    end

endmodule
