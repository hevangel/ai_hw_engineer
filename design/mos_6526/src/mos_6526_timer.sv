// Original cycle-completion timer; see spec/spec.md for oracle/phase contract.
module mos_6526_timer (
    input logic clk, rst_n, phi2_mode_i, pulse_i,
    input logic write_low_i, write_high_i, write_control_i,
    input logic [7:0] data_i,
    output logic [15:0] count_o, latch_o,
    output logic started_o, underflow_o, underflow_event_o
);
    logic [15:0] count_q, latch_q, count_next, latch_next;
    logic started_q, started_next, oneshot_q;
    logic enable_early_q, enable_late_q, enable_early_next, enable_late_next;
    logic load_request_q, load_delay_q, load_next;
    logic oneshot_early_q, underflow_next;
    assign count_o = count_q;
    assign latch_o = latch_q;
    assign started_o = started_q;
    // Pre-boundary event lets a same-edge peripheral consume the underflow
    // without inserting another register delay. underflow_o retains the
    // post-boundary event for pulse outputs and delayed cascaded sources.
    assign underflow_event_o = rst_n && underflow_next;

    // ASSUMPTION: sampled pipeline follows the pinned independent VICE timer
    // profile; this is not a claim about every subcycle physical race.
    always_comb begin
        latch_next = latch_q;
        if (write_low_i) latch_next[7:0] = data_i;
        if (write_high_i) latch_next[15:8] = data_i;
        count_next = count_q;
        if (enable_late_q && count_q != 0) count_next = count_q-16'd1;
        enable_early_next = started_q && phi2_mode_i;
        enable_late_next = enable_early_q || (pulse_i && started_q);
        underflow_next = count_next == 0 && enable_late_next;
        load_next = load_delay_q || underflow_next;
        started_next = started_q;
        if (load_next) begin
            count_next = latch_q;
            enable_late_next = 0;
        end
        if (underflow_next && (oneshot_q || oneshot_early_q)) begin
            started_next = 0;
            enable_early_next = 0;
        end
        // Boundary writes occur after the old cycle completes. In particular,
        // a write coincident with reload affects the counter as well as latch.
        if (write_high_i && (load_next || !started_next)) count_next = latch_next;
        if (write_low_i && load_next) count_next[7:0] = data_i;
        if (write_control_i) started_next = data_i[0];
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count_q <= 16'hffff; latch_q <= 16'hffff;
            started_q <= 0; oneshot_q <= 0;
            enable_early_q <= 0; enable_late_q <= 0;
            load_request_q <= 0; load_delay_q <= 0;
            oneshot_early_q <= 0;
            underflow_o <= 0;
        end else begin
            count_q <= count_next; latch_q <= latch_next; started_q <= started_next;
            enable_early_q <= enable_early_next; enable_late_q <= enable_late_next;
            load_delay_q <= load_request_q;
            load_request_q <= write_control_i && data_i[4];
            oneshot_early_q <= oneshot_q;
            if (write_control_i) oneshot_q <= data_i[3];
            underflow_o <= underflow_next;
        end
    end
`ifdef FORMAL
    `include "mos_6526_timer_props.sv"
`endif
endmodule
