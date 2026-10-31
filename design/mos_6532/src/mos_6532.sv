module mos_6532 (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       cs1,
    input  logic       cs2_n,
    input  logic       rs,
    input  logic       rw,
    input  logic [6:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,
    input  logic [7:0] pa_i,
    input  logic [7:0] pb_i,
    output logic [7:0] pa_o,
    output logic [7:0] pb_o,
    output logic [7:0] pa_oe,
    output logic [7:0] pb_oe,
    output logic       irq_n
);
    logic [7:0] ram [0:127];
    logic [7:0] ora, orb, ddra, ddrb;
    logic [7:0] timer_count;
    logic [9:0] divider, reload_divider;
    logic timer_running, timer_fast, timer_flag, timer_enable;
    logic edge_flag, edge_enable, edge_positive, previous_pa7;
    logic selected, writing, timer_write, timer_read, flag_read, edge_write;
    logic timer_tick, timer_expire, edge_event;

    assign selected = cs1 && !cs2_n;
    assign writing = selected && !rw;
    assign timer_write = writing && rs && addr[2] && addr[4];
    assign edge_write = writing && rs && addr[2] && !addr[4];
    assign timer_read = selected && rw && rs && addr[2] && !addr[0];
    assign flag_read = selected && rw && rs && addr[2] && addr[0];
    assign timer_tick = timer_running && (timer_fast || divider == 0);
    assign timer_expire = timer_tick && !timer_fast && timer_count == 0;
    // ASSUMPTION: sampled resolved PA7, including output mode; no subcycle pulses.
    assign edge_event = (pa_i[7] != previous_pa7) && (pa_i[7] == edge_positive);
    assign pa_o = ora;
    assign pb_o = orb;
    assign pa_oe = ddra;
    assign pb_oe = ddrb;
    assign irq_n = !(rst_n && ((timer_enable && timer_flag) ||
                              (edge_enable && edge_flag)));
    assign data_oe = clk && rst_n && selected && rw;

    always_comb begin
        data_o = 8'h00;
        if (!rs) data_o = ram[addr];
        else if (!addr[2]) begin
            case (addr[1:0])
                2'd0: data_o = pa_i;  // PA reads the resolved pins, not ORA.
                2'd1: data_o = ddra;
                2'd2: data_o = (orb & ddrb) | (pb_i & ~ddrb);
                2'd3: data_o = ddrb;
                default: data_o = 8'h00;
            endcase
        end else if (!addr[0]) data_o = timer_count;
        else data_o = {timer_flag, edge_flag, 6'b0};
    end

    // Native phase-two write completion. RAM is deliberately not reset.
    always_ff @(negedge clk) begin
        if (rst_n && writing && !rs) ram[addr] <= data_i;
        if (!rst_n) begin
            ora <= 0;
            orb <= 0;
            ddra <= 0;
            ddrb <= 0;
            // ASSUMPTION: deterministic stopped timer/cleared flags on reset.
            timer_count <= 0;
            divider <= 0;
            reload_divider <= 0;
            timer_running <= 0;
            timer_fast <= 0;
            timer_flag <= 0;
            timer_enable <= 0;
            edge_flag <= 0;
            edge_enable <= 0;
            edge_positive <= 0;
            previous_pa7 <= pa_i[7];
        end else begin
            previous_pa7 <= pa_i[7];
            if (writing && rs && !addr[2]) begin
                case (addr[1:0])
                    2'd0: ora <= data_i;
                    2'd1: ddra <= data_i;
                    2'd2: orb <= data_i;
                    2'd3: ddrb <= data_i;
                    default: ;
                endcase
            end
            if (edge_write) begin
                edge_positive <= addr[0];
                edge_enable <= addr[1];
            end
            if (flag_read) edge_flag <= 0;
            // ASSUMPTION: a new sampled edge wins over acknowledgment.
            if (edge_event) edge_flag <= 1;

            if (timer_write) begin
                timer_count <= data_i;
                divider <= 0;  // First decrement after one clock, not P clocks.
                case (addr[1:0])
                    2'd0: reload_divider <= 10'd0;
                    2'd1: reload_divider <= 10'd7;
                    2'd2: reload_divider <= 10'd63;
                    2'd3: reload_divider <= 10'd1023;
                    default: reload_divider <= 0;
                endcase
                timer_running <= 1;
                timer_fast <= 0;
                timer_flag <= 0;
                timer_enable <= addr[3];
            end else begin
                if (timer_running) begin
                    if (timer_tick) begin
                        timer_count <= timer_count - 8'd1;
                        divider <= reload_divider;
                    end else divider <= divider - 10'd1;
                    if (timer_expire) begin
                        timer_fast <= 1;
                        timer_flag <= 1;
                    end
                end
                if (timer_read) begin
                    timer_enable <= addr[3];
                    if (!timer_expire) begin
                        timer_flag <= 0;
                        if (timer_fast) begin
                            // ASSUMPTION: MAME timer_r restores the prescaler.
                            timer_count <= timer_count;
                            timer_fast <= 0;
                            divider <= 0;
                        end
                    end
                end
            end
        end
    end

`ifdef FORMAL
    `include "mos_6532_props.sv"
`endif
endmodule
