module mos_6560 #(
    parameter bit PAL = 1'b1
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce_i,
    // CPU phase-two register access.
    input  logic        phi2_i,
    input  logic        rw_i,
    input  logic [13:0] addr_i,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    output logic        data_oe_o,
    // Phase-one display fetch: address out, twelve-bit data in.
    output logic        fetch_o,
    output logic        fetch_matrix_o,
    output logic [13:0] fetch_addr_o,
    input  logic [11:0] fetch_data_i,
    // Four color indices per system clock, first pixel in bits 3..0.
    output logic [15:0] pixel_o,
    output logic [6:0]  scan_h_o,
    output logic [8:0]  scan_line_o,
    output logic        frame_end_o,
    input  logic        lightpen_n_i,
    input  logic [7:0]  pot_x_i,
    input  logic [7:0]  pot_y_i,
    output logic        audio_sample_o,
    output logic [3:0]  audio_voices_o,
    output logic [8:0]  audio_level_o
);
    logic [127:0] config_regs;
    logic [8:0] raster, raster_next, frame_lines, frame_lines_next;
    logic [6:0] raster_pos, raster_pos_next;
    logic field, interlace, line_end;
    logic [7:0] lightpen_x, lightpen_y;
    logic reg_write;
    logic unused_timing;
    assign unused_timing = field ^ interlace;
    assign reg_write = addr_i[13:8] == 6'b010000 && phi2_i && !rw_i;

    mos_6560_regs registers (
        .clk, .rst_n, .phi2_i, .rw_i, .addr_i, .data_i,
        .raster_i(raster), .lightpen_x_i(lightpen_x), .lightpen_y_i(lightpen_y),
        .pot_x_i, .pot_y_i, .data_o, .data_oe_o, .config_o(config_regs)
    );

    // Register 0 bit 7 requests interlace; the PAL profile ignores it.
    mos_6560_raster #(.PAL(PAL)) timing (
        .clk, .rst_n, .ce_i, .interlace_i(config_regs[7]),
        .scan_h_o, .scan_line_o, .raster_o(raster), .raster_pos_o(raster_pos),
        .raster_next_o(raster_next), .raster_pos_next_o(raster_pos_next),
        .frame_lines_o(frame_lines), .frame_lines_next_o(frame_lines_next),
        .field_o(field), .interlace_o(interlace), .line_end_o(line_end),
        .frame_end_o
    );

    mos_6560_video #(.PAL(PAL)) video (
        .clk, .rst_n, .ce_i, .config_i(config_regs),
        .scan_h_i(scan_h_o), .scan_line_i(scan_line_o),
        .line_end_i(line_end), .frame_end_i(frame_end_o),
        .reg_write_i(reg_write), .reg_addr_i(addr_i[3:0]), .reg_data_i(data_i),
        .fetch_data_i, .fetch_o, .fetch_matrix_o, .fetch_addr_o, .pixel_o
    );

    mos_6560_lightpen #(.PAL(PAL)) lightpen (
        .clk, .rst_n, .ce_i, .lightpen_n_i,
        .scan_h_i(scan_h_o), .scan_line_i(scan_line_o),
        .line_end_i(line_end), .frame_end_i(frame_end_o),
        .raster_i(raster), .raster_pos_i(raster_pos), .frame_lines_i(frame_lines),
        .raster_next_i(raster_next), .raster_pos_next_i(raster_pos_next),
        .frame_lines_next_i(frame_lines_next),
        .lightpen_x_o(lightpen_x), .lightpen_y_o(lightpen_y)
    );

    mos_6560_audio audio (
        .clk, .rst_n, .ce_i, .config_i(config_regs),
        .sample_o(audio_sample_o), .voices_o(audio_voices_o),
        .level_o(audio_level_o)
    );
endmodule
