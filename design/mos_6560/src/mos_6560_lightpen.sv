module mos_6560_lightpen #(
    parameter bit PAL = 1'b1
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       ce_i,
    input  logic       lightpen_n_i,
    input  logic [6:0] scan_h_i,
    input  logic [8:0] scan_line_i,
    input  logic       line_end_i,
    input  logic       frame_end_i,
    input  logic [8:0] raster_i,
    input  logic [6:0] raster_pos_i,
    input  logic [8:0] frame_lines_i,
    input  logic [8:0] raster_next_i,
    input  logic [6:0] raster_pos_next_i,
    input  logic [8:0] frame_lines_next_i,
    output logic [7:0] lightpen_x_o,
    output logic [7:0] lightpen_y_o
);
    localparam logic [6:0] CYCLES = PAL ? 7'd71 : 7'd65;
    logic active_q, active_d, triggered_q, triggered_d;
    logic trigger_q, trigger_d, extra_q, extra_d;
    logic [7:0] x_q, x_d, y_q, y_d;
    logic fire;
    logic [6:0] cyc, next_cyc, last_cycles;
    logic [8:0] line, last;

    always_comb begin
        active_d = active_q;
        triggered_d = triggered_q;
        trigger_d = trigger_q;
        extra_d = extra_q;
        x_d = x_q;
        y_d = y_q;
        fire = 0;
        cyc = line_end_i ? 7'd0 : scan_h_i + 7'd1;
        next_cyc = (cyc == CYCLES - 7'd1) ? 7'd0 : cyc + 7'd1;
        line = frame_end_i ? 9'd0 : (line_end_i ? scan_line_i + 9'd1 : scan_line_i);
        last = PAL ? frame_lines_i - 9'd1 : frame_lines_i;
        last_cycles = (!PAL && raster_i == frame_lines_i) ? 7'd33 : CYCLES;

        if (rst_n) begin
            // An active-low edge requests capture by the next executed cycle.
            // The final-line rule removes the half-clock extra position bit.
            if (!lightpen_n_i && !active_d) begin
                trigger_d = 1;
                if (raster_i == last && raster_pos_i == last_cycles - 7'd2)
                    extra_d = 0;
            end
            active_d = !lightpen_n_i;

            if (ce_i) begin
                fire = trigger_d;
                // At readback 0/1 the once-per-frame capture lock reopens; a
                // held pen then captures in the following cycle.
                if ((line == 0 || line >= frame_lines_next_i - 9'd1) &&
                    raster_next_i == 0 && raster_pos_next_i == 7'd1) begin
                    triggered_d = 0;
                    if (active_d) begin
                        trigger_d = 1;
                        fire = 0;
                    end
                end
                if (fire) begin
                    trigger_d = 0;
                    if (!triggered_d) begin
                        triggered_d = 1;
                        last = PAL ? frame_lines_next_i - 9'd1 : frame_lines_next_i;
                        if (!(raster_next_i == last && raster_pos_next_i > 7'd1)) begin
                            x_d = {next_cyc, extra_d};
                            y_d = raster_next_i[8:1];
                            extra_d = 1;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization with an inactive pen input.
        if (!rst_n) begin
            active_q <= 0;
            triggered_q <= 0;
            trigger_q <= 0;
            extra_q <= 1;
            x_q <= 0;
            y_q <= 0;
        end else begin
            active_q <= active_d;
            triggered_q <= triggered_d;
            trigger_q <= trigger_d;
            extra_q <= extra_d;
            x_q <= x_d;
            y_q <= y_d;
        end
    end

    assign lightpen_x_o = x_q;
    assign lightpen_y_o = y_q;
endmodule
