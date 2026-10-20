// Integrated sampled CIA. Physical/revision qualifications: spec/spec.md.
module mos_6526 (
    input logic clk, rst_n, cs_n, rw,
    input logic [3:0] addr,
    input logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic data_oe,
    input logic [7:0] pa_i, pb_i,
    output logic [7:0] pa_o, pb_o, pa_oe, pb_oe,
    input logic cnt_i, sp_i, flag_n_i, tod_i,
    output logic cnt_o, cnt_oe, sp_o, sp_oe, pc_n, irq_n
);
    logic [7:0] pra_q, prb_q, ddra_q, ddrb_q, pa_sample_q, pb_sample_q;
    logic [2:0] cra_high_q, cra_low_q, crb_high_q, crb_low_q;
    logic [7:0] cra_value, crb_value, serial_data, tod_data, icr_data, unused_icr_state;
    logic cnt_sample_q, sp_sample_q, flag_sample_q, tod_sample_q;
    logic previous_cnt_q, previous_flag_q, previous_tod_q;
    logic cnt_rise, flag_fall, tod_rise, selected, wr, rd, boundary_clk;
    logic ta_started, tb_started, ta_underflow, tb_underflow, ta_event, tb_event;
    logic ta_read_started, tb_read_started;
    logic ta_toggle_q, tb_toggle_q, pc_q, tb_pulse, ta_pb, tb_pb;
    logic [15:0] unused_ta_count, unused_tb_count, unused_ta_latch, unused_tb_latch;
    logic [15:0] ta_read_count, tb_read_count;
    logic [4:0] interrupt_sources;
    logic serial_event, serial_cnt_drive, serial_sp_drive;
    logic unused_serial_active, unused_serial_pending, unused_tod_stopped, unused_tod_latched;
    logic [31:0] unused_tod_time, unused_tod_alarm;
    logic tod_event;
    logic unused_irq_state;

    assign boundary_clk = !clk;
    assign selected = !cs_n;
    assign wr = selected && !rw;
    assign rd = selected && rw;
    assign data_oe = rst_n && clk && rd;
    assign cnt_rise = cnt_sample_q && !previous_cnt_q;
    assign flag_fall = previous_flag_q && !flag_sample_q;
    assign tod_rise = tod_sample_q && !previous_tod_q;
    assign cra_value = {cra_high_q,1'b0,cra_low_q,ta_read_started};
    assign crb_value = {crb_high_q,1'b0,crb_low_q,tb_read_started};
    assign pa_o = pra_q;
    assign pa_oe = rst_n ? ddra_q : 8'b0;
    assign ta_pb = cra_low_q[1] ? ta_toggle_q : ta_underflow;
    assign tb_pb = crb_low_q[1] ? tb_toggle_q : tb_underflow;
    assign pb_o = {crb_low_q[0] ? tb_pb : prb_q[7],
                   cra_low_q[0] ? ta_pb : prb_q[6],prb_q[5:0]};
    assign pb_oe = rst_n ? ddrb_q | {crb_low_q[0],cra_low_q[0],6'b0} : 8'b0;
    assign cnt_oe = rst_n && serial_cnt_drive;
    assign sp_oe = rst_n && serial_sp_drive;
    assign pc_n = !rst_n || pc_q;
    assign interrupt_sources = {flag_fall,serial_event,tod_event,tb_event,ta_event};
    always_comb begin
        case (crb_high_q[1:0])
            2'b00: tb_pulse = 0;
            2'b01: tb_pulse = cnt_rise;
            2'b10: tb_pulse = ta_underflow;
            default: tb_pulse = ta_underflow && cnt_sample_q;
        endcase
        case (addr)
            0: data_o = pa_sample_q;
            // ASSUMPTION: timer-selected read bits bypass the GPIO sample
            // and use this cycle's timer result (Lorenz/VICE; spec ledger).
            1: data_o = {crb_low_q[0] ? (crb_low_q[1] ? tb_toggle_q ^ tb_event : tb_event) : pb_sample_q[7],
                         cra_low_q[0] ? (cra_low_q[1] ? ta_toggle_q ^ ta_event : ta_event) : pb_sample_q[6],
                         pb_sample_q[5:0]};
            2: data_o = ddra_q;
            3: data_o = ddrb_q;
            4: data_o = ta_read_count[7:0];
            5: data_o = ta_read_count[15:8];
            6: data_o = tb_read_count[7:0];
            7: data_o = tb_read_count[15:8];
            8,9,10,11: data_o = tod_data;
            12: data_o = serial_data;
            13: data_o = icr_data;
            14: data_o = cra_value;
            default: data_o = crb_value;
        endcase
    end
    // ASSUMPTION: once-per-PHI2 resolved-pin sampling. Shorter physical
    // pulses and the serial synchronizer's internal latches need captures.
    always_ff @(posedge clk) begin
        pa_sample_q <= pa_i; pb_sample_q <= pb_i;
        cnt_sample_q <= cnt_i; sp_sample_q <= sp_i;
        flag_sample_q <= flag_n_i; tod_sample_q <= tod_i;
    end
    always_ff @(negedge clk) begin
        if (!rst_n) begin
            pra_q <= 0; prb_q <= 0; ddra_q <= 0; ddrb_q <= 0;
            cra_high_q <= 0; cra_low_q <= 0; crb_high_q <= 0; crb_low_q <= 0;
            previous_cnt_q <= cnt_i; previous_flag_q <= flag_n_i; previous_tod_q <= tod_i;
            ta_toggle_q <= 0; tb_toggle_q <= 0; pc_q <= 1;
        end else begin
            previous_cnt_q <= cnt_sample_q;
            previous_flag_q <= flag_sample_q;
            previous_tod_q <= tod_sample_q;
            pc_q <= !(selected && addr == 1);
            if (ta_event) ta_toggle_q <= !ta_toggle_q;
            if (tb_event) tb_toggle_q <= !tb_toggle_q;
            if (wr) begin
                case (addr)
                    0: pra_q <= data_i;
                    1: prb_q <= data_i;
                    2: ddra_q <= data_i;
                    3: ddrb_q <= data_i;
                    14: begin
                        cra_high_q <= data_i[7:5]; cra_low_q <= data_i[3:1];
                        if (data_i[0] && !ta_started) ta_toggle_q <= 1;
                    end
                    15: begin
                        crb_high_q <= data_i[7:5]; crb_low_q <= data_i[3:1];
                        if (data_i[0] && !tb_started) tb_toggle_q <= 1;
                    end
                    default: ;
                endcase
            end
        end
    end
    mos_6526_timer timer_a (
        .clk(boundary_clk), .rst_n, .phi2_mode_i(!cra_high_q[0]),
        .pulse_i(cra_high_q[0] && cnt_rise),
        .write_low_i(wr && addr == 4), .write_high_i(wr && addr == 5),
        .write_control_i(wr && addr == 14), .data_i,
        .count_o(unused_ta_count), .latch_o(unused_ta_latch), .started_o(ta_started),
        .cycle_count_o(ta_read_count), .cycle_started_o(ta_read_started),
        .underflow_o(ta_underflow), .underflow_event_o(ta_event)
    );
    mos_6526_timer timer_b (
        .clk(boundary_clk), .rst_n, .phi2_mode_i(crb_high_q[1:0] == 0), .pulse_i(tb_pulse),
        .write_low_i(wr && addr == 6), .write_high_i(wr && addr == 7),
        .write_control_i(wr && addr == 15), .data_i,
        .count_o(unused_tb_count), .latch_o(unused_tb_latch), .started_o(tb_started),
        .cycle_count_o(tb_read_count), .cycle_started_o(tb_read_started),
        .underflow_o(tb_underflow), .underflow_event_o(tb_event)
    );
    mos_6526_tod tod_clock (
        .clk(boundary_clk), .rst_n, .edge_i(tod_rise), .mode_50hz_i(cra_high_q[2]),
        .write_i(wr && addr[3:2] == 2'b10), .read_i(rd && addr[3:2] == 2'b10),
        .alarm_select_i(crb_high_q[2]), .addr(addr[1:0]), .data_i, .data_o(tod_data),
        .alarm_event_o(tod_event), .stopped_o(unused_tod_stopped), .latched_o(unused_tod_latched),
        .time_o(unused_tod_time), .alarm_o(unused_tod_alarm)
    );
    mos_6526_serial serial_port (
        .clk(boundary_clk), .rst_n, .output_mode_i(cra_high_q[1]),
        .write_i(wr && addr == 12), .data_i, .cnt_rise_i(cnt_rise), .sp_i(sp_sample_q),
        .baud_pulse_i(ta_event && !cra_low_q[2]), .data_o(serial_data),
        .cnt_o, .cnt_oe(serial_cnt_drive), .sp_o, .sp_oe(serial_sp_drive),
        .irq_event_o(serial_event), .active_o(unused_serial_active), .pending_o(unused_serial_pending)
    );
    mos_6526_irq interrupt_control (
        .clk(boundary_clk), .rst_n, .read_i(rd && addr == 13), .write_i(wr && addr == 13),
        .data_i, .source_i(interrupt_sources), .data_o(unused_icr_state), .cycle_data_o(icr_data),
        .irq_n(unused_irq_state), .cycle_irq_n(irq_n)
    );
`ifdef FORMAL
    `include "mos_6526_props.sv"
`endif
endmodule
