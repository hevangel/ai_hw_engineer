module raster_pair (
    input logic clk, rst_n, ce_i, interlace_i,
    input logic phi2_i, rw_i,
    input logic [13:0] addr_i,
    input logic [7:0] data_i,
    output logic [63:0] pal_state_o, ntsc_state_o
);
    for (genvar p = 0; p < 2; p++) begin : profiles
        logic [6:0] h, pos;
        logic [8:0] line_count, raster, lines;
        logic field_bit, lace, line_end, frame_end;
        logic [7:0] bus_data;
        logic oe;
        logic [127:0] unused_config;
        logic [63:0] state_bits;
        mos_6560_raster #(.PAL(p == 0)) timing (
            .clk, .rst_n, .ce_i, .interlace_i, .scan_h_o(h),
            .scan_line_o(line_count), .raster_o(raster), .raster_pos_o(pos),
            .frame_lines_o(lines), .field_o(field_bit), .interlace_o(lace),
            .line_end_o(line_end), .frame_end_o(frame_end)
        );
        mos_6560_regs registers (
            .clk, .rst_n, .phi2_i, .rw_i, .addr_i, .data_i,
            .raster_i(raster), .lightpen_x_i(8'h00), .lightpen_y_i(8'h00),
            .pot_x_i(8'h00), .pot_y_i(8'h00), .data_o(bus_data),
            .data_oe_o(oe), .config_o(unused_config)
        );
        assign state_bits = {10'b0, oe, bus_data, frame_end, line_end,
                             lace, field_bit, lines, pos, raster, line_count, h};
        if (p == 0) begin : pal_output
            assign pal_state_o = state_bits;
        end else begin : ntsc_output
            assign ntsc_state_o = state_bits;
        end
    end
endmodule
