// Both chip profiles share CPU, light-pen and POT stimulus; each has its own
// display-memory response. Packed state: {level, sample, data, oe, pixels,
// fetch address, matrix, fetch}.
module vic_pair (
    input  logic        clk, rst_n, ce_i,
    input  logic        phi2_i, rw_i,
    input  logic [13:0] addr_i,
    input  logic [7:0]  data_i,
    input  logic        lightpen_n_i,
    input  logic [7:0]  pot_x_i, pot_y_i,
    input  logic [11:0] pal_fetch_data_i, ntsc_fetch_data_i,
    output logic [13:0] pal_fetch_addr_o, ntsc_fetch_addr_o,
    output logic [63:0] pal_state_o, ntsc_state_o
);
    for (genvar p = 0; p < 2; p++) begin : profiles
        logic fetch, matrix, oe, sample, unused_frame_end;
        logic [13:0] fetch_addr;
        logic [15:0] pixels;
        logic [7:0] bus_data;
        logic [3:0] unused_voices;
        logic [8:0] level, unused_line;
        logic [6:0] unused_h;
        logic [63:0] state_bits;
        mos_6560 #(.PAL(p == 0)) vic (
            .clk, .rst_n, .ce_i, .phi2_i, .rw_i, .addr_i, .data_i,
            .data_o(bus_data), .data_oe_o(oe),
            .fetch_o(fetch), .fetch_matrix_o(matrix), .fetch_addr_o(fetch_addr),
            .fetch_data_i(p == 0 ? pal_fetch_data_i : ntsc_fetch_data_i),
            .pixel_o(pixels), .scan_h_o(unused_h), .scan_line_o(unused_line),
            .frame_end_o(unused_frame_end), .lightpen_n_i, .pot_x_i, .pot_y_i,
            .audio_sample_o(sample), .audio_voices_o(unused_voices),
            .audio_level_o(level)
        );
        // Levels are compared at sample points only.
        assign state_bits = {13'b0, sample ? level : 9'd0, sample, bus_data, oe, pixels,
                             fetch_addr, matrix, fetch};
        if (p == 0) begin : pal_output
            assign pal_state_o = state_bits;
            assign pal_fetch_addr_o = fetch_addr;
        end else begin : ntsc_output
            assign ntsc_state_o = state_bits;
            assign ntsc_fetch_addr_o = fetch_addr;
        end
    end
endmodule
