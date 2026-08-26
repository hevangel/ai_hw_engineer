`timescale 1ns/1ps

module intel_8255 (
    input  logic       clk,
    input  logic       reset,

    input  logic       cs_n,
    input  logic       rd_n,
    input  logic       wr_n,
    input  logic [1:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,

    input  logic [7:0] port_a_i,
    output logic [7:0] port_a_o,
    output logic [7:0] port_a_oe,
    input  logic [7:0] port_b_i,
    output logic [7:0] port_b_o,
    output logic [7:0] port_b_oe,
    input  logic [7:0] port_c_i,
    output logic [7:0] port_c_o,
    output logic [7:0] port_c_oe
);

    logic [7:0] control_word;
    logic [7:0] port_a_output_latch;
    logic [7:0] port_b_output_latch;
    logic [7:0] port_c_output_latch;
    logic [7:0] port_a_input_latch;
    logic [7:0] port_b_input_latch;

    logic       ibf_a;
    logic       ibf_b;
    logic       obf_a_n;
    logic       obf_b_n;
    logic       inte_a_input;
    logic       inte_a_output;
    logic       inte_b;
    logic       previous_pc2;
    logic       previous_pc4;
    logic       previous_pc6;

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
    logic [7:0] port_c_read_value;

    assign group_a_mode = (!control_word[7]) ? 2'd0 :
                          (control_word[6] ? 2'd2 :
                           (control_word[5] ? 2'd1 : 2'd0));
    assign group_b_mode = control_word[2];

    assign group_a_input_handshake = (group_a_mode == 2'd2) ||
                                     ((group_a_mode == 2'd1) && control_word[4]);
    assign group_a_output_handshake = (group_a_mode == 2'd2) ||
                                      ((group_a_mode == 2'd1) && !control_word[4]);
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

    always_comb begin
        port_a_o = port_a_output_latch;
        port_b_o = port_b_output_latch;
        port_c_o = port_c_output_latch;

        if (group_a_mode == 2'd2) begin
            port_a_oe = {8{!port_c_i[6]}};
        end else begin
            port_a_oe = control_word[4] ? 8'h00 : 8'hff;
        end
        port_b_oe = control_word[1] ? 8'h00 : 8'hff;

        port_c_oe[7:4] = control_word[3] ? 4'h0 : 4'hf;
        port_c_oe[3:0] = control_word[0] ? 4'h0 : 4'hf;
        port_c_read_value[7:4] = control_word[3] ?
                                      port_c_i[7:4] : port_c_output_latch[7:4];
        port_c_read_value[3:0] = control_word[0] ?
                                      port_c_i[3:0] : port_c_output_latch[3:0];

        if (group_a_mode == 2'd1) begin
            port_c_o[3] = intr_a;
            port_c_oe[3] = 1'b1;
            port_c_read_value[3] = intr_a;
            if (control_word[4]) begin
                port_c_oe[4] = 1'b0;
                port_c_o[5] = ibf_a;
                port_c_oe[5] = 1'b1;
                port_c_read_value[4] = port_c_i[4];
                port_c_read_value[5] = ibf_a;
            end else begin
                port_c_oe[6] = 1'b0;
                port_c_o[7] = obf_a_n;
                port_c_oe[7] = 1'b1;
                port_c_read_value[6] = port_c_i[6];
                port_c_read_value[7] = obf_a_n;
            end
        end else if (group_a_mode == 2'd2) begin
            port_c_o[3] = intr_a;
            port_c_oe[3] = 1'b1;
            port_c_oe[4] = 1'b0;
            port_c_o[5] = ibf_a;
            port_c_oe[5] = 1'b1;
            port_c_oe[6] = 1'b0;
            port_c_o[7] = obf_a_n;
            port_c_oe[7] = 1'b1;
            port_c_read_value[3] = intr_a;
            port_c_read_value[4] = port_c_i[4];
            port_c_read_value[5] = ibf_a;
            port_c_read_value[6] = port_c_i[6];
            port_c_read_value[7] = obf_a_n;
        end

        if (group_b_mode) begin
            port_c_o[0] = intr_b;
            port_c_oe[0] = 1'b1;
            port_c_oe[2] = 1'b0;
            port_c_read_value[0] = intr_b;
            port_c_read_value[2] = port_c_i[2];
            if (control_word[1]) begin
                port_c_o[1] = ibf_b;
                port_c_read_value[1] = ibf_b;
            end else begin
                port_c_o[1] = obf_b_n;
                port_c_read_value[1] = obf_b_n;
            end
            port_c_oe[1] = 1'b1;
        end

        data_o = 8'h00;
        data_oe = 1'b0;
        if (bus_read) begin
            case (addr)
                2'b00: begin
                    data_oe = 1'b1;
                    if (group_a_input_handshake) begin
                        data_o = port_a_input_latch;
                    end else if (control_word[4]) begin
                        data_o = port_a_i;
                    end else begin
                        data_o = port_a_output_latch;
                    end
                end
                2'b01: begin
                    data_oe = 1'b1;
                    if (group_b_input_handshake) begin
                        data_o = port_b_input_latch;
                    end else if (control_word[1]) begin
                        data_o = port_b_i;
                    end else begin
                        data_o = port_b_output_latch;
                    end
                end
                2'b10: begin
                    data_o = port_c_read_value;
                    data_oe = 1'b1;
                end
                default: begin
                    data_o = 8'h00;
                    data_oe = 1'b0;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            control_word <= 8'h9b;
            port_a_output_latch <= 8'h00;
            port_b_output_latch <= 8'h00;
            port_c_output_latch <= 8'h00;
            port_a_input_latch <= 8'h00;
            port_b_input_latch <= 8'h00;
            ibf_a <= 1'b0;
            ibf_b <= 1'b0;
            obf_a_n <= 1'b1;
            obf_b_n <= 1'b1;
            inte_a_input <= 1'b0;
            inte_a_output <= 1'b0;
            inte_b <= 1'b0;
            previous_pc2 <= port_c_i[2];
            previous_pc4 <= port_c_i[4];
            previous_pc6 <= port_c_i[6];
        end else if (bus_write && (addr == 2'b11) && data_i[7]) begin
            control_word <= data_i;
            port_a_output_latch <= 8'h00;
            port_b_output_latch <= 8'h00;
            port_c_output_latch <= 8'h00;
            port_a_input_latch <= 8'h00;
            port_b_input_latch <= 8'h00;
            ibf_a <= 1'b0;
            ibf_b <= 1'b0;
            obf_a_n <= 1'b1;
            obf_b_n <= 1'b1;
            inte_a_input <= 1'b0;
            inte_a_output <= 1'b0;
            inte_b <= 1'b0;
            previous_pc2 <= port_c_i[2];
            previous_pc4 <= port_c_i[4];
            previous_pc6 <= port_c_i[6];
        end else begin
            previous_pc2 <= port_c_i[2];
            previous_pc4 <= port_c_i[4];
            previous_pc6 <= port_c_i[6];

            if (group_a_input_handshake && previous_pc4 &&
                !port_c_i[4]) begin
                port_a_input_latch <= port_a_i;
                ibf_a <= 1'b1;
            end
            if (group_a_output_handshake && previous_pc6 &&
                !port_c_i[6]) begin
                obf_a_n <= 1'b1;
            end
            if (group_b_input_handshake && previous_pc2 &&
                !port_c_i[2]) begin
                port_b_input_latch <= port_b_i;
                ibf_b <= 1'b1;
            end
            if (group_b_output_handshake && previous_pc2 &&
                !port_c_i[2]) begin
                obf_b_n <= 1'b1;
            end

            if (bus_write) begin
                case (addr)
                    2'b00: begin
                        if ((group_a_mode == 2'd2) || !control_word[4]) begin
                            port_a_output_latch <= data_i;
                            if (group_a_output_handshake) begin
                                obf_a_n <= 1'b0;
                            end
                        end
                    end
                    2'b01: begin
                        if (!control_word[1]) begin
                            port_b_output_latch <= data_i;
                            if (group_b_output_handshake) begin
                                obf_b_n <= 1'b0;
                            end
                        end
                    end
                    2'b10: begin
                        port_c_output_latch <= data_i;
                    end
                    default: begin
                        if (!data_i[7]) begin
                            port_c_output_latch[data_i[3:1]] <= data_i[0];
                            if (group_a_input_handshake &&
                                (data_i[3:1] == 3'd4)) begin
                                inte_a_input <= data_i[0];
                            end
                            if (group_a_output_handshake &&
                                (data_i[3:1] == 3'd6)) begin
                                inte_a_output <= data_i[0];
                            end
                            if (group_b_mode && (data_i[3:1] == 3'd2)) begin
                                inte_b <= data_i[0];
                            end
                        end
                    end
                endcase
            end

            if (bus_read) begin
                case (addr)
                    2'b00: begin
                        if (group_a_input_handshake) begin
                            ibf_a <= 1'b0;
                        end
                    end
                    2'b01: begin
                        if (group_b_input_handshake) begin
                            ibf_b <= 1'b0;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

`ifdef FORMAL
`ifdef FORMAL_COVER
    intel_8255_cover formal_coverage (
        .clk                 (clk),
        .reset               (reset),
        .addr                (addr),
        .data_i              (data_i),
        .port_a_oe           (port_a_oe),
        .port_c_i            (port_c_i),
        .port_c_output_latch (port_c_output_latch),
        .control_word        (control_word),
        .ibf_a               (ibf_a),
        .ibf_b               (ibf_b),
        .obf_a_n             (obf_a_n),
        .obf_b_n             (obf_b_n),
        .intr_a              (intr_a),
        .intr_b              (intr_b),
        .previous_pc2        (previous_pc2),
        .previous_pc4        (previous_pc4),
        .previous_pc6        (previous_pc6),
        .bus_read            (bus_read),
        .bus_write           (bus_write)
    );
`else
    intel_8255_props formal_properties (
        .clk                      (clk),
        .reset                    (reset),
        .cs_n                     (cs_n),
        .rd_n                     (rd_n),
        .wr_n                     (wr_n),
        .addr                     (addr),
        .data_i                   (data_i),
        .data_o                   (data_o),
        .data_oe                  (data_oe),
        .port_a_i                 (port_a_i),
        .port_a_o                 (port_a_o),
        .port_a_oe                (port_a_oe),
        .port_b_i                 (port_b_i),
        .port_b_o                 (port_b_o),
        .port_b_oe                (port_b_oe),
        .port_c_i                 (port_c_i),
        .port_c_o                 (port_c_o),
        .port_c_oe                (port_c_oe),
        .control_word             (control_word),
        .port_a_output_latch      (port_a_output_latch),
        .port_b_output_latch      (port_b_output_latch),
        .port_c_output_latch      (port_c_output_latch),
        .port_a_input_latch       (port_a_input_latch),
        .port_b_input_latch       (port_b_input_latch),
        .ibf_a                    (ibf_a),
        .ibf_b                    (ibf_b),
        .obf_a_n                  (obf_a_n),
        .obf_b_n                  (obf_b_n),
        .inte_a_input             (inte_a_input),
        .inte_a_output            (inte_a_output),
        .inte_b                   (inte_b),
        .previous_pc2             (previous_pc2),
        .previous_pc4             (previous_pc4),
        .previous_pc6             (previous_pc6)
    );
`endif
`endif

endmodule
