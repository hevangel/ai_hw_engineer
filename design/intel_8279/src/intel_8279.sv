// Intel 8279 Programmable Keyboard / Display Interface
// Standard: IEEE 1800-2017 SystemVerilog

`timescale 1ns / 1ps

module intel_8279 #(
    parameter int SCAN_DIV = 64
) (
    input  logic        clk,
    input  logic        rst_n,
    // CPU Interface
    input  logic        cs_n,
    input  logic        rd_n,
    input  logic        wr_n,
    input  logic        a0,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    output logic        data_oe,
    output logic        irq,
    // Scan & Return Interface
    output logic [3:0]  sl,
    input  logic [7:0]  rl,
    input  logic        shift,
    input  logic        cntl_stb,
    // Display Interface
    output logic [3:0]  out_a,
    output logic [3:0]  out_b,
    output logic        bd_n
);

    // -------------------------------------------------------------------------
    // Internal Types and Enumerations
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        CMD_MODE_SET        = 3'b000,
        CMD_PROGRAM_CLOCK   = 3'b001,
        CMD_READ_FIFO       = 3'b010,
        CMD_READ_DISPLAY    = 3'b011,
        CMD_WRITE_DISPLAY   = 3'b100,
        CMD_WRITE_INHIBIT   = 3'b101,
        CMD_CLEAR           = 3'b110,
        CMD_END_INTERRUPT   = 3'b111
    } cmd_opcode_e;

    typedef enum logic {
        READ_SRC_FIFO_SENSOR = 1'b0,
        READ_SRC_DISPLAY     = 1'b1
    } read_source_e;

    // -------------------------------------------------------------------------
    // Configuration Registers
    // -------------------------------------------------------------------------
    logic       display_16char;       // 0: 8-char, 1: 16-char
    logic       display_right_entry;  // 0: Left entry (typewriter), 1: Right entry (calculator)
    logic [2:0] keyboard_mode;        // 000-111
    logic [4:0] prescaler_reload;     // Prescaler reload value (2..31)
    logic [4:0] prescaler_cnt;        // Current prescaler counter
    logic       scan_tick;            // Pulse generated every prescaler period
    localparam int DigitBits = (SCAN_DIV > 1) ? $clog2(SCAN_DIV) : 1;
    logic [DigitBits-1:0] digit_div;

    logic       fifo_ram_ai;          // Auto-increment for FIFO/Sensor read
    logic [2:0] sensor_read_addr;     // Row address for Sensor RAM read
    // Intel specifies one shared display address and auto-increment register.
    logic       disp_ai;
    logic [3:0] disp_addr;
    logic [3:0] display_origin;

    logic       inhibit_b;            // Nibble B write inhibit
    logic       inhibit_a;            // Nibble A write inhibit
    logic       blank_b;
    logic       blank_a;
    logic [7:0] blank_code;

    logic       special_error_mode;   // Special error mode enable
    read_source_e read_source;

    // -------------------------------------------------------------------------
    // Memories & Pointers
    // -------------------------------------------------------------------------
    // 8x8 FIFO RAM / Sensor RAM
    logic [7:0] fifo_ram [8];
    logic [2:0] fifo_wr_ptr;
    logic [2:0] fifo_rd_ptr;
    logic [3:0] fifo_count;           // 0 to 8

    // 8x8 Sensor RAM image & previous scan state
    logic [7:0] sensor_ram [8];
    logic [7:0] sensor_last [8];
    logic       sensor_irq_reg;

    // 16x8 Display RAM
    logic [7:0] display_ram [16];

    // Status flags
    logic       status_du;            // Display Unavailable
    logic       status_se;            // Sensor closure / Special Error
    logic       status_overrun;       // FIFO Overrun error
    logic       status_underrun;      // FIFO Underrun error

    // Clear operation FSM
    logic [4:0] clear_timer;          // Multi-cycle clear countdown
    logic [7:0] clear_data_pattern;

    // Scan lines counter
    logic [3:0] scan_cnt;

    // Strobed Input edge detection
    logic       cntl_stb_d;

    // Keyboard Debounce and Key Tracking (8 rows x 8 columns)
    logic [7:0] key_first_scan [8]; // Keys detected on first scan
    logic [7:0] key_second_scan [8]; // Keys still held after one complete scan
    logic [7:0] key_debounced [8];  // Keys confirmed across 2 scans

    // -------------------------------------------------------------------------
    // Helper Mode Decodes
    // -------------------------------------------------------------------------
    wire is_encoded_scan = (keyboard_mode == 3'b000) || (keyboard_mode == 3'b010) ||
                           (keyboard_mode == 3'b100) || (keyboard_mode == 3'b110);
    wire is_2key_lockout = (keyboard_mode == 3'b000) || (keyboard_mode == 3'b001);
    wire is_nkey_rollover= (keyboard_mode == 3'b010) || (keyboard_mode == 3'b011);
    wire is_sensor_mode  = (keyboard_mode == 3'b100) || (keyboard_mode == 3'b101);
    wire is_strobed_mode = (keyboard_mode == 3'b110) || (keyboard_mode == 3'b111);

    // Decoded scan always exposes four digits, regardless of DD.
    wire [3:0] max_display_idx = !is_encoded_scan ? 4'd3 :
                                  (display_16char ? 4'd15 : 4'd7);

    // -------------------------------------------------------------------------
    // CPU Bus Control & Decoding
    // -------------------------------------------------------------------------
    wire bus_selected = ~cs_n;
    wire bus_write    = bus_selected & ~wr_n & rd_n;
    wire bus_read     = bus_selected & ~rd_n & wr_n;

    // Active-high output enable
    assign data_oe = bus_read;

    // Status word composition: {DU, S/E, O, U, F, NNN}
    wire [7:0] status_word = {
        status_du,
        status_se,
        status_overrun,
        status_underrun,
        (fifo_count == 4'd8),
        (fifo_count == 4'd8) ? 3'b000 : fifo_count[2:0]
    };

    // Read Data Mux
    always_comb begin
        if (a0) begin
            data_o = status_word;
        end else begin
            if (read_source == READ_SRC_DISPLAY) begin
                data_o = display_ram[disp_addr];
            end else begin
                if (is_sensor_mode) begin
                    data_o = sensor_ram[sensor_read_addr];
                end else begin
                    data_o = fifo_ram[fifo_rd_ptr];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // IRQ Generation
    // -------------------------------------------------------------------------
    always_comb begin
        if (is_sensor_mode) begin
            irq = sensor_irq_reg;
        end else begin
            irq = (fifo_count > 4'd0) || (special_error_mode && status_se);
        end
    end

    // -------------------------------------------------------------------------
    // Scan Line Output (SL[3:0])
    // -------------------------------------------------------------------------
    always_comb begin
        if (is_encoded_scan) begin
            sl = scan_cnt;
        end else begin
            // Decoded 1-of-4 active-low scan
            case (scan_cnt[1:0])
                2'b00:   sl = 4'b1110;
                2'b01:   sl = 4'b1101;
                2'b10:   sl = 4'b1011;
                2'b11:   sl = 4'b0111;
                default: sl = 4'b1111;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Display Output Multiplexing (OUT_A, OUT_B, BD_N)
    // -------------------------------------------------------------------------
    wire [3:0] active_disp_idx = display_right_entry ?
        ((display_origin + scan_cnt) & max_display_idx) :
        (scan_cnt & max_display_idx);
    wire [7:0] active_disp_char = display_ram[active_disp_idx];

    always_comb begin
        if (status_du) begin
            out_a = 4'b0000;
            out_b = 4'b0000;
            bd_n  = 1'b0;
        end else begin
            out_a = blank_a ? blank_code[3:0] : active_disp_char[3:0];
            out_b = blank_b ? blank_code[7:4] : active_disp_char[7:4];
            bd_n  = 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Prescaler & Timing Engine
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prescaler_cnt <= 5'd0;
            digit_div     <= '0;
            scan_tick     <= 1'b0;
        end else if (bus_write && a0 && (data_i[7:5] == CMD_PROGRAM_CLOCK)) begin
            prescaler_cnt <= 5'd0;
            digit_div     <= '0;
            scan_tick     <= 1'b0;
        end else begin
            if (prescaler_cnt >= (prescaler_reload - 5'd1)) begin
                prescaler_cnt <= 5'd0;
                if (digit_div == DigitBits'(SCAN_DIV - 1)) begin
                    digit_div <= '0;
                    scan_tick <= 1'b1;
                end else begin
                    digit_div <= digit_div + 1'b1;
                    scan_tick <= 1'b0;
                end
            end else begin
                prescaler_cnt <= prescaler_cnt + 5'd1;
                scan_tick     <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main Sequential Block
    // -------------------------------------------------------------------------
    integer idx;

    wire [2:0] scan_row_idx = scan_cnt[2:0] & max_display_idx[2:0];
    wire [7:0] active_keys  = ~rl;
    wire [7:0] write_mask   = {inhibit_b ? 4'h0 : 4'hF, inhibit_a ? 4'h0 : 4'hF};

    logic candidate_valid;
    logic [2:0] candidate_col;
    logic multiple_keys_down;
    logic multiple_pending_keys;
    always_comb begin
        candidate_valid = 1'b0;
        candidate_col = 3'd0;
        multiple_keys_down = ((active_keys & (active_keys - 8'd1)) != 8'd0);
        multiple_pending_keys = 1'b0;
        for (int row = 0; row < 8; row = row + 1) begin
            if (row[2:0] != scan_row_idx && |key_first_scan[row]) begin
                multiple_keys_down = 1'b1;
            end
            if (row[2:0] != scan_row_idx &&
                |(key_first_scan[row] & ~key_debounced[row])) begin
                multiple_pending_keys = 1'b1;
            end
        end
        for (int col = 0; col < 8; col = col + 1) begin
            if (!candidate_valid && active_keys[col] &&
                key_second_scan[scan_row_idx][col] &&
                !key_debounced[scan_row_idx][col]) begin
                candidate_valid = 1'b1;
                candidate_col = col[2:0];
            end
        end
        for (int col = 0; col < 8; col = col + 1) begin
            if (candidate_valid && col[2:0] != candidate_col &&
                active_keys[col] && !key_debounced[scan_row_idx][col]) begin
                multiple_pending_keys = 1'b1;
            end
        end
    end
    wire keyboard_push = scan_tick && !is_sensor_mode && !is_strobed_mode &&
                         candidate_valid && (!is_2key_lockout || !multiple_keys_down) &&
                         !(special_error_mode && (status_se || multiple_pending_keys));
    wire strobe_push = is_strobed_mode && cntl_stb && !cntl_stb_d;
    wire fifo_push = keyboard_push || strobe_push;
    wire fifo_pop = bus_read && !a0 && read_source == READ_SRC_FIFO_SENSOR &&
                    !is_sensor_mode && fifo_count != 4'd0;
    wire fifo_space = fifo_count < 4'd8 || fifo_pop;
    wire [7:0] fifo_push_data = strobe_push ? rl :
        {// ASSUMPTION: active-low SHIFT/CNTL encode as asserted-high code bits.
         ~cntl_stb, ~shift, scan_row_idx, candidate_col};
    wire [3:0] clear_idx = (clear_timer[3:0] - 4'd1) & max_display_idx;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            display_16char      <= 1'b0;
            display_right_entry <= 1'b0;
            keyboard_mode       <= 3'b000;
            prescaler_reload    <= 5'd31;

            fifo_ram_ai         <= 1'b0;
            sensor_read_addr    <= 3'd0;
            disp_ai             <= 1'b0;
            disp_addr           <= 4'd0;
            display_origin      <= 4'd0;

            inhibit_b           <= 1'b0;
            inhibit_a           <= 1'b0;
            blank_b             <= 1'b0;
            blank_a             <= 1'b0;
            blank_code          <= 8'h00;

            special_error_mode  <= 1'b0;
            read_source         <= READ_SRC_FIFO_SENSOR;

            fifo_wr_ptr         <= 3'd0;
            fifo_rd_ptr         <= 3'd0;
            fifo_count          <= 4'd0;

            sensor_irq_reg      <= 1'b0;
            status_du           <= 1'b0;
            status_se           <= 1'b0;
            status_overrun      <= 1'b0;
            status_underrun     <= 1'b0;

            clear_timer         <= 5'd0;
            clear_data_pattern  <= 8'h00;

            scan_cnt            <= 4'd0;
            cntl_stb_d          <= 1'b1;

            for (idx = 0; idx < 8; idx = idx + 1) begin
                fifo_ram[idx]       <= 8'h00;
                sensor_ram[idx]     <= 8'hFF;
                sensor_last[idx]    <= 8'hFF;
                key_first_scan[idx] <= 8'h00;
                key_second_scan[idx] <= 8'h00;
                key_debounced[idx]  <= 8'h00;
            end

            for (idx = 0; idx < 16; idx = idx + 1) begin
                display_ram[idx]    <= 8'h00;
            end
        end else begin
            cntl_stb_d <= cntl_stb;

            // -----------------------------------------------------------------
            // Display Clear Multi-Cycle Handler
            // -----------------------------------------------------------------
            if (clear_timer > 5'd0 && scan_tick) begin
                clear_timer <= clear_timer - 5'd1;
                display_ram[clear_idx] <= clear_data_pattern;
                if (!is_encoded_scan) begin
                    display_ram[{2'b01, clear_idx[1:0]}] <= clear_data_pattern;
                    display_ram[{2'b10, clear_idx[1:0]}] <= clear_data_pattern;
                    display_ram[{2'b11, clear_idx[1:0]}] <= clear_data_pattern;
                end else if (!display_16char) begin
                    display_ram[{1'b1, clear_idx[2:0]}] <= clear_data_pattern;
                end
                if (clear_timer == 5'd1) begin
                    status_du <= 1'b0;
                end
            end

            // -----------------------------------------------------------------
            // Autonomous Scan Progression
            // -----------------------------------------------------------------
            if (scan_tick) begin
                scan_cnt <= (scan_cnt >= max_display_idx) ? 4'd0 : (scan_cnt + 4'd1);

                if (is_sensor_mode) begin
                    // ---------------------------------------------------------
                    // Sensor Matrix Mode: Direct sampling without debounce
                    // ---------------------------------------------------------
                    if (!sensor_irq_reg) sensor_ram[scan_row_idx] <= rl;
                    if (!sensor_irq_reg && rl != sensor_last[scan_row_idx]) begin
                        sensor_last[scan_row_idx] <= rl;
                        if (rl != 8'hFF) status_se <= 1'b1;
                        sensor_irq_reg            <= 1'b1;
                    end
                end else if (!is_strobed_mode) begin
                    // ---------------------------------------------------------
                    // Scanned Keyboard Modes: Debouncing & Rollover/Lockout
                    // ---------------------------------------------------------
                    // Check debounce across scans
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        if (active_keys[idx]) begin
                            key_second_scan[scan_row_idx][idx] <=
                                key_first_scan[scan_row_idx][idx];
                            key_first_scan[scan_row_idx][idx] <= 1'b1;
                        end else begin
                            key_first_scan[scan_row_idx][idx] <= 1'b0;
                            key_second_scan[scan_row_idx][idx] <= 1'b0;
                            key_debounced[scan_row_idx][idx]  <= 1'b0;
                        end
                    end
                end
            end

            if (scan_tick && is_nkey_rollover && special_error_mode &&
                candidate_valid && multiple_pending_keys) begin
                status_se <= 1'b1;
            end

            // -----------------------------------------------------------------
            // Strobed Input Mode: Strobe rising edge capture
            // -----------------------------------------------------------------
            if (fifo_push) begin
                if (fifo_space) begin
                    fifo_ram[fifo_wr_ptr] <= fifo_push_data;
                    fifo_wr_ptr <= fifo_wr_ptr + 3'd1;
                    if (keyboard_push)
                        key_debounced[scan_row_idx][candidate_col] <= 1'b1;
                end else begin
                    status_overrun <= 1'b1;
                    if (keyboard_push)
                        key_debounced[scan_row_idx][candidate_col] <= 1'b1;
                end
            end
            if (fifo_pop) fifo_rd_ptr <= fifo_rd_ptr + 3'd1;
            if (fifo_push && fifo_space && !fifo_pop)
                fifo_count <= fifo_count + 4'd1;
            else if (fifo_pop && !(fifo_push && fifo_space))
                fifo_count <= fifo_count - 4'd1;

            // -----------------------------------------------------------------
            // CPU Bus Writes (Commands & Data)
            // -----------------------------------------------------------------
            if (bus_write) begin
                if (a0) begin
                    // Command Write (a0 = 1)
                    case (data_i[7:5])
                        CMD_MODE_SET: begin
                            display_right_entry <= data_i[4];
                            display_16char      <= data_i[3];
                            keyboard_mode       <= data_i[2:0];
                        end

                        CMD_PROGRAM_CLOCK: begin
                            prescaler_reload <= (data_i[4:0] < 5'd2) ? 5'd2 : data_i[4:0];
                        end

                        CMD_READ_FIFO: begin
                            read_source      <= READ_SRC_FIFO_SENSOR;
                            fifo_ram_ai      <= data_i[4];
                            sensor_read_addr <= data_i[2:0];
                        end

                        CMD_READ_DISPLAY: begin
                            read_source    <= READ_SRC_DISPLAY;
                            disp_ai        <= data_i[4];
                            disp_addr      <= data_i[3:0] & max_display_idx;
                        end

                        CMD_WRITE_DISPLAY: begin
                            disp_ai        <= data_i[4];
                            disp_addr      <= data_i[3:0] & max_display_idx;
                        end

                        CMD_WRITE_INHIBIT: begin
                            inhibit_a <= data_i[3];
                            inhibit_b <= data_i[2];
                            blank_a   <= data_i[1];
                            blank_b   <= data_i[0];
                        end

                        CMD_CLEAR: begin
                            if (!data_i[3]) blank_code <= 8'h00;
                            else if (!data_i[2]) blank_code <= 8'h20;
                            else blank_code <= 8'hFF;
                            // CD[2]: Enable Clear Display
                            if (data_i[4] || data_i[0]) begin
                                status_du   <= 1'b1;
                                clear_timer <= {1'b0, max_display_idx} + 5'd1;
                                case (data_i[3:2])
                                    2'b00:   clear_data_pattern <= 8'h00;
                                    2'b10:   clear_data_pattern <= 8'h20;
                                    2'b11:   clear_data_pattern <= 8'hFF;
                                    default: clear_data_pattern <= 8'h00;
                                endcase
                            end

                            // CF: Clear FIFO / Status (or CA)
                            if (data_i[1] || data_i[0]) begin
                                fifo_wr_ptr      <= 3'd0;
                                fifo_rd_ptr      <= 3'd0;
                                fifo_count       <= 4'd0;
                                sensor_read_addr <= 3'd0;
                                status_overrun   <= 1'b0;
                                status_underrun  <= 1'b0;
                                status_se        <= 1'b0;
                                sensor_irq_reg   <= 1'b0;
                            end

                            // CA: Clear All resync
                            if (data_i[0]) begin
                                scan_cnt <= 4'd0;
                            end
                        end

                        CMD_END_INTERRUPT: begin
                            if (is_sensor_mode) begin
                                sensor_irq_reg <= 1'b0;
                                sensor_last[scan_row_idx] <= sensor_ram[scan_row_idx];
                            end
                            if (is_nkey_rollover) begin
                                special_error_mode <= data_i[4];
                                if (!data_i[4]) begin
                                    status_se <= 1'b0;
                                end
                            end
                        end

                        default: ;
                    endcase
                end else begin
                    // Data Write (a0 = 0) to Display RAM
                    if (!status_du) begin
                        if (display_right_entry) begin
                            // A ring origin makes the newest written address
                            // appear at the right edge without copying RAM.
                            display_origin <= (disp_addr + 4'd1) & max_display_idx;
                        end
                        display_ram[disp_addr] <=
                            (display_ram[disp_addr] & ~write_mask) | (data_i & write_mask);
                        if (disp_ai) begin
                            disp_addr <= (disp_addr >= max_display_idx) ?
                                         4'd0 : (disp_addr + 4'd1);
                        end
                    end
                end
            end

            // -----------------------------------------------------------------
            // CPU Bus Reads (Pointer updates & side effects)
            // -----------------------------------------------------------------
            if (bus_read && !a0) begin
                if (read_source == READ_SRC_DISPLAY) begin
                    if (disp_ai) begin
                        disp_addr <= (disp_addr >= max_display_idx) ?
                                     4'd0 : (disp_addr + 4'd1);
                    end
                end else begin
                    if (is_sensor_mode) begin
                        if (fifo_ram_ai) begin
                            sensor_read_addr <= sensor_read_addr + 3'd1;
                        end else begin
                            sensor_irq_reg <= 1'b0;
                        end
                    end else begin
                        if (fifo_count == 4'd0) begin
                            status_underrun <= 1'b1;
                        end
                    end
                end
            end
        end
    end

`ifdef FORMAL
`ifdef FORMAL_COVER
    intel_8279_cover formal_coverage (
        .clk(clk),
        .rst_n(rst_n),
        .bd_n(bd_n),
        .status_du(status_du)
    );
`else
    intel_8279_props formal_properties (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(cs_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .a0(a0),
        .data_i(data_i),
        .data_o(data_o),
        .data_oe(data_oe),
        .irq(irq),
        .sl(sl),
        .rl(rl),
        .shift(shift),
        .cntl_stb(cntl_stb),
        .out_a(out_a),
        .out_b(out_b),
        .bd_n(bd_n),
        .fifo_count(fifo_count),
        .prescaler_cnt(prescaler_cnt),
        .prescaler_reload(prescaler_reload),
        .scan_cnt(scan_cnt),
        .status_overrun(status_overrun),
        .status_underrun(status_underrun),
        .status_du(status_du),
        .status_se(status_se),
        .special_error_mode(special_error_mode),
        .is_sensor_mode(is_sensor_mode)
    );
`endif
`endif

endmodule
