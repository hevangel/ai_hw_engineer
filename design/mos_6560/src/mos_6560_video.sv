module mos_6560_video #(
    parameter bit PAL = 1'b1
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         ce_i,
    input  logic [127:0] config_i,
    input  logic [6:0]   scan_h_i,
    input  logic [8:0]   scan_line_i,
    input  logic         line_end_i,
    input  logic         frame_end_i,
    input  logic         reg_write_i,
    input  logic [3:0]   reg_addr_i,
    input  logic [7:0]   reg_data_i,
    input  logic [11:0]  fetch_data_i,
    output logic         fetch_o,
    output logic         fetch_matrix_o,
    output logic [13:0]  fetch_addr_o,
    output logic [15:0]  pixel_o
);
    localparam logic [1:0] AREA_IDLE = 2'd0, AREA_PENDING = 2'd1,
                           AREA_DISPLAY = 2'd2, AREA_DONE = 2'd3;
    localparam logic [2:0] FETCH_IDLE = 3'd0, FETCH_START = 3'd1,
                           FETCH_MATRIX = 3'd2, FETCH_CHARGEN = 3'd3,
                           FETCH_DONE = 3'd4;
    localparam logic [1:0] PEND_NONE = 2'd0, PEND_AUX = 2'd1, PEND_COLOR = 2'd2;
    localparam logic [5:0] MAX_COLUMNS = PAL ? 6'd32 : 6'd31;

    logic [7:0] r0, r1, r2, r3, r5;
    assign r0 = config_i[7:0];
    assign r1 = config_i[15:8];
    assign r2 = config_i[23:16];
    assign r3 = config_i[31:24];
    assign r5 = config_i[47:40];
    // Registers 4 and 6..15 are consumed elsewhere or through pending writes;
    // register 0 bit 7 (interlace) and register 3 bit 7 (raster) likewise.
    logic unused_config;
    assign unused_config = ^{config_i[127:48], config_i[39:32], r0[7], r3[7]};

    // Sequencer state; names follow the independent per-cycle model.
    logic [1:0]  area_q, area_d;
    logic [2:0]  fetch_q, fetch_d;
    logic [2:0]  start_delay_q, start_delay_d;
    logic [5:0]  buf_offset_q, buf_offset_d;
    logic [5:0]  text_cols_q, text_cols_d;
    logic [5:0]  pending_cols_q, pending_cols_d;
    logic [5:0]  text_lines_q, text_lines_d;
    logic [8:0]  ycounter_q, ycounter_d;
    logic [6:0]  row_counter_q, row_counter_d;
    logic [11:0] vmc_q, vmc_d, vmb_q, vmb_d;
    logic [6:0]  vmc_left_q, vmc_left_d;
    logic        vmc_inc_q, vmc_inc_d, vmc_wrap_q, vmc_wrap_d;
    logic        blank_line_q, blank_line_d, was_blank_q, was_blank_d;
    // Fetch latches, two-stage load pipeline and pixel shifter.
    logic [7:0]  vbuf_q, vbuf_d;
    logic [3:0]  cbuf_q, cbuf_d;
    logic [2:0][7:0] gload_q, gload_d;
    logic [2:0][3:0] cload_q, cload_d;
    logic [2:0]  load_q, load_d;
    logic [7:0]  gdata_q, gdata_d;
    logic [3:0]  cdata_q, cdata_d;
    logic [3:0]  shift_pos_q, shift_pos_d;
    // Output colors change only through pending register 14/15 writes.
    logic [3:0]  out_bg_q, out_bg_d, out_aux_q, out_aux_d;
    logic [2:0]  out_border_q, out_border_d;
    logic        out_reverse_q, out_reverse_d;
    logic [1:0]  pend_q, pend_d;
    logic [7:0]  pend_data_q, pend_data_d;

    logic [6:0]  cyc;
    logic [8:0]  line;
    logic        tall;
    logic [11:0] vmc_old;
    logic [3:0]  bg, aux, color;
    logic [2:0]  border;
    logic        reverse;
    logic [2:0]  p;
    logic [1:0]  pair;

    always_comb begin
        area_d = area_q;
        fetch_d = fetch_q;
        start_delay_d = start_delay_q;
        buf_offset_d = buf_offset_q;
        text_cols_d = text_cols_q;
        pending_cols_d = pending_cols_q;
        text_lines_d = text_lines_q;
        ycounter_d = ycounter_q;
        row_counter_d = row_counter_q;
        vmc_d = vmc_q;
        vmb_d = vmb_q;
        vmc_left_d = vmc_left_q;
        vmc_inc_d = vmc_inc_q;
        vmc_wrap_d = vmc_wrap_q;
        blank_line_d = blank_line_q;
        was_blank_d = was_blank_q;
        vbuf_d = vbuf_q;
        cbuf_d = cbuf_q;
        gload_d = gload_q;
        cload_d = cload_q;
        load_d = load_q;
        gdata_d = gdata_q;
        cdata_d = cdata_q;
        shift_pos_d = shift_pos_q;
        out_bg_d = out_bg_q;
        out_aux_d = out_aux_q;
        out_border_d = out_border_q;
        out_reverse_d = out_reverse_q;
        pend_d = pend_q;
        pend_data_d = pend_data_q;
        fetch_o = 0;
        fetch_matrix_o = 0;
        fetch_addr_o = 0;
        pixel_o = 0;
        vmc_old = 0;
        bg = 0;
        aux = 0;
        border = 0;
        reverse = 0;
        color = 0;
        p = 0;
        pair = 0;
        tall = r3[0];
        cyc = line_end_i ? 7'd0 : scan_h_i + 7'd1;
        line = frame_end_i ? 9'd0 : (line_end_i ? scan_line_i + 9'd1 : scan_line_i);

        if (rst_n && ce_i) begin
            // Vertical opening compares the line before this cycle's advance.
            if (area_d == AREA_IDLE && r1 == scan_line_i[8:1])
                area_d = (text_lines_d == 0) ? AREA_DONE : AREA_PENDING;

            if (line_end_i) begin
                was_blank_d = blank_line_d;
                if (area_d == AREA_DISPLAY)
                    ycounter_d = ycounter_d + 9'd1;
                vmc_wrap_d = vmc_inc_d;
                vmc_inc_d = 0;
                vmc_left_d = 0;
                fetch_d = FETCH_IDLE;
                blank_line_d = 1;
            end
            if (frame_end_i) begin
                row_counter_d = 0;
                area_d = AREA_IDLE;
                ycounter_d = 0;
                vmc_d = 0;
                vmb_d = 0;
                vmc_wrap_d = 0;
            end

            if (area_d == AREA_DISPLAY || area_d == AREA_PENDING) begin
                if (fetch_d == FETCH_IDLE && r0[6:0] == cyc) begin
                    fetch_d = FETCH_START;
                    start_delay_d = 3'd4;
                    buf_offset_d = 0;
                    if (area_d == AREA_PENDING)
                        area_d = AREA_DISPLAY;
                    text_cols_d = pending_cols_d;
                end
                if (area_d == AREA_DISPLAY && cyc == 0) begin
                    vmc_old = vmc_d;
                    if (ycounter_d == (tall ? 9'd16 : 9'd8) ||
                        ycounter_d == (tall ? 9'd32 : 9'd16)) begin
                        ycounter_d = 0;
                        if (!was_blank_d)
                            vmb_d = vmc_old;
                        row_counter_d = row_counter_d + 7'd1;
                        if (row_counter_d == {1'b0, text_lines_d})
                            area_d = AREA_DONE;
                    end
                    vmc_d = vmb_d;
                    if (vmc_wrap_d) begin
                        if (vmc_old[3:0] == 0)
                            vmc_d = vmc_d + 12'h010;
                        if (vmc_old[7:0] == 0)
                            vmc_d = vmc_d + 12'h100;
                    end
                end
            end

            if (cyc == 7'd1)
                pending_cols_d = (r2[6:0] > {1'b0, MAX_COLUMNS}) ?
                                 MAX_COLUMNS : r2[5:0];
            else if (cyc == 7'd2 && line == 0)
                text_lines_d = r3[6:1];

            case (fetch_d)
                FETCH_START: begin
                    start_delay_d = start_delay_d - 3'd1;
                    if (start_delay_d == 0) begin
                        text_cols_d = pending_cols_d;
                        if (text_cols_d != 0) begin
                            blank_line_d = 0;
                            vmc_left_d = {text_cols_d, 1'b0};
                            fetch_d = FETCH_MATRIX;
                        end else begin
                            fetch_d = FETCH_DONE;
                        end
                    end
                end
                FETCH_MATRIX: begin
                    fetch_o = 1;
                    fetch_matrix_o = 1;
                    fetch_addr_o = {r5[7:4], r2[7], 9'd0} + {3'd0, vmc_d[11:1]};
                    vbuf_d = fetch_data_i[7:0];
                    cbuf_d = fetch_data_i[11:8];
                    fetch_d = FETCH_CHARGEN;
                end
                FETCH_CHARGEN: begin
                    fetch_o = 1;
                    fetch_addr_o = {r5[3:0], 10'd0} +
                        (tall ? {2'd0, vbuf_d, 4'd0} : {3'd0, vbuf_d, 3'd0}) +
                        {10'd0, ycounter_d[3] & tall, ycounter_d[2:0]};
                    gload_d[2] = fetch_data_i[7:0];
                    cload_d[2] = cbuf_d;
                    load_d[2] = 1;
                    buf_offset_d = buf_offset_d + 6'd1;
                    fetch_d = (buf_offset_d >= text_cols_d) ? FETCH_DONE : FETCH_MATRIX;
                end
                default: begin end
            endcase

            vmc_inc_d = vmc_left_d != 0;
            if (vmc_inc_d) begin
                vmc_d = vmc_d + 12'd1;
                vmc_left_d = vmc_left_d - 7'd1;
            end

            // Character data reaches the shifter two cycles after its fetch.
            if (load_d[0]) begin
                gdata_d = gload_d[0];
                cdata_d = cload_d[0];
                shift_pos_d = 0;
            end
            load_d = {1'b0, load_d[2], load_d[1]};
            gload_d[0] = gload_d[1];
            cload_d[0] = cload_d[1];
            gload_d[1] = gload_d[2];
            cload_d[1] = cload_d[2];

            bg = out_bg_d;
            border = out_border_d;
            aux = out_aux_d;
            reverse = out_reverse_d;
            for (int i = 0; i < 4; i++) begin
                // A color write takes effect inside the next four-pixel group.
                if (i == 1 && pend_q == PEND_AUX)
                    aux = pend_data_q[7:4];
                if (i == 1 && pend_q == PEND_COLOR) begin
                    bg = pend_data_q[7:4];
                    border = pend_data_q[2:0];
                end
                if (i == 3 && pend_q == PEND_COLOR)
                    reverse = !pend_data_q[3];
                if (shift_pos_d[3]) begin
                    color = {1'b0, border};
                end else begin
                    p = shift_pos_d[2:0];
                    shift_pos_d = shift_pos_d + 4'd1;
                    if (!cdata_d[3]) begin
                        color = (gdata_d[3'd7 - p] ^ reverse) ? {1'b0, cdata_d[2:0]} : bg;
                    end else begin
                        pair = gdata_d[(3'd6 - (p & 3'd6)) +: 2];
                        case (pair)
                            2'd0: color = bg;
                            2'd1: color = {1'b0, border};
                            2'd2: color = {1'b0, cdata_d[2:0]};
                            default: color = aux;
                        endcase
                    end
                end
                pixel_o[4*i +: 4] = color;
            end
            if (pend_q != PEND_NONE) begin
                out_bg_d = bg;
                out_border_d = border;
                out_aux_d = aux;
                out_reverse_d = reverse;
            end
            pend_d = PEND_NONE;
        end

        // CPU writes complete after the cycle they accompany.
        if (rst_n && reg_write_i && reg_addr_i == 4'he) begin
            pend_d = PEND_AUX;
            pend_data_d = reg_data_i;
        end else if (rst_n && reg_write_i && reg_addr_i == 4'hf) begin
            pend_d = PEND_COLOR;
            pend_data_d = reg_data_i;
        end
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization following the reference's
        // startup values, not a physical reset pin.
        if (!rst_n) begin
            area_q <= AREA_IDLE;
            fetch_q <= FETCH_IDLE;
            start_delay_q <= 0;
            buf_offset_q <= 0;
            text_cols_q <= 0;
            pending_cols_q <= 0;
            text_lines_q <= 0;
            ycounter_q <= 0;
            row_counter_q <= 0;
            vmc_q <= 0;
            vmb_q <= 0;
            vmc_left_q <= 0;
            vmc_inc_q <= 0;
            vmc_wrap_q <= 0;
            blank_line_q <= 1;
            was_blank_q <= 1;
            vbuf_q <= 0;
            cbuf_q <= 0;
            gload_q <= '0;
            cload_q <= '0;
            load_q <= 0;
            gdata_q <= 0;
            cdata_q <= 0;
            shift_pos_q <= 4'd8;
            out_bg_q <= 0;
            out_aux_q <= 0;
            out_border_q <= 0;
            out_reverse_q <= 0;
            pend_q <= PEND_NONE;
            pend_data_q <= 0;
        end else begin
            area_q <= area_d;
            fetch_q <= fetch_d;
            start_delay_q <= start_delay_d;
            buf_offset_q <= buf_offset_d;
            text_cols_q <= text_cols_d;
            pending_cols_q <= pending_cols_d;
            text_lines_q <= text_lines_d;
            ycounter_q <= ycounter_d;
            row_counter_q <= row_counter_d;
            vmc_q <= vmc_d;
            vmb_q <= vmb_d;
            vmc_left_q <= vmc_left_d;
            vmc_inc_q <= vmc_inc_d;
            vmc_wrap_q <= vmc_wrap_d;
            blank_line_q <= blank_line_d;
            was_blank_q <= was_blank_d;
            vbuf_q <= vbuf_d;
            cbuf_q <= cbuf_d;
            gload_q <= gload_d;
            cload_q <= cload_d;
            load_q <= load_d;
            gdata_q <= gdata_d;
            cdata_q <= cdata_d;
            shift_pos_q <= shift_pos_d;
            out_bg_q <= out_bg_d;
            out_aux_q <= out_aux_d;
            out_border_q <= out_border_d;
            out_reverse_q <= out_reverse_d;
            pend_q <= pend_d;
            pend_data_q <= pend_data_d;
        end
    end

`ifdef FORMAL
    `include "mos_6560_video_props.sv"
`endif
endmodule
