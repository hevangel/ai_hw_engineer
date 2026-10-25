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
    logic [3:0] tx_irq_q;
    logic active_q, pending_q, previous_mode_q, cnt_q, sp_q;
    logic shifter_free_q, last_bit;
    assign last_bit = baud_pulse_i && active_q && cnt_q && bits_q == 7;
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
         (output_mode_i && tx_irq_q[3]));
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sdr_q <= 0; shift_q <= 0; pending_data_q <= 0;
            tx_irq_q <= 0;
            bits_q <= 0; active_q <= 0; pending_q <= 0;
            shifter_free_q <= 1;
            previous_mode_q <= 0; cnt_q <= 1; sp_q <= 1;
        end else begin
            // ASSUMPTION: sampled request phase matching the original
            // cia-sdr-delay hardware table (VICE SVN 45953); physical pin
            // synchronization remains open in spec/spec.md.
            // request four PHI2 clocks after bit 8 is presented, before
            // the final CNT rising edge when the divider is sufficiently slow.
            tx_irq_q <= {tx_irq_q[2:0], output_mode_i &&
                previous_mode_q == output_mode_i && baud_pulse_i &&
                last_bit};
            previous_mode_q <= output_mode_i;
            if (previous_mode_q != output_mode_i) begin
                // ASSUMPTION: direction transition flush/release; see spec.
                shift_q <= 0; bits_q <= 0; active_q <= 0; pending_q <= 0;
                tx_irq_q <= 0;
                shifter_free_q <= 1;
                cnt_q <= 1; sp_q <= 1;
            end else if (!output_mode_i) begin
                if (cnt_rise_i) begin
                    shift_q <= {shift_q[6:0],sp_i};
                    bits_q <= bits_q+3'd1;
                    if (bits_q == 7) sdr_q <= {shift_q[6:0],sp_i};
                end
            end else begin
                if (!active_q && pending_q) begin
                    shift_q <= pending_data_q;
                    bits_q <= 0; active_q <= 1; pending_q <= 0;
                    shifter_free_q <= 0;
                    if (baud_pulse_i) begin
                        shift_q <= {pending_data_q[6:0],1'b0};
                        sp_q <= pending_data_q[7]; cnt_q <= 0;
                    end
                end else if (active_q && baud_pulse_i) begin
                    cnt_q <= !cnt_q;
                    if (cnt_q) begin
                        sp_q <= shift_q[7]; shift_q <= {shift_q[6:0],1'b0};
                        // SP now holds bit 8 independently of the shifter.
                        // The original SDR-load test requires the next byte
                        // to be accepted before the final CNT rising edge.
                        if (bits_q == 7) begin
                            shifter_free_q <= 1;
                        end
                    end else begin
                        bits_q <= bits_q+3'd1;
                        if (bits_q == 7) begin
                            if (pending_q) begin
                                shift_q <= pending_data_q;
                                pending_q <= 0; shifter_free_q <= 0;
                            end else active_q <= 0;
                        end
                    end
                end
            end
            if (write_i) begin
                // ASSUMPTION: CPU write wins a coincident receive completion;
                // a pending transmit slot keeps the latest written byte.
                sdr_q <= data_i;
                if (output_mode_i) begin
                    pending_data_q <= data_i; pending_q <= 1;
                    // ASSUMPTION: sampled idle preload; the exact load
                    // pipeline near baud edges remains in the source ledger.
                    if (previous_mode_q == output_mode_i &&
                        ((!active_q && !pending_q) ||
                         (active_q && shifter_free_q))) begin
                        shift_q <= data_i; active_q <= 1;
                        shifter_free_q <= 0; pending_q <= 0;
                        // Independent MAME serial_load/output releases CNT
                        // between bytes instead of waiting out the old tail.
                        // The previous final SP bit is retained on this edge.
                        cnt_q <= 1; bits_q <= 0;
                    end
                end
            end
        end
    end
`ifdef FORMAL
    `include "mos_6526_serial_props.sv"
`endif
endmodule
