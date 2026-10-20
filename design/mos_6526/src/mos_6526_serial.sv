module mos_6526_serial (
    input logic clk, rst_n, output_mode_i, write_i,
    input logic [7:0] data_i,
    input logic cnt_rise_i, sp_i, baud_pulse_i,
    output logic [7:0] data_o,
    output logic cnt_o, cnt_oe, sp_o, sp_oe,
    output logic irq_event_o, active_o, pending_o
);
    logic [7:0] sdr_q, shift_q, pending_data_q;
    logic [2:0] bits_q;
    logic active_q, pending_q, previous_mode_q, cnt_q, sp_q;
    assign data_o = sdr_q;
    assign active_o = active_q;
    assign pending_o = pending_q;
    assign cnt_o = cnt_q;
    assign sp_o = sp_q;
    // Open drain: one means release, rather than an active high driver.
    assign cnt_oe = output_mode_i && !cnt_q;
    assign sp_oe = output_mode_i && !sp_q;
    assign irq_event_o = rst_n && previous_mode_q == output_mode_i &&
        ((!output_mode_i && cnt_rise_i && bits_q == 7) ||
         (output_mode_i && baud_pulse_i && active_q && !cnt_q && bits_q == 7));
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sdr_q <= 0; shift_q <= 0; pending_data_q <= 0;
            bits_q <= 0; active_q <= 0; pending_q <= 0;
            previous_mode_q <= 0; cnt_q <= 1; sp_q <= 1;
        end else begin
            previous_mode_q <= output_mode_i;
            if (previous_mode_q != output_mode_i) begin
                // ASSUMPTION: direction transition flush/release; see spec.
                shift_q <= 0; bits_q <= 0; active_q <= 0; pending_q <= 0;
                cnt_q <= 1; sp_q <= 1;
            end else if (!output_mode_i) begin
                if (cnt_rise_i) begin
                    shift_q <= {shift_q[6:0],sp_i};
                    bits_q <= bits_q+3'd1;
                    if (bits_q == 7) sdr_q <= {shift_q[6:0],sp_i};
                end
            end else if (baud_pulse_i) begin
                if (!active_q && pending_q) begin
                    shift_q <= {pending_data_q[6:0],1'b0};
                    sp_q <= pending_data_q[7]; cnt_q <= 0;
                    bits_q <= 0; active_q <= 1; pending_q <= 0;
                end else if (active_q) begin
                    cnt_q <= !cnt_q;
                    if (cnt_q) begin
                        sp_q <= shift_q[7]; shift_q <= {shift_q[6:0],1'b0};
                    end else begin
                        bits_q <= bits_q+3'd1;
                        if (bits_q == 7) begin
                            if (pending_q) begin
                                shift_q <= pending_data_q;
                                pending_q <= 0;
                            end else active_q <= 0;
                        end
                    end
                end
            end
            if (write_i) begin
                // ASSUMPTION: CPU write wins a coincident receive completion;
                // a pending transmit slot keeps the latest written byte.
                sdr_q <= data_i;
                if (output_mode_i) begin pending_data_q <= data_i; pending_q <= 1; end
            end
        end
    end
`ifdef FORMAL
    `include "mos_6526_serial_props.sv"
`endif
endmodule
