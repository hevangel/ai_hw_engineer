module intel_8253_8254 #(
    parameter bit IS_8254 = 1'b1
) (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       cs_n,
    input  logic       rd_n,
    input  logic       wr_n,
    input  logic [1:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,

    input  logic [2:0] counter_clk_i,
    input  logic [2:0] gate_i,
    output logic [2:0] out_o
);

    localparam int CounterCount = 3;

    logic [15:0] reload_value [CounterCount];
    logic [15:0] count_value [CounterCount];
    logic [15:0] latched_count [CounterCount];
    logic [7:0]  latched_status [CounterCount];
    logic [2:0]  mode_bits [CounterCount];
    logic [1:0]  rw_format [CounterCount];

    logic bcd_enabled [CounterCount];
    logic null_count [CounterCount];
    logic reload_valid [CounterCount];
    logic load_pending [CounterCount];
    logic trigger_pending [CounterCount];
    logic counting [CounterCount];
    logic mode3_first_tick [CounterCount];
    logic out_state [CounterCount];

    logic shared_msb_next [CounterCount];
    logic read_msb_next [CounterCount];
    logic write_msb_next [CounterCount];
    logic count_latched [CounterCount];
    logic status_latched [CounterCount];

    logic [2:0] previous_counter_clk;
    logic [2:0] previous_gate;
    logic [2:0] counter_clk_fall;
    logic [2:0] gate_rise;
    logic       bus_read;
    logic       bus_write;

    logic [15:0] read_count_source [CounterCount];
    logic        selected_read_msb [CounterCount];
    logic [7:0]  counter_read_data [CounterCount];

    function automatic logic [2:0] canonical_mode(
        input logic [2:0] raw_mode
    );
        begin
            if (raw_mode[2:1] == 2'b11) begin
                canonical_mode = {1'b0, raw_mode[1:0]};
            end else begin
                canonical_mode = raw_mode;
            end
        end
    endfunction

    function automatic logic [15:0] decrement_value(
        input logic [15:0] current_value,
        input logic        use_bcd
    );
        logic [15:0] next_value;
        begin
            if (!use_bcd) begin
                decrement_value = current_value - 16'h0001;
            end else begin
                next_value = current_value;
                if (current_value[3:0] != 4'd0) begin
                    next_value[3:0] = current_value[3:0] - 4'd1;
                end else begin
                    next_value[3:0] = 4'd9;
                    if (current_value[7:4] != 4'd0) begin
                        next_value[7:4] = current_value[7:4] - 4'd1;
                    end else begin
                        next_value[7:4] = 4'd9;
                        if (current_value[11:8] != 4'd0) begin
                            next_value[11:8] = current_value[11:8] - 4'd1;
                        end else begin
                            next_value[11:8] = 4'd9;
                            if (current_value[15:12] != 4'd0) begin
                                next_value[15:12] =
                                    current_value[15:12] - 4'd1;
                            end else begin
                                next_value[15:12] = 4'd9;
                            end
                        end
                    end
                end
                decrement_value = next_value;
            end
        end
    endfunction

    function automatic logic [15:0] subtract_value(
        input logic [15:0] current_value,
        input logic        use_bcd,
        input logic [1:0]  amount
    );
        logic [15:0] next_value;
        begin
            next_value = current_value;
            for (int subtract_index = 0; subtract_index < 3;
                 subtract_index = subtract_index + 1) begin
                if (subtract_index < amount) begin
                    next_value = decrement_value(next_value, use_bcd);
                end
            end
            subtract_value = next_value;
        end
    endfunction

    assign bus_read = !cs_n && !rd_n && wr_n;
    assign bus_write = !cs_n && rd_n && !wr_n;
    assign counter_clk_fall = previous_counter_clk & ~counter_clk_i;
    assign gate_rise = ~previous_gate & gate_i;

    always_comb begin
        for (int counter_index = 0; counter_index < CounterCount;
             counter_index = counter_index + 1) begin
            out_o[counter_index] = out_state[counter_index];
            if (count_latched[counter_index]) begin
                read_count_source[counter_index] =
                    latched_count[counter_index];
            end else begin
                read_count_source[counter_index] = count_value[counter_index];
            end

            if (IS_8254) begin
                selected_read_msb[counter_index] =
                    read_msb_next[counter_index];
            end else begin
                selected_read_msb[counter_index] =
                    shared_msb_next[counter_index];
            end

            if (status_latched[counter_index]) begin
                counter_read_data[counter_index] =
                    latched_status[counter_index];
            end else begin
                case (rw_format[counter_index])
                    2'b01: begin
                        counter_read_data[counter_index] =
                            read_count_source[counter_index][7:0];
                    end
                    2'b10: begin
                        counter_read_data[counter_index] =
                            read_count_source[counter_index][15:8];
                    end
                    2'b11: begin
                        if (selected_read_msb[counter_index]) begin
                            counter_read_data[counter_index] =
                                read_count_source[counter_index][15:8];
                        end else begin
                            counter_read_data[counter_index] =
                                read_count_source[counter_index][7:0];
                        end
                    end
                    default: begin
                        counter_read_data[counter_index] = 8'h00;
                    end
                endcase
            end
        end

        data_o = 8'h00;
        data_oe = 1'b0;
        if (bus_read) begin
            case (addr)
                2'b00: begin
                    data_o = counter_read_data[0];
                    data_oe = 1'b1;
                end
                2'b01: begin
                    data_o = counter_read_data[1];
                    data_oe = 1'b1;
                end
                2'b10: begin
                    data_o = counter_read_data[2];
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
        if (!rst_n) begin
            previous_counter_clk <= counter_clk_i;
            previous_gate <= gate_i;
            for (int counter_index = 0; counter_index < CounterCount;
                 counter_index = counter_index + 1) begin
                reload_value[counter_index] <= 16'h0000;
                count_value[counter_index] <= 16'h0000;
                latched_count[counter_index] <= 16'h0000;
                latched_status[counter_index] <= 8'h00;
                mode_bits[counter_index] <= 3'b000;
                rw_format[counter_index] <= 2'b11;
                bcd_enabled[counter_index] <= 1'b0;
                null_count[counter_index] <= 1'b1;
                reload_valid[counter_index] <= 1'b0;
                load_pending[counter_index] <= 1'b0;
                trigger_pending[counter_index] <= 1'b0;
                counting[counter_index] <= 1'b0;
                mode3_first_tick[counter_index] <= 1'b1;
                out_state[counter_index] <= 1'b1;
                shared_msb_next[counter_index] <= 1'b0;
                read_msb_next[counter_index] <= 1'b0;
                write_msb_next[counter_index] <= 1'b0;
                count_latched[counter_index] <= 1'b0;
                status_latched[counter_index] <= 1'b0;
            end
        end else begin
            previous_counter_clk <= counter_clk_i;
            previous_gate <= gate_i;

            for (int counter_index = 0; counter_index < CounterCount;
                 counter_index = counter_index + 1) begin
                if (bus_write && (addr == 2'b11) &&
                    (data_i[7:6] != 2'b11) &&
                    (data_i[7:6] == counter_index[1:0]) &&
                    (data_i[5:4] != 2'b00)) begin
                    rw_format[counter_index] <= data_i[5:4];
                    mode_bits[counter_index] <= data_i[3:1];
                    bcd_enabled[counter_index] <= data_i[0];
                    null_count[counter_index] <= 1'b1;
                    reload_valid[counter_index] <= 1'b0;
                    load_pending[counter_index] <= 1'b0;
                    trigger_pending[counter_index] <= 1'b0;
                    counting[counter_index] <= 1'b0;
                    mode3_first_tick[counter_index] <= 1'b1;
                    out_state[counter_index] <=
                        (canonical_mode(data_i[3:1]) != 3'd0);
                    shared_msb_next[counter_index] <= 1'b0;
                    read_msb_next[counter_index] <= 1'b0;
                    write_msb_next[counter_index] <= 1'b0;
                    count_latched[counter_index] <= 1'b0;
                    status_latched[counter_index] <= 1'b0;
                end else if (bus_write &&
                             (addr == counter_index[1:0])) begin
                    case (rw_format[counter_index])
                        2'b01: begin
                            reload_value[counter_index] <=
                                {8'h00, data_i};
                            reload_valid[counter_index] <= 1'b1;
                            null_count[counter_index] <= 1'b1;
                            trigger_pending[counter_index] <= 1'b0;
                            if ((canonical_mode(
                                     mode_bits[counter_index]) == 3'd0) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd2) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd3) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd4)) begin
                                load_pending[counter_index] <= 1'b1;
                            end
                            if (canonical_mode(
                                    mode_bits[counter_index]) == 3'd0) begin
                                counting[counter_index] <= 1'b0;
                            end
                        end
                        2'b10: begin
                            reload_value[counter_index] <=
                                {data_i, 8'h00};
                            reload_valid[counter_index] <= 1'b1;
                            null_count[counter_index] <= 1'b1;
                            trigger_pending[counter_index] <= 1'b0;
                            if ((canonical_mode(
                                     mode_bits[counter_index]) == 3'd0) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd2) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd3) ||
                                (canonical_mode(
                                     mode_bits[counter_index]) == 3'd4)) begin
                                load_pending[counter_index] <= 1'b1;
                            end
                            if (canonical_mode(
                                    mode_bits[counter_index]) == 3'd0) begin
                                counting[counter_index] <= 1'b0;
                            end
                        end
                        2'b11: begin
                            if ((IS_8254 &&
                                 !write_msb_next[counter_index]) ||
                                (!IS_8254 &&
                                 !shared_msb_next[counter_index])) begin
                                reload_value[counter_index][7:0] <= data_i;
                                reload_valid[counter_index] <= 1'b0;
                                trigger_pending[counter_index] <= 1'b0;
                                if (IS_8254) begin
                                    write_msb_next[counter_index] <= 1'b1;
                                end else begin
                                    shared_msb_next[counter_index] <= 1'b1;
                                end
                                if (canonical_mode(
                                        mode_bits[counter_index]) == 3'd0) begin
                                    counting[counter_index] <= 1'b0;
                                end
                            end else begin
                                reload_value[counter_index][15:8] <= data_i;
                                reload_valid[counter_index] <= 1'b1;
                                null_count[counter_index] <= 1'b1;
                                trigger_pending[counter_index] <= 1'b0;
                                if (IS_8254) begin
                                    write_msb_next[counter_index] <= 1'b0;
                                end else begin
                                    shared_msb_next[counter_index] <= 1'b0;
                                end
                                if ((canonical_mode(
                                         mode_bits[counter_index]) == 3'd0) ||
                                    (canonical_mode(
                                         mode_bits[counter_index]) == 3'd2) ||
                                    (canonical_mode(
                                         mode_bits[counter_index]) == 3'd3) ||
                                    (canonical_mode(
                                         mode_bits[counter_index]) == 3'd4)) begin
                                    load_pending[counter_index] <= 1'b1;
                                end
                            end
                        end
                        default: begin
                        end
                    endcase
                end else begin
                    if (((canonical_mode(mode_bits[counter_index]) == 3'd2) ||
                         (canonical_mode(mode_bits[counter_index]) == 3'd3)) &&
                        !gate_i[counter_index]) begin
                        out_state[counter_index] <= 1'b1;
                        counting[counter_index] <= 1'b0;
                        trigger_pending[counter_index] <= 1'b0;
                        mode3_first_tick[counter_index] <= 1'b1;
                    end else if (gate_rise[counter_index] &&
                                 (((canonical_mode(
                                       mode_bits[counter_index]) == 3'd1) &&
                                   reload_valid[counter_index]) ||
                                  (canonical_mode(
                                       mode_bits[counter_index]) == 3'd2) ||
                                  (canonical_mode(
                                       mode_bits[counter_index]) == 3'd3) ||
                                  ((canonical_mode(
                                        mode_bits[counter_index]) == 3'd5) &&
                                   reload_valid[counter_index]))) begin
                        trigger_pending[counter_index] <= 1'b1;
                    end

                    if (counter_clk_fall[counter_index]) begin
                        case (canonical_mode(mode_bits[counter_index]))
                            3'd0: begin
                                if (load_pending[counter_index] &&
                                    reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    load_pending[counter_index] <= 1'b0;
                                    null_count[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                end else if (counting[counter_index] &&
                                             gate_i[counter_index]) begin
                                    if (count_value[counter_index] ==
                                        16'h0001) begin
                                        count_value[counter_index] <=
                                            16'h0000;
                                        out_state[counter_index] <= 1'b1;
                                    end else begin
                                        count_value[counter_index] <=
                                            decrement_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index]);
                                    end
                                end
                            end
                            3'd1: begin
                                if ((trigger_pending[counter_index] ||
                                     gate_rise[counter_index]) &&
                                    reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    null_count[counter_index] <= 1'b0;
                                    trigger_pending[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                    out_state[counter_index] <= 1'b0;
                                end else if (counting[counter_index]) begin
                                    if (count_value[counter_index] ==
                                        16'h0001) begin
                                        count_value[counter_index] <=
                                            16'h0000;
                                        counting[counter_index] <= 1'b0;
                                        out_state[counter_index] <= 1'b1;
                                    end else begin
                                        count_value[counter_index] <=
                                            decrement_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index]);
                                    end
                                end
                            end
                            3'd2: begin
                                if (!gate_i[counter_index]) begin
                                    out_state[counter_index] <= 1'b1;
                                    counting[counter_index] <= 1'b0;
                                end else if ((trigger_pending[counter_index] ||
                                             gate_rise[counter_index] ||
                                             load_pending[counter_index]) &&
                                            reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    load_pending[counter_index] <= 1'b0;
                                    trigger_pending[counter_index] <= 1'b0;
                                    null_count[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                    out_state[counter_index] <= 1'b1;
                                end else if (counting[counter_index]) begin
                                    if (count_value[counter_index] ==
                                        16'h0001) begin
                                        count_value[counter_index] <=
                                            reload_value[counter_index];
                                        out_state[counter_index] <= 1'b1;
                                    end else if (count_value[counter_index] ==
                                                 16'h0002) begin
                                        count_value[counter_index] <=
                                            16'h0001;
                                        out_state[counter_index] <= 1'b0;
                                    end else begin
                                        count_value[counter_index] <=
                                            decrement_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index]);
                                        out_state[counter_index] <= 1'b1;
                                    end
                                end
                            end
                            3'd3: begin
                                if (!gate_i[counter_index]) begin
                                    out_state[counter_index] <= 1'b1;
                                    counting[counter_index] <= 1'b0;
                                    mode3_first_tick[counter_index] <= 1'b1;
                                end else if ((trigger_pending[counter_index] ||
                                             gate_rise[counter_index] ||
                                             load_pending[counter_index]) &&
                                            reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    load_pending[counter_index] <= 1'b0;
                                    trigger_pending[counter_index] <= 1'b0;
                                    null_count[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                    mode3_first_tick[counter_index] <= 1'b1;
                                    out_state[counter_index] <= 1'b1;
                                end else if (counting[counter_index]) begin
                                    if (mode3_first_tick[counter_index] &&
                                        reload_value[counter_index][0]) begin
                                        if (out_state[counter_index]) begin
                                            count_value[counter_index] <=
                                                subtract_value(
                                                    count_value[counter_index],
                                                    bcd_enabled[counter_index],
                                                    2'd1);
                                        end else begin
                                            count_value[counter_index] <=
                                                subtract_value(
                                                    count_value[counter_index],
                                                    bcd_enabled[counter_index],
                                                    2'd3);
                                        end
                                        mode3_first_tick[counter_index] <=
                                            1'b0;
                                    end else if ((count_value[counter_index] ==
                                                 16'h0001) ||
                                                (count_value[counter_index] ==
                                                 16'h0002) ||
                                                ((count_value[counter_index] ==
                                                  16'h0000) &&
                                                 (reload_value[counter_index] !=
                                                  16'h0000))) begin
                                        count_value[counter_index] <=
                                            reload_value[counter_index];
                                        out_state[counter_index] <=
                                            !out_state[counter_index];
                                        mode3_first_tick[counter_index] <=
                                            1'b1;
                                    end else begin
                                        count_value[counter_index] <=
                                            subtract_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index],
                                                2'd2);
                                        mode3_first_tick[counter_index] <=
                                            1'b0;
                                    end
                                end
                            end
                            3'd4: begin
                                if (load_pending[counter_index] &&
                                    reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    load_pending[counter_index] <= 1'b0;
                                    null_count[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                    out_state[counter_index] <= 1'b1;
                                end else if (counting[counter_index] &&
                                             !out_state[counter_index]) begin
                                    out_state[counter_index] <= 1'b1;
                                    counting[counter_index] <= 1'b0;
                                end else if (counting[counter_index] &&
                                             gate_i[counter_index]) begin
                                    if (count_value[counter_index] ==
                                        16'h0001) begin
                                        count_value[counter_index] <=
                                            16'h0000;
                                        out_state[counter_index] <= 1'b0;
                                    end else begin
                                        count_value[counter_index] <=
                                            decrement_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index]);
                                    end
                                end
                            end
                            default: begin
                                if ((trigger_pending[counter_index] ||
                                     gate_rise[counter_index]) &&
                                    reload_valid[counter_index]) begin
                                    count_value[counter_index] <=
                                        reload_value[counter_index];
                                    null_count[counter_index] <= 1'b0;
                                    trigger_pending[counter_index] <= 1'b0;
                                    counting[counter_index] <= 1'b1;
                                    out_state[counter_index] <= 1'b1;
                                end else if (counting[counter_index]) begin
                                    if (!out_state[counter_index]) begin
                                        out_state[counter_index] <= 1'b1;
                                        counting[counter_index] <= 1'b0;
                                    end else if (count_value[counter_index] ==
                                                 16'h0001) begin
                                        count_value[counter_index] <=
                                            16'h0000;
                                        out_state[counter_index] <= 1'b0;
                                    end else begin
                                        count_value[counter_index] <=
                                            decrement_value(
                                                count_value[counter_index],
                                                bcd_enabled[counter_index]);
                                    end
                                end
                            end
                        endcase
                    end
                end
            end

            if (bus_write && (addr == 2'b11) &&
                (data_i[7:6] != 2'b11) &&
                (data_i[5:4] == 2'b00)) begin
                for (int counter_index = 0; counter_index < CounterCount;
                     counter_index = counter_index + 1) begin
                    if ((data_i[7:6] == counter_index[1:0]) &&
                        !count_latched[counter_index]) begin
                        latched_count[counter_index] <=
                            count_value[counter_index];
                        count_latched[counter_index] <= 1'b1;
                        if (IS_8254) begin
                            read_msb_next[counter_index] <= 1'b0;
                        end else begin
                            shared_msb_next[counter_index] <= 1'b0;
                        end
                    end
                end
            end

            if (IS_8254 && bus_write && (addr == 2'b11) &&
                (data_i[7:6] == 2'b11)) begin
                for (int counter_index = 0; counter_index < CounterCount;
                     counter_index = counter_index + 1) begin
                    if (!data_i[counter_index + 1]) begin
                        if (!data_i[5] &&
                            !count_latched[counter_index]) begin
                            latched_count[counter_index] <=
                                count_value[counter_index];
                            count_latched[counter_index] <= 1'b1;
                            read_msb_next[counter_index] <= 1'b0;
                        end
                        if (!data_i[4] &&
                            !status_latched[counter_index]) begin
                            latched_status[counter_index] <= {
                                out_state[counter_index],
                                null_count[counter_index],
                                rw_format[counter_index],
                                mode_bits[counter_index],
                                bcd_enabled[counter_index]
                            };
                            status_latched[counter_index] <= 1'b1;
                        end
                    end
                end
            end

            if (bus_read && (addr != 2'b11)) begin
                for (int counter_index = 0; counter_index < CounterCount;
                     counter_index = counter_index + 1) begin
                    if (addr == counter_index[1:0]) begin
                        if (status_latched[counter_index]) begin
                            status_latched[counter_index] <= 1'b0;
                        end else begin
                            case (rw_format[counter_index])
                                2'b01, 2'b10: begin
                                    count_latched[counter_index] <= 1'b0;
                                end
                                2'b11: begin
                                    if (IS_8254) begin
                                        if (read_msb_next[counter_index]) begin
                                            read_msb_next[counter_index] <=
                                                1'b0;
                                            count_latched[counter_index] <=
                                                1'b0;
                                        end else begin
                                            read_msb_next[counter_index] <=
                                                1'b1;
                                        end
                                    end else begin
                                        if (shared_msb_next[counter_index]) begin
                                            shared_msb_next[counter_index] <=
                                                1'b0;
                                            count_latched[counter_index] <=
                                                1'b0;
                                        end else begin
                                            shared_msb_next[counter_index] <=
                                                1'b1;
                                        end
                                    end
                                end
                                default: begin
                                end
                            endcase
                        end
                    end
                end
            end
        end
    end

`ifdef FORMAL_SAFETY
    function automatic logic packed_bcd_valid(input logic [15:0] value);
        begin
            packed_bcd_valid = (value[3:0] <= 4'd9) &&
                               (value[7:4] <= 4'd9) &&
                               (value[11:8] <= 4'd9) &&
                               (value[15:12] <= 4'd9);
        end
    endfunction

    (* anyconst *) logic [15:0] formal_bcd_value;
    logic formal_engine_write [CounterCount];

    always_comb begin
        for (int formal_comb_index = 0;
             formal_comb_index < CounterCount;
             formal_comb_index = formal_comb_index + 1) begin
            formal_engine_write[formal_comb_index] =
                bus_write &&
                ((addr == formal_comb_index[1:0]) ||
                 ((addr == 2'b11) &&
                  (data_i[7:6] == formal_comb_index[1:0]) &&
                  (data_i[7:6] != 2'b11) &&
                  (data_i[5:4] != 2'b00)));
        end
        if (packed_bcd_valid(formal_bcd_value)) begin
            assert (packed_bcd_valid(
                subtract_value(formal_bcd_value, 1'b1, 2'd1)));
            assert (packed_bcd_valid(
                subtract_value(formal_bcd_value, 1'b1, 2'd2)));
            assert (packed_bcd_valid(
                subtract_value(formal_bcd_value, 1'b1, 2'd3)));
        end
        assert (subtract_value(16'h0000, 1'b1, 2'd1) == 16'h9999);
        assert (subtract_value(16'h0000, 1'b1, 2'd2) == 16'h9998);
        assert (subtract_value(16'h0000, 1'b1, 2'd3) == 16'h9997);
        assert (subtract_value(16'h0010, 1'b1, 2'd2) == 16'h0008);
        assert (subtract_value(16'h0003, 1'b1, 2'd3) == 16'h0000);
    end

    always_ff @(posedge clk) begin
        if (!$initstate) begin
            for (int formal_index = 0; formal_index < CounterCount;
                 formal_index = formal_index + 1) begin
                if ((canonical_mode(mode_bits[formal_index]) == 3'd1) ||
                    (canonical_mode(mode_bits[formal_index]) == 3'd5)) begin
                    assert (!trigger_pending[formal_index] ||
                            reload_valid[formal_index]);
                end

                if ($past(rst_n &&
                          counter_clk_fall[formal_index] &&
                          (canonical_mode(mode_bits[formal_index]) == 3'd4) &&
                          counting[formal_index] &&
                          !out_state[formal_index] &&
                          !(load_pending[formal_index] &&
                            reload_valid[formal_index]) &&
                          !formal_engine_write[formal_index])) begin
                    assert (out_state[formal_index]);
                    assert (!counting[formal_index]);
                end

                if ($past(rst_n &&
                          counter_clk_fall[formal_index] &&
                          (canonical_mode(mode_bits[formal_index]) == 3'd3) &&
                          counting[formal_index] &&
                          gate_i[formal_index] &&
                          reload_valid[formal_index] &&
                          (reload_value[formal_index] == 16'h0000) &&
                          (count_value[formal_index] == 16'h0000) &&
                          !load_pending[formal_index] &&
                          !trigger_pending[formal_index] &&
                          !gate_rise[formal_index] &&
                          !formal_engine_write[formal_index])) begin
                    if ($past(bcd_enabled[formal_index])) begin
                        assert (count_value[formal_index] == 16'h9998);
                    end else begin
                        assert (count_value[formal_index] == 16'hfffe);
                    end
                    assert (out_state[formal_index] ==
                            $past(out_state[formal_index]));
                end
            end
        end
    end
`endif

endmodule
