module mos_6560_raster #(
    parameter bit PAL = 1'b1
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       ce_i,
    input  logic       interlace_i,
    output logic [6:0] scan_h_o,
    output logic [8:0] scan_line_o,
    output logic [8:0] raster_o,
    output logic [6:0] raster_pos_o,
    output logic [8:0] raster_next_o,
    output logic [6:0] raster_pos_next_o,
    output logic [8:0] frame_lines_o,
    output logic [8:0] frame_lines_next_o,
    output logic       field_o,
    output logic       interlace_o,
    output logic       line_end_o,
    output logic       frame_end_o
);
    localparam logic [6:0] CYCLES = PAL ? 7'd71 : 7'd65;
    localparam logic [8:0] LINES = PAL ? 9'd312 : 9'd261;
    logic [6:0] h_q, h_d;
    logic [8:0] line_q, line_d, frame_lines_q, frame_lines_d;
    logic field_q, field_d, interlace_q, interlace_d;

    assign scan_h_o = h_q;
    assign scan_line_o = line_q;
    assign frame_lines_o = frame_lines_q;
    assign frame_lines_next_o = frame_lines_d;
    assign field_o = field_q;
    assign interlace_o = interlace_q;
    assign line_end_o = rst_n && ce_i && (h_q == CYCLES - 7'd1);
    assign frame_end_o = line_end_o && (line_q == frame_lines_q - 9'd1);

    // ASSUMPTION: integer epochs/interlace follow pinned independent models;
    // this is not a composite-sync or physical master-clock implementation.
    always_comb begin
        h_d = h_q;
        line_d = line_q;
        frame_lines_d = frame_lines_q;
        field_d = field_q;
        interlace_d = interlace_q;
        // ASSUMPTION: platform initialization, not a physical VIC reset pin.
        if (!rst_n) begin
            h_d = 0;
            line_d = 0;
            frame_lines_d = LINES;
            field_d = 0;
            interlace_d = 0;
        end else if (ce_i) begin
            if (h_q == CYCLES - 7'd1) begin
                h_d = 0;
                if (line_q == frame_lines_q - 9'd1) begin
                    line_d = 0;
                    if (!PAL && interlace_i) begin
                        interlace_d = 1;
                        field_d = interlace_q ? !field_q : 1'b0;
                        frame_lines_d = (interlace_q && !field_q) ?
                                        LINES + 9'd1 : LINES + 9'd2;
                    end else begin
                        interlace_d = 0;
                        field_d = 0;
                        frame_lines_d = LINES;
                    end
                end else begin
                    line_d = line_q + 9'd1;
                end
            end else begin
                h_d = h_q + 7'd1;
            end
        end
    end

    always_ff @(posedge clk) begin
        h_q <= h_d;
        line_q <= line_d;
        frame_lines_q <= frame_lines_d;
        field_q <= field_d;
        interlace_q <= interlace_d;
    end

    // MAME raster_line(): look ahead, then apply the field-zero half-line.
    // Keep readback separate from the scan epoch used for memory sequencing.
    function automatic logic [15:0] readback(
        input logic [6:0] h, input logic [8:0] line, input logic field,
        input logic lace, input logic [8:0] lines
    );
        logic [7:0] ahead_h;
        logic [8:0] ahead_line, previous_lines, result_line;
        logic [6:0] result_pos;
        logic ahead_field;
        ahead_h = {1'b0, h} + (PAL ? 8'd0 : 8'd37);
        ahead_line = line;
        ahead_field = field;
        previous_lines = lace ? (field ? LINES + 9'd2 : LINES + 9'd1) : LINES;
        if (ahead_h >= {1'b0, CYCLES}) begin
            ahead_h = ahead_h - {1'b0, CYCLES};
            ahead_line = line + 9'd1;
        end
        if (ahead_line >= lines) begin
            ahead_line = 0;
            ahead_field = lace ? !field : 1'b0;
            previous_lines = lines;
        end
        result_line = ahead_line;
        result_pos = ahead_h[6:0];
        if (!PAL && !ahead_field && ahead_line == 0) begin
            if (ahead_h < 8'd33)
                result_line = previous_lines;
            else
                result_pos = ahead_h[6:0] - 7'd33;
        end
        readback = {result_line, result_pos};
    endfunction

    // The next view is MAME's raster_line(cycle + 1), used by light-pen
    // capture within the current cycle; it equals the view after this edge.
    assign {raster_o, raster_pos_o} =
        readback(h_q, line_q, field_q, interlace_q, frame_lines_q);
    assign {raster_next_o, raster_pos_next_o} =
        readback(h_d, line_d, field_d, interlace_d, frame_lines_d);

`ifdef FORMAL
    `include "mos_6560_raster_props.sv"
`endif
endmodule
