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
    output logic [8:0] frame_lines_o,
    output logic       field_o,
    output logic       interlace_o,
    output logic       line_end_o,
    output logic       frame_end_o
);
    localparam logic [6:0] CYCLES = PAL ? 7'd71 : 7'd65;
    localparam logic [8:0] LINES = PAL ? 9'd312 : 9'd261;
    logic [6:0] h_q;
    logic [8:0] line_q, frame_lines_q;
    logic field_q, interlace_q;
    logic [7:0] ahead_h;
    logic [8:0] ahead_line, previous_lines;
    logic ahead_field;

    assign scan_h_o = h_q;
    assign scan_line_o = line_q;
    assign frame_lines_o = frame_lines_q;
    assign field_o = field_q;
    assign interlace_o = interlace_q;
    assign line_end_o = rst_n && ce_i && (h_q == CYCLES - 7'd1);
    assign frame_end_o = line_end_o && (line_q == frame_lines_q - 9'd1);

    // ASSUMPTION: integer epochs/interlace follow pinned independent models;
    // this is not a composite-sync or physical master-clock implementation.
    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization, not a physical VIC reset pin.
        if (!rst_n) begin
            h_q <= 0;
            line_q <= 0;
            frame_lines_q <= LINES;
            field_q <= 0;
            interlace_q <= 0;
        end else if (ce_i) begin
            if (h_q == CYCLES - 7'd1) begin
                h_q <= 0;
                if (line_q == frame_lines_q - 9'd1) begin
                    line_q <= 0;
                    if (!PAL && interlace_i) begin
                        interlace_q <= 1;
                        field_q <= interlace_q ? !field_q : 1'b0;
                        frame_lines_q <= (interlace_q && !field_q) ?
                                         LINES + 9'd1 : LINES + 9'd2;
                    end else begin
                        interlace_q <= 0;
                        field_q <= 0;
                        frame_lines_q <= LINES;
                    end
                end else begin
                    line_q <= line_q + 9'd1;
                end
            end else begin
                h_q <= h_q + 7'd1;
            end
        end
    end

    // MAME raster_line(): look ahead, then apply the field-zero half-line.
    // Keep readback separate from the scan epoch used for memory sequencing.
    always_comb begin
        ahead_h = {1'b0, h_q} + (PAL ? 8'd0 : 8'd37);
        ahead_line = line_q;
        ahead_field = field_q;
        previous_lines = interlace_q ?
                         (field_q ? LINES + 9'd2 : LINES + 9'd1) : LINES;
        if (ahead_h >= {1'b0, CYCLES}) begin
            ahead_h = ahead_h - {1'b0, CYCLES};
            ahead_line = line_q + 9'd1;
        end
        if (ahead_line >= frame_lines_q) begin
            ahead_line = 0;
            ahead_field = interlace_q ? !field_q : 1'b0;
            previous_lines = frame_lines_q;
        end
        raster_o = ahead_line;
        raster_pos_o = ahead_h[6:0];
        if (!PAL && !ahead_field && ahead_line == 0) begin
            if (ahead_h < 8'd33)
                raster_o = previous_lines;
            else
                raster_pos_o = ahead_h[6:0] - 7'd33;
        end
    end

`ifdef FORMAL
    `include "mos_6560_raster_props.sv"
`endif
endmodule
