module mos_6522 (
    input  logic       clk, rst_n, cs1, cs2_n, rw,
    input  logic [3:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,
    input  logic [7:0] pa_i, pb_i,
    output logic [7:0] pa_o, pb_o, pa_oe, pb_oe,
    input  logic       ca1_i, ca2_i, cb1_i, cb2_i,
    output logic       ca2_o, ca2_oe, cb1_o, cb1_oe, cb2_o, cb2_oe,
    output logic       irq_n
);
    logic [7:0] ora, orb, ddra, ddrb, ira, irb, acr, pcr, sr;
    logic [6:0] ifr, ier, irq_set, irq_clear;
    logic [15:0] t1_count, t1_latch, t2_count;
    logic [7:0] t2_latch;
    logic t1_running, t1_armed, t1_wait, t1_reload, t1_pb7;
    logic t2_running, t2_armed, t2_wait, t2_reload;
    logic prev_ca1, prev_ca2, prev_cb1, prev_cb2, prev_pb6;
    logic ca1_event, ca2_event, cb1_event, cb2_event;
    logic selected, wr, rd, pa_access, pb_access, sr_access;
    logic ca2_handshake, cb2_handshake;
    logic [2:0] ca2_mode, cb2_mode, sr_mode, sr_bits;
    logic [7:0] pb_value, pb_read;
    logic t1_underflow, t2_step, t2_underflow, t2_low_underflow;
    logic sr_t2, sr_external, sr_internal, sr_running, sr_clk, sr_data;
    logic sr_start_delay, sr_last_pending, sr_irq_delay;
    logic sr_toggle, sr_input, sr_output, sr_out_finish, sr_complete;

    assign selected = cs1 && !cs2_n;
    assign wr = selected && !rw;
    assign rd = selected && rw;
    assign pa_access = selected && addr == 4'h1;
    assign pb_access = selected && addr == 4'h0;
    assign sr_access = selected && addr == 4'ha;
    assign data_oe = clk && rst_n && selected && rw;
    assign irq_n = !(rst_n && |(ifr & ier));
    assign ca2_mode = pcr[3:1];
    assign cb2_mode = pcr[7:5];
    assign sr_mode = acr[4:2];
    assign sr_t2 = sr_mode == 1 || sr_mode == 4 || sr_mode == 5;
    assign sr_external = sr_mode == 3 || sr_mode == 7;
    assign sr_internal = sr_mode != 0 && !sr_external;
    assign pa_o = ora;
    assign pa_oe = ddra;
    assign pb_value = {acr[7] ? t1_pb7 : orb[7], orb[6:0]};
    assign pb_o = pb_value;
    assign pb_oe = ddrb | {acr[7], 7'b0};
    assign pb_read = (pb_value & pb_oe) | (pb_i & ~pb_oe);
    assign ca2_oe = ca2_mode[2];
    assign ca2_o = ca2_mode[1] ? ca2_mode[0] : ca2_handshake;
    assign cb1_oe = sr_internal;
    assign cb1_o = sr_clk;
    assign cb2_oe = sr_mode != 0 ? sr_mode[2] : cb2_mode[2];
    assign cb2_o = sr_mode[2] ?
        ((sr_running || sr_external || sr_mode == 4) ? sr_data : pcr[5]) :
        (cb2_mode[1] ? cb2_mode[0] : cb2_handshake);

    // ASSUMPTION: asynchronous peripheral pins are sampled once per falling edge.
    assign ca1_event = ca1_i != prev_ca1 && ca1_i == pcr[0];
    assign ca2_event = !ca2_mode[2] && ca2_i != prev_ca2 && ca2_i == ca2_mode[1];
    assign cb1_event = sr_internal ? (sr_toggle && !sr_clk == pcr[4]) :
        (cb1_i != prev_cb1 && cb1_i == pcr[4]);
    assign cb2_event = sr_mode == 0 && !cb2_mode[2] &&
        cb2_i != prev_cb2 && cb2_i == cb2_mode[1];

    assign t1_underflow = t1_running && !t1_wait && !t1_reload && t1_count == 0;
    assign t2_step = (t2_running || sr_t2) && !t2_wait &&
        (!acr[5] || (prev_pb6 && !pb_i[6]));
    assign t2_low_underflow = t2_step && !t2_reload && t2_count[7:0] == 0;
    assign t2_underflow = t2_low_underflow && t2_count[15:8] == 0;
    assign sr_toggle = sr_running && sr_internal &&
        (sr_t2 ? t2_low_underflow : !sr_start_delay);
    assign sr_input = sr_running && !sr_mode[2] && sr_mode != 0 &&
        (sr_external ? (!prev_cb1 && cb1_i) : (sr_toggle && !sr_clk));
    assign sr_output = sr_running && sr_mode[2] &&
        (sr_external ? (prev_cb1 && !cb1_i) : (sr_toggle && sr_clk));
    assign sr_out_finish = sr_running && sr_mode[2] && !sr_external && sr_mode != 4 &&
        sr_last_pending && sr_toggle && !sr_clk;
    assign sr_complete = sr_irq_delay || sr_out_finish ||
        (sr_external && (sr_input || sr_output) && sr_bits == 7);

    always_comb begin
        case (addr)
            4'h0: data_o = acr[1] && ifr[4] ? irb : pb_read;
            4'h1, 4'hf: data_o = acr[0] && ifr[1] ? ira : pa_i;
            4'h2: data_o = ddrb;
            4'h3: data_o = ddra;
            4'h4: data_o = t1_count[7:0];
            4'h5: data_o = t1_count[15:8];
            4'h6: data_o = t1_latch[7:0];
            4'h7: data_o = t1_latch[15:8];
            4'h8: data_o = t2_count[7:0];
            4'h9: data_o = t2_count[15:8];
            4'ha: data_o = sr;
            4'hb: data_o = acr;
            4'hc: data_o = pcr;
            4'hd: data_o = {|(ifr & ier), ifr};
            // ASSUMPTION: IER7=1 per independent MAME; MOS prose says zero.
            4'he: data_o = {1'b1, ier};
            default: data_o = 0;
        endcase
    end

    always_comb begin
        irq_clear = 0;
        if (wr && addr == 4'hd) irq_clear = data_i[6:0];
        if (pa_access) begin
            irq_clear[1] = 1;
            if (!ca2_mode[0]) irq_clear[0] = 1;
        end
        if (pb_access) begin
            irq_clear[4] = 1;
            if (!cb2_mode[0]) irq_clear[3] = 1;
        end
        if ((rd && addr == 4'h4) || (wr && (addr == 4'h5 || addr == 4'h7)))
            irq_clear[6] = 1;
        if ((rd && addr == 4'h8) || (wr && addr == 4'h9)) irq_clear[5] = 1;
        if (sr_access || sr_mode == 0 || (wr && addr == 4'hb && data_i[4:2] == 0))
            irq_clear[2] = 1;
        irq_set = 0;
        irq_set[0] = ca2_event;
        irq_set[1] = ca1_event;
        irq_set[2] = sr_complete && sr_mode != 0;
        irq_set[3] = cb2_event;
        irq_set[4] = cb1_event;
        irq_set[5] = t2_underflow && t2_armed && !(wr && addr == 4'h9);
        irq_set[6] = t1_underflow && (t1_armed || acr[6]) && !(wr && addr == 4'h5);
    end

    always_ff @(negedge clk) begin
        if (!rst_n) begin
            ora <= 0; orb <= 0; ddra <= 0; ddrb <= 0;
            ira <= 0; irb <= 0; acr <= 0; pcr <= 0; ifr <= 0; ier <= 0;
            // ASSUMPTION: unspecified timer/SR reset contents are deterministic.
            t1_count <= 0; t1_latch <= 0; t2_count <= 0; t2_latch <= 0;
            t1_running <= 0; t1_armed <= 0; t1_wait <= 0; t1_reload <= 0; t1_pb7 <= 1;
            t2_running <= 0; t2_armed <= 0; t2_wait <= 0; t2_reload <= 0;
            prev_ca1 <= ca1_i; prev_ca2 <= ca2_i;
            prev_cb1 <= cb1_i; prev_cb2 <= cb2_i; prev_pb6 <= pb_i[6];
            ca2_handshake <= 1; cb2_handshake <= 1;
            sr <= 0; sr_bits <= 0; sr_running <= 0; sr_clk <= 1; sr_data <= 1;
            sr_start_delay <= 0; sr_last_pending <= 0; sr_irq_delay <= 0;
        end else begin
            prev_ca1 <= ca1_i; prev_ca2 <= ca2_i;
            prev_cb1 <= cb1_i; prev_cb2 <= cb2_i; prev_pb6 <= pb_i[6];
            // ASSUMPTION: newly sampled events win simultaneous acknowledgments.
            ifr <= (ifr & ~irq_clear) | irq_set;
            if (!acr[0] || !ifr[1]) ira <= pa_i;
            if (!acr[1] || !ifr[4]) irb <= pb_read;
            if (ca2_mode == 5 || ca2_mode < 4) ca2_handshake <= 1;
            if (cb2_mode == 5 || cb2_mode < 4) cb2_handshake <= 1;
            if (pa_access && (ca2_mode == 4 || ca2_mode == 5)) ca2_handshake <= 0;
            if (wr && addr == 0 && (cb2_mode == 4 || cb2_mode == 5)) cb2_handshake <= 0;
            if (ca1_event && ca2_mode == 4) ca2_handshake <= 1;
            if (cb1_event && cb2_mode == 4) cb2_handshake <= 1;

            if (t1_running) begin
                if (t1_wait) t1_wait <= 0;
                else if (t1_reload) begin
                    // ASSUMPTION: one-shot also reloads, as MAME counter readback does.
                    t1_count <= t1_latch;
                    t1_reload <= 0;
                end else begin
                    t1_count <= t1_count - 16'd1;
                    if (t1_underflow) begin
                        t1_reload <= 1;
                        t1_armed <= 0;
                        if (acr[7] && (t1_armed || acr[6]))
                            t1_pb7 <= acr[6] ? !t1_pb7 : 1'b1;
                    end
                end
            end
            if (t2_wait) t2_wait <= 0;
            else if (t2_step) begin
                if (sr_t2 && t2_reload) begin
                    t2_count[7:0] <= t2_latch;
                    t2_reload <= 0;
                end else begin
                    t2_count <= t2_count - 16'd1;
                    if (t2_low_underflow && sr_t2) t2_reload <= 1;
                    if (t2_underflow) t2_armed <= 0;
                end
            end

            sr_irq_delay <= 0;
            if (sr_start_delay) sr_start_delay <= 0;
            if (sr_toggle) sr_clk <= !sr_clk;
            if (sr_input || sr_output) begin
                sr <= {sr[6:0], sr_mode[2] ? sr[7] : cb2_i};
                sr_bits <= sr_bits + 3'd1;
                if (sr_output) sr_data <= sr[7];
                if (sr_bits == 7 && !sr_external && sr_mode != 4) begin
                    if (sr_mode[2]) sr_last_pending <= 1;
                    else begin
                        sr_running <= 0;
                        sr_irq_delay <= 1;
                    end
                end
            end
            if (sr_out_finish) begin
                sr_running <= 0;
                sr_last_pending <= 0;
            end
            if (sr_access) begin
                if (wr) sr <= data_i;
                sr_bits <= 0;
                sr_running <= sr_mode != 0;
                sr_last_pending <= 0;
                sr_irq_delay <= 0;
                // ASSUMPTION: phi2 shifter initial edge is two clocks after start.
                sr_start_delay <= 1;
                if (!sr_running) sr_clk <= 1;
            end

            if (wr) begin
                case (addr)
                    4'h0: orb <= data_i;
                    4'h1, 4'hf: ora <= data_i;
                    4'h2: ddrb <= data_i;
                    4'h3: ddra <= data_i;
                    4'h4, 4'h6: t1_latch[7:0] <= data_i;
                    4'h5: begin
                        t1_latch[15:8] <= data_i;
                        t1_count <= {data_i, t1_latch[7:0]};
                        t1_running <= 1; t1_armed <= 1; t1_wait <= 1; t1_reload <= 0;
                        t1_pb7 <= 0;
                    end
                    4'h7: t1_latch[15:8] <= data_i;
                    4'h8: t2_latch <= data_i;
                    4'h9: begin
                        t2_count <= {data_i, t2_latch};
                        t2_running <= 1; t2_armed <= 1;
                        t2_wait <= !acr[5]; t2_reload <= 0;
                    end
                    4'hb: begin
                        acr <= data_i;
                        if (data_i[0] && !acr[0]) ira <= pa_i;
                        if (data_i[1] && !acr[1]) irb <= pb_read;
                        // ASSUMPTION: serial mode changes restart transfer bookkeeping.
                        if (data_i[4:2] != sr_mode) begin
                            sr_running <= data_i[4:2] == 3 || data_i[4:2] == 7 || data_i[4:2] == 4;
                            sr_bits <= 0; sr_clk <= 1; sr_last_pending <= 0;
                            sr_irq_delay <= 0; sr_start_delay <= 1;
                        end
                    end
                    4'hc: pcr <= data_i;
                    4'he: ier <= data_i[7] ? ier | data_i[6:0] : ier & ~data_i[6:0];
                    default: ;
                endcase
            end
        end
    end
`ifdef FORMAL
    `include "mos_6522_props.sv"
`endif
endmodule
