module mos_6526_tod #(
    parameter logic [7:0] RESET_HOUR = 8'h01
) (
    input logic clk, rst_n, edge_i, mode_50hz_i,
    input logic write_i, read_i, alarm_select_i,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic alarm_event_o, stopped_o, latched_o,
    output logic [31:0] time_o, alarm_o
);
    logic [31:0] time_q, alarm_q, snapshot_q, time_next, alarm_next;
    logic stopped_q, latched_q, stopped_next;
    logic [2:0] divider_q, divider_next;
    logic [7:0] write_value;

    // Per-digit NMOS-style BCD counters, including invalid-digit wrap. The
    // independent VICE TOD code pins the 11->12 PM and 12->01 behavior.
    function automatic logic [31:0] advance_time(input logic [31:0] value);
        logic [31:0] result;
        logic [3:0] low_digit;
        logic [2:0] high_digit;
        logic carry_second, carry_minute;
        begin
            result = value;
            result[3:0] = value[3:0]+4'd1;
            carry_second = 0;
            carry_minute = 0;
            if (result[3:0] == 4'd10) begin
                result[3:0] = 0;
                low_digit = value[11:8]+4'd1;
                high_digit = value[14:12];
                if (low_digit == 4'd10) begin
                    low_digit = 0; high_digit = high_digit+3'd1;
                    if (high_digit == 3'd6) begin high_digit = 0; carry_second = 1; end
                end
                result[15:8] = {1'b0,high_digit,low_digit};
                if (carry_second) begin
                    low_digit = value[19:16]+4'd1;
                    high_digit = value[22:20];
                    if (low_digit == 4'd10) begin
                        low_digit = 0; high_digit = high_digit+3'd1;
                        if (high_digit == 3'd6) begin high_digit = 0; carry_minute = 1; end
                    end
                    result[23:16] = {1'b0,high_digit,low_digit};
                    if (carry_minute) begin
                        if (value[28:24] == 5'h12) result[28:24] = 5'h01;
                        else if (value[28:24] == 5'h09) result[28:24] = 5'h10;
                        else result[27:24] = value[27:24]+4'd1;
                        if (result[28:24] == 5'h12) result[31] = !value[31];
                    end
                end
            end
            advance_time = result;
        end
    endfunction
    always_comb begin
        time_next = time_q;
        alarm_next = alarm_q;
        stopped_next = stopped_q;
        divider_next = divider_q;
        if (stopped_q) divider_next = 0;
        else if (edge_i) begin
            if (divider_q == (mode_50hz_i ? 3'd4 : 3'd5)) begin
                divider_next = 0;
                time_next = advance_time(time_q);
            end else divider_next = divider_q+3'd1;
        end
        case (addr)
            0: write_value = data_i & 8'h0f;
            1,2: write_value = data_i & 8'h7f;
            default: write_value = data_i & 8'h9f;
        endcase
        if (write_i) begin
            if (alarm_select_i) alarm_next[8*addr +: 8] = write_value;
            else begin
                // ASSUMPTION: boundary writes follow the old clock's tick.
                // Writing time hour 12 flips PM; alarm writes do not.
                if (addr == 3 && write_value[4:0] == 5'h12) write_value[7] = !write_value[7];
                time_next[8*addr +: 8] = write_value;
                if (addr == 3) stopped_next = 1;
                if (addr == 0) begin
                    stopped_next = 0;
                    if (stopped_q) divider_next = 0;
                end
            end
        end
        alarm_event_o = rst_n && time_next == alarm_next &&
            (time_next != time_q || alarm_next != alarm_q);
        data_o = latched_q ? snapshot_q[8*addr +: 8] : time_q[8*addr +: 8];
    end
    assign time_o = time_q;
    assign alarm_o = alarm_q;
    assign stopped_o = stopped_q;
    assign latched_o = latched_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // ASSUMPTION: common VICE reset profile; preliminary sheet differs.
            time_q <= {RESET_HOUR & 8'h9f,24'b0}; alarm_q <= 0;
            snapshot_q <= 0; stopped_q <= 1; latched_q <= 0; divider_q <= 0;
        end else begin
            time_q <= time_next; alarm_q <= alarm_next;
            stopped_q <= stopped_next; divider_q <= divider_next;
            if (read_i && addr == 3 && !latched_q) begin
                snapshot_q <= time_q; latched_q <= 1;
            end
            if (read_i && addr == 0) latched_q <= 0;
        end
    end
`ifdef FORMAL
    `include "mos_6526_tod_props.sv"
`endif
endmodule
