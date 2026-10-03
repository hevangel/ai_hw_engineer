// Intel 8275 functional controller. Sources/assumptions: ../spec/spec.md.
module intel_8275 #(
    parameter integer MAX_COLS = 80
) (
    input logic clk, rst_n, cclk_en,
    input logic cs_n, rd_n, wr_n, a0,
    input logic [7:0] db_in,
    output logic [7:0] db_out,
    output logic db_oe,
    input logic dack_n, lpen,
    output logic drq, irq,
    output logic [6:0] cc,
    output logic [3:0] lc,
    output logic [1:0] la, gpa,
    output logic hrtc, vrtc, vsp, lten, rvv, hlgt
);
    localparam integer COL_BITS = MAX_COLS > 1 ? $clog2(MAX_COLS) : 1;
    logic [7:0] screen [0:3];
    logic [7:0] row_buffer [0:1][0:MAX_COLS-1];
    logic [6:0] fifo [0:1][0:15];
    logic [7:0] cursor_col, cursor_row, pen_col, pen_row;
    logic ie, ir, lp, ic, ve, du, fo;
    logic read_seen, write_seen, ack_seen, pen_seen;
    logic [2:0] param_left, param_index;
    logic [1:0] param_kind; // 0 none, 1 screen writes, 2 cursor writes, 3 pen reads
    logic [7:0] x;
    logic [6:0] row;
    logic [3:0] line;
    logic [1:0] preset_delay;
    logic preset;
    logic [4:0] frame_phase;
    logic [5:0] field, row_field;
    logic end_row, end_screen, blank_frame;
    logic display_bank, fill_bank, display_valid;
    logic filling, fill_complete, dma_screen_stop, replacement, stop_pending;
    logic [7:0] fill_count;
    logic [4:0] fifo_count;
    logic [3:0] fifo_out;
    logic [2:0] burst_index, burst_code;
    logic [1:0] burst_length_code;
    logic [5:0] request_age;
    logic initial_request;

    logic [7:0] columns, htotal;
    logic [6:0] rows, total_rows;
    logic [3:0] last_line, underline, display_line;
    logic [5:0] space_count;
    logic [3:0] burst_length;
    logic bus_read, bus_write, ack, command;
    logic row_boundary, prefetch, row_start, active_row, completes_now;
    logic [6:0] next_row;
    logic [7:0] raw;
    logic [5:0] effective_field;
    logic [3:0] graphic;
    logic field_code, special_code, graphic_code, cell_end_screen;
    logic cell_blank, blink_blank, cursor_on;

    // Packed {LA1,LA0,VSP,LTEN}, directly transcribed from Intel Table 2.
    function automatic logic [3:0] graphic_outputs(input logic [3:0] code,
                                                  input logic [1:0] region);
        case (region)
            0: case (code)
                0,1,4,8,12: graphic_outputs=4'b0010;
                2,3,5,6,7,9,10: graphic_outputs=4'b0100;
                default: graphic_outputs=0;
            endcase
            1: case (code)
                0,2,6: graphic_outputs=4'b1000;
                1,3,5: graphic_outputs=4'b1100;
                4,7,8,10: graphic_outputs=4'b0001;
                9: graphic_outputs=4'b0100;
                12: graphic_outputs=4'b0010;
                default: graphic_outputs=0;
            endcase
            default: case (code)
                2,3,7,8,12: graphic_outputs=4'b0010;
                0,1,4,5,6,9,10: graphic_outputs=4'b0100;
                default: graphic_outputs=0;
            endcase
        endcase
    endfunction

    always_comb begin
        columns = (screen[0][6:0] >= 7'(MAX_COLS)) ? 8'(MAX_COLS) :
                  {1'b0,screen[0][6:0]} + 8'd1;
        htotal = columns + ({4'b0,screen[3][3:0]} + 8'd1) * 8'd2;
        rows = {1'b0,screen[1][5:0]} + 7'd1;
        total_rows = rows + {5'b0,screen[1][7:6]} + 7'd1;
        last_line = screen[2][3:0];
        underline = screen[2][7:4];
        space_count = burst_code == 0 ? 6'd0 : {burst_code,3'b0} - 6'd1;
        burst_length = 4'd1 << burst_length_code;
        bus_read = !cs_n && !rd_n && !read_seen;
        bus_write = !cs_n && !wr_n && !write_seen;
        ack = !dack_n && !ack_seen && drq;
        command = bus_write && a0;
        completes_now = ack && !command && (stop_pending ||
            (replacement && fill_count == columns) ||
            (!replacement &&
             (((db_in == 8'hf1 || db_in == 8'hf3) &&
                (fill_count+8'd1 >= columns || {1'b0,burst_index}+4'd1 >= burst_length)) ||
              (fill_count+8'd1 >= columns && (screen[3][6] || db_in[7:6] != 2'b10)))));
        next_row = row == total_rows - 7'd1 ? 7'd0 : row + 7'd1;
        row_boundary = cclk_en && !preset && x >= htotal - 8'd1 && line >= last_line;
        row_start = row_boundary && next_row < rows &&
                    (!screen[0][7] || !next_row[0]);
        // DMA is one raster row ahead, including the last VRTC row.
        prefetch = row_boundary && (next_row == total_rows - 7'd1 ||
                   (next_row < rows - 7'd1 &&
                    (!screen[0][7] || !next_row[0])));
        // In spaced mode fetch on blank odd rows, ahead of even display rows.
        if (screen[0][7])
            prefetch = row_boundary && (next_row == total_rows - 7'd1 ||
                       (next_row < rows - 7'd1 && next_row[0]));
        active_row = row < rows && (!screen[0][7] || !row[0]);
        hrtc = x >= columns;
        vrtc = row >= rows;
        display_line = line;
        if (hrtc) display_line = line == last_line ? 4'd0 : line + 4'd1;
        lc = screen[3][7] ? (display_line == 0 ? last_line : display_line - 4'd1) : display_line;
        irq = ir;
        db_oe = !cs_n && !rd_n;
        db_out = a0 ? {1'b0,ie,ir,lp,ic,ve,du,fo} :
                 (param_kind == 3 && param_left != 0 ?
                  (param_index == 0 ? pen_col : pen_row) : 8'd0);

        raw = 0;
        if (x < columns && display_valid) raw = row_buffer[display_bank][COL_BITS'(x)];
        field_code = raw[7:6] == 2'b10;
        special_code = raw >= 8'hf0;
        graphic_code = raw >= 8'hc0 && raw < 8'hf0;
        cell_end_screen = raw == 8'hf2 || raw == 8'hf3;
        effective_field = field;
        cc = raw[6:0];
        if (field_code && !screen[3][6]) begin
            effective_field = raw[5:0];
            cc = fifo[display_bank][fifo_out];
        end
        graphic = graphic_outputs(raw[5:2], line < underline ? 2'd0 :
                                  (line == underline ? 2'd1 : 2'd2));
        blink_blank = effective_field[1] && !frame_phase[4];
        cursor_on = cursor_col == x && cursor_row == {1'b0,row} &&
                    (screen[3][5] || !frame_phase[3]);
        la = 0;
        hlgt = effective_field[0];
        gpa = effective_field[3:2];
        rvv = effective_field[4];
        lten = effective_field[5] && line == underline;
        vsp = blink_blank;
        if (graphic_code) begin
            la = graphic[3:2];
            hlgt = raw[0];
            vsp = graphic[1] || (raw[1] && !frame_phase[4]);
            lten = graphic[0];
        end
        if (cursor_on) begin
            if (screen[3][4]) lten = lten || line == underline;
            else rvv = !rvv;
        end
        cell_blank = hrtc || vrtc || !active_row || !ve || !display_valid ||
                     blank_frame || end_screen || end_row || special_code ||
                     (field_code && screen[3][6]) ||
                     (underline[3] && (line == 0 || line == last_line));
        if (cell_blank) begin
            vsp = 1;
            lten = 0;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            screen[0]<=0; screen[1]<=0; screen[2]<=0; screen[3]<=0;
            cursor_col<=8'hff; cursor_row<=8'hff; pen_col<=0; pen_row<=0;
            ie<=0; ir<=0; lp<=0; ic<=0; ve<=0; du<=0; fo<=0;
            read_seen<=0; write_seen<=0; ack_seen<=0; pen_seen<=0;
            param_left<=0; param_index<=0; param_kind<=0;
            x<=0; row<=0; line<=0; preset<=0; preset_delay<=0;
            frame_phase<=0; field<=0; row_field<=0;
            end_row<=0; end_screen<=0; blank_frame<=0;
            display_bank<=0; fill_bank<=1; display_valid<=0;
            filling<=0; fill_complete<=0; dma_screen_stop<=0;
            replacement<=0; stop_pending<=0; fill_count<=0;
            fifo_count<=0; fifo_out<=0; burst_index<=0;
            burst_code<=0; burst_length_code<=0; request_age<=0;
            initial_request<=0; drq<=0;
        end else begin
            // ASSUMPTION A1: externally synchronized strobes, one event per assertion.
            read_seen<=!cs_n && !rd_n;
            write_seen<=!cs_n && !wr_n;
            ack_seen<=!dack_n;
            pen_seen<=lpen;
            if (bus_read) begin
                if (a0) begin ir<=0; lp<=0; ic<=0; du<=0; fo<=0; end
                else if (param_kind == 3 && param_left != 0) begin
                    param_left<=param_left-3'd1;
                    param_index<=param_index+3'd1;
                end else ic<=1;
            end
            // ASSUMPTION A4: new events win over a simultaneous status read.
            if (lpen && !pen_seen) begin
                pen_col<=x; pen_row<={1'b0,row}; lp<=1;
            end
            if (command) begin
                if (param_left != 0) ic<=1;
                param_left<=0; param_index<=0; param_kind<=0;
                preset<=0; preset_delay<=0;
                case (db_in[7:5])
                    0: begin
                        ie<=0; ir<=0; ve<=0; drq<=0; filling<=0;
                        display_valid<=0; fill_complete<=0;
                        param_kind<=1; param_left<=4;
                    end
                    1: begin
                        ie<=1; ve<=1;
                        burst_code<=db_in[4:2]; burst_length_code<=db_in[1:0];
                    end
                    2: ve<=0;
                    3: begin param_kind<=3; param_left<=2; end
                    4: begin param_kind<=2; param_left<=2; end
                    5: ie<=1;
                    6: ie<=0;
                    7: begin preset<=1; preset_delay<=2; drq<=0; filling<=0; end
                endcase
            end else begin
                if (bus_write) begin
                    if (param_left == 0 || param_kind == 3) ic<=1;
                    else begin
                        if (param_kind == 1) begin
                            screen[param_index[1:0]]<=db_in;
                            if (param_index == 0 && db_in[6:0] >= 7'(MAX_COLS)) ic<=1;
                        end else if (param_index == 0) cursor_col<=db_in;
                        else cursor_row<=db_in;
                        param_index<=param_index+3'd1; param_left<=param_left-3'd1;
                    end
                end

                if (cclk_en && request_age != 63) request_age<=request_age+6'd1;
                if (filling && !drq && !preset) begin
                    if (!initial_request || request_age >= space_count) begin
                        drq<=1; request_age<=0; initial_request<=0;
                    end
                end
                if (ack) begin
                    drq<=0;
                    if (stop_pending) begin
                        filling<=0; fill_complete<=1; stop_pending<=0;
                    end else begin
                        if (replacement) begin
                            fifo[fill_bank][fifo_count[3:0]]<=db_in[6:0];
                            replacement<=0;
                            if (fifo_count == 16) begin fo<=1; fifo_count<=1; end
                            else fifo_count<=fifo_count+5'd1;
                        end else if (fill_count < columns) begin
                            row_buffer[fill_bank][COL_BITS'(fill_count)]<=db_in;
                            fill_count<=fill_count+8'd1;
                            replacement<=!screen[3][6] && db_in[7:6] == 2'b10;
                        end
                        burst_index<=burst_index+3'd1;
                        initial_request<=({1'b0,burst_index}+4'd1 >= burst_length);
                        if ({1'b0,burst_index}+4'd1 >= burst_length) burst_index<=0;
                        if (!replacement && (db_in == 8'hf1 || db_in == 8'hf3)) begin
                            if (db_in == 8'hf3) dma_screen_stop<=1;
                            if (fill_count+8'd1 >= columns ||
                                {1'b0,burst_index}+4'd1 >= burst_length) begin
                                filling<=0; fill_complete<=1;
                            end else stop_pending<=1;
                        end else if ((replacement && fill_count == columns) ||
                                     (!replacement && fill_count+8'd1 >= columns &&
                                      (screen[3][6] || db_in[7:6] != 2'b10))) begin
                            filling<=0; fill_complete<=1;
                        end
                    end
                end

                if (cclk_en) begin
                    if (preset) begin
                        // ASSUMPTION A2: deterministic top-left position after two CCLKs.
                        if (preset_delay != 0) begin
                            preset_delay<=preset_delay-2'd1;
                            if (preset_delay == 1) begin
                                x<=0; row<=0; line<=0; field<=0; row_field<=0;
                                end_row<=0; end_screen<=0;
                            end
                        end
                    end else begin
                        if (x < columns && active_row && display_valid && !end_screen) begin
                            if (!end_row && field_code) begin
                                field<=raw[5:0];
                                if (!screen[3][6]) fifo_out<=fifo_out+4'd1;
                            end
                            if (raw == 8'hf0 || raw == 8'hf1) end_row<=1;
                            if (cell_end_screen) end_screen<=1;
                        end
                        if (x >= htotal-8'd1) begin
                            x<=0; fifo_out<=0; end_row<=0;
                            if (line >= last_line) begin
                                line<=0; row<=next_row;
                                row_field<=field; field<=field;
                            end else begin line<=line+4'd1; field<=row_field; end
                        end else x<=x+8'd1;
                        if (row_boundary) begin
                            if (next_row == rows-7'd1 && ie) ir<=1;
                            if (next_row == rows) begin
                                field<=0; row_field<=0; end_screen<=0; blank_frame<=0;
                                dma_screen_stop<=0; display_valid<=0;
                                frame_phase<=frame_phase+5'd1;
                            end
                            if (row_start && ve && !blank_frame && !end_screen) begin
                                if (!fill_complete && !completes_now) begin
                                    du<=1; blank_frame<=1; filling<=0; drq<=0;
                                    display_valid<=0;
                                end else begin
                                    display_bank<=fill_bank; display_valid<=1;
                                end
                            end
                            if (prefetch && ve && (!blank_frame || next_row == rows) &&
                                (!dma_screen_stop || next_row == rows)) begin
                                // Simultaneous swap uses the other bank for the next row.
                                fill_bank<=row_start ? display_bank : !display_bank;
                                fill_count<=0; fifo_count<=0; replacement<=0;
                                stop_pending<=0; fill_complete<=0;
                                filling<=1; burst_index<=0; drq<=0;
                                request_age<=0; initial_request<=1;
                                if (row_start && !fill_complete && !completes_now && !end_screen) filling<=0;
                            end
                        end
                    end
                end
            end
        end
    end

`ifdef FORMAL
    `include "intel_8275_props.sv"
`endif
endmodule
