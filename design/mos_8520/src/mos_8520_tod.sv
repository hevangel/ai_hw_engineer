// 8520 time-of-day: a 24-bit binary event counter clocked by rising TOD
// pin edges, serviced on a phase-two/4 divider, with an edge-triggered
// alarm comparator. Behavior follows the pinned MAME 8520 model
// (spec/spec.md); registers 8/9/A are the low/middle/high bytes.
module mos_8520_tod (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       edge_i,          // rising TOD pin edge this cycle
    input  logic       write_i,
    input  logic       read_i,
    input  logic       alarm_select_i,  // CRB bit 7: writes go to the alarm
    input  logic [1:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       alarm_event_o,
    output logic [23:0] time_o,
    output logic [23:0] alarm_o
);
    logic [23:0] time_q, time_d, alarm_q, alarm_d, latch_q, latch_d;
    logic [1:0]  div_q, div_d;
    logic        pending_q, pending_d, stopped_q, stopped_d, latched_q, latched_d;
    logic        match_q, match_d, alarm_pending_q, alarm_pending_d;
    logic [23:0] view;
    logic        cmp;

    // Edge-triggered comparator: a new match (by tick or write) raises it.
    function automatic logic compare(input logic [23:0] t, input logic [23:0] a,
                                           input logic previous);
        compare = (t == a) && !previous;
    endfunction

    always_comb begin
        time_d = time_q;
        alarm_d = alarm_q;
        latch_d = latch_q;
        div_d = div_q;
        pending_d = pending_q;
        stopped_d = stopped_q;
        latched_d = latched_q;
        match_d = match_q;
        alarm_pending_d = 0;
        view = latched_q ? latch_q : time_q;
        cmp = 0;
        data_o = 8'hff;
        case (addr)
            2'd0: data_o = view[7:0];
            2'd1: data_o = view[15:8];
            2'd2: data_o = (!latched_q && !alarm_select_i) ? time_q[23:16] : view[23:16];
            default: data_o = 8'hff;
        endcase

        if (rst_n) begin
            // CPU access first (reads/writes complete before the cycle).
            if (read_i) begin
                if (addr == 2'd0) latched_d = 0;
                if (addr == 2'd2 && !latched_q && !alarm_select_i) begin
                    latched_d = 1;
                    latch_d = time_q;
                end
            end
            if (write_i && addr != 2'd3) begin
                if (addr == 2'd2 && !alarm_select_i) stopped_d = 1;
                if (alarm_select_i)
                    alarm_d[8*addr +: 8] = data_i;
                else
                    time_d[8*addr +: 8] = data_i;
                alarm_pending_d = compare(time_d, alarm_d, match_d);
                match_d = time_d == alarm_d;
                if (addr == 2'd0 && !alarm_select_i && stopped_d) stopped_d = 0;
            end

            // Phase-two cycle: pin edge, then the /4 divider services it.
            if (edge_i) pending_d = 1;
            div_d = div_q + 2'd1;
            if (div_d == 0) begin
                if (pending_d) begin
                    pending_d = 0;
                    if (!stopped_d) begin
                        // The carry ripples by nibbles; the comparator sees
                        // the half-way value of a $xxxFFF tick.
                        if (time_d[11:0] == 12'hfff) begin
                            time_d[11:0] = 0;
                            cmp = compare(time_d, alarm_d, match_d);
                            if (cmp) alarm_pending_d = 1;
                            match_d = time_d == alarm_d;
                            time_d = time_d + 24'h001000;
                        end else begin
                            time_d = time_d + 24'd1;
                        end
                    end
                end
                cmp = compare(time_d, alarm_d, match_d);
                if (cmp) alarm_pending_d = 1;
                match_d = time_d == alarm_d;
            end
        end
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization matches the reference reset:
        // time and alarm zero (equal, so no edge), clock stopped.
        if (!rst_n) begin
            time_q <= 0;
            alarm_q <= 0;
            latch_q <= 0;
            div_q <= 0;
            pending_q <= 0;
            stopped_q <= 1;
            latched_q <= 0;
            match_q <= 1;
            alarm_pending_q <= 0;
        end else begin
            time_q <= time_d;
            alarm_q <= alarm_d;
            latch_q <= latch_d;
            div_q <= div_d;
            pending_q <= pending_d;
            stopped_q <= stopped_d;
            latched_q <= latched_d;
            match_q <= match_d;
            alarm_pending_q <= alarm_pending_d;
        end
    end

`ifdef FORMAL
    `include "mos_8520_tod_props.sv"
`endif

    assign alarm_event_o = alarm_pending_q;
    assign time_o = time_q;
    assign alarm_o = alarm_q;
endmodule
