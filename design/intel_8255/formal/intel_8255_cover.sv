module intel_8255_cover (
    input logic       clk,
    input logic       reset,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    input logic [7:0] port_a_oe,
    input logic [7:0] port_c_i,
    input logic [7:0] port_c_output_latch,
    input logic [7:0] control_word,
    input logic       ibf_a,
    input logic       ibf_b,
    input logic       obf_a_n,
    input logic       obf_b_n,
    input logic       intr_a,
    input logic       intr_b,
    input logic       previous_pc2,
    input logic       previous_pc4,
    input logic       previous_pc6,
    input logic       bus_read,
    input logic       bus_write
);

    logic [1:0] group_a_mode;
    logic       group_b_mode;
    logic       group_a_input_handshake;
    logic       group_a_output_handshake;
    logic       saw_non_default_mode;
    logic       a_output_write_seen;
    logic       a_output_ack_seen;
    logic       b_output_write_seen;
    logic       b_output_ack_seen;
    logic       bsr_pc7_pending;
    logic       reconfig_pending;
    logic       reset_conflict_pending;

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

    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (reset);
            saw_non_default_mode <= 1'b0;
            a_output_write_seen <= 1'b0;
            a_output_ack_seen <= 1'b0;
            b_output_write_seen <= 1'b0;
            b_output_ack_seen <= 1'b0;
            bsr_pc7_pending <= 1'b0;
            reconfig_pending <= 1'b0;
            reset_conflict_pending <= 1'b0;
        end else if (reset) begin
            saw_non_default_mode <= 1'b0;
            a_output_write_seen <= 1'b0;
            a_output_ack_seen <= 1'b0;
            b_output_write_seen <= 1'b0;
            b_output_ack_seen <= 1'b0;
            bsr_pc7_pending <= 1'b0;
            reconfig_pending <= 1'b0;
            reset_conflict_pending <= bus_write;
        end else begin
            if (control_word != 8'h9b) begin
                saw_non_default_mode <= 1'b1;
            end

            if (bus_write && (addr == 2'b00) &&
                (group_a_mode == 2'd1) && !control_word[4]) begin
                a_output_write_seen <= 1'b1;
            end
            if (a_output_write_seen && previous_pc6 && !port_c_i[6]) begin
                a_output_ack_seen <= 1'b1;
            end

            if (bus_write && (addr == 2'b01) && group_b_mode &&
                !control_word[1]) begin
                b_output_write_seen <= 1'b1;
            end
            if (b_output_write_seen && previous_pc2 && !port_c_i[2]) begin
                b_output_ack_seen <= 1'b1;
            end

            bsr_pc7_pending <= bus_write && (addr == 2'b11) &&
                               !data_i[7] &&
                               (data_i[3:1] == 3'd7) && data_i[0];
            reconfig_pending <= bus_write && (addr == 2'b11) &&
                                (data_i == 8'h9b) &&
                                saw_non_default_mode;
            reset_conflict_pending <= 1'b0;
        end

        cover (!$initstate && group_a_mode == 2'd0 &&
               port_a_oe == 8'hff && control_word[1] == 1'b0 &&
               control_word[3] == 1'b0 && control_word[0] == 1'b0);
        cover (!$initstate && group_a_mode == 2'd1 &&
               control_word[4] && ibf_a && intr_a);
        cover (!$initstate && a_output_ack_seen &&
               port_c_i[6] && intr_a);
        cover (!$initstate && group_b_mode && control_word[1] &&
               ibf_b && intr_b);
        cover (!$initstate && b_output_ack_seen &&
               port_c_i[2] && intr_b);
        cover (!$initstate && group_a_mode == 2'd2 &&
               !port_c_i[6] && port_a_oe == 8'hff);
        cover (!$initstate && group_a_mode == 2'd2 && ibf_a &&
               !obf_a_n && port_c_i[6] && port_a_oe == 8'h00);
        cover (!$initstate && bsr_pc7_pending &&
               port_c_output_latch[7]);
        cover (!$initstate && reconfig_pending &&
               control_word == 8'h9b);
        cover (!$initstate && group_a_input_handshake &&
               previous_pc4 && !port_c_i[4] &&
               bus_read && (addr == 2'b00));
        cover (!$initstate && group_a_output_handshake &&
               previous_pc6 && !port_c_i[6] &&
               bus_write && (addr == 2'b00));
        cover (!$initstate && reset_conflict_pending &&
               control_word == 8'h9b && !ibf_a && !ibf_b &&
               obf_a_n && obf_b_n);
    end

endmodule
