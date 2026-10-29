// Commodore 64 (breadbin, 1982) mainboard: 6510, VIC-II, SID, two 6526 CIAs,
// the 906114-01 PLA, 64 KiB DRAM, 1 Kx4 color RAM and the three ROMs.
// Source and assumption ledger: spec/spec.md.
//
// One clk edge is one VIC-II dot (8 per system clock). The board derives
// PHI2 from the dot counter: low for dots 0-3 (VIC phase one), high for
// dots 4-7 (CPU phase two). The CPU cycle ends at the PHI2 falling edge,
// half a dot before the VIC cycle edge, so every CPU access is stable over
// the VIC's eight dots. The PLA is time-multiplexed on the real board; here
// it is evaluated once for the CPU access and once per VIC fetch port.
module c64_board #(
    // mos_6567 VARIANT: 0 = 6569 PAL, 1 = 6567R8 NTSC (others as mos_6567).
    parameter int VARIANT = 0,
    // System clocks between CPU and VIC reset release (0..15); -1 selects
    // the phase unchanged VICE x64sc uses for the variant (spec/spec.md).
    parameter int VIC_START_DELAY = -1
) (
    input  logic        clk,
    input  logic        rst_n,
    // Keyboard matrix: keys[8*column + row] pressed, column = CIA1 PA bit,
    // row = CIA1 PB bit. RESTORE is wired to NMI separately.
    input  logic [63:0] keys,
    input  logic        restore_n,
    // Control ports, active low {fire, right, left, down, up}.
    input  logic [4:0]  joy1_n,
    input  logic [4:0]  joy2_n,
    // Expansion port (pulled up when no cartridge is present).
    input  logic        exrom_n,
    input  logic        game_n,
    // Host observation.
    input  logic [15:0] host_addr,
    output logic [7:0]  host_ram_q,
    output logic [3:0]  host_color_q,
    // Video.
    output logic        pixel_valid,
    output logic [3:0]  pixel,
    output logic [8:0]  pixel_row,
    output logic [9:0]  pixel_col,
    // SID digital voice outputs for the host audio mixer.
    output logic [2:0][11:0] sid_wave,
    output logic [2:0][7:0]  sid_env,
    output logic [7:0]  sid_mode_vol,
    output logic        sid_ce,
    // Bus and CPU observation.
    output logic        phi2,
    output logic [15:0] cpu_addr,
    output logic [7:0]  cpu_data_in,
    output logic [7:0]  cpu_data_out,
    output logic        cpu_we,
    output logic        cpu_fetch,
    output logic        cpu_jammed,
    output logic [15:0] cpu_pc,
    output logic [7:0]  cpu_a, cpu_x, cpu_y, cpu_s, cpu_p,
    output logic        ba, aec, irq_n, nmi_n,
    output logic [7:0]  pla_out,
    output logic        iec_atn_n, iec_clk_n, iec_data_n,
    output logic [8:0]  raster_line,
    output logic [6:0]  raster_cycle,
    output logic [31:0] cycle_count,
    output logic [31:0] frame_count
);
    localparam bit NTSC = VARIANT == 1 || VARIANT == 2 || VARIANT == 4;
    // CPU cycles per half period of the 50 Hz (PAL) / 60 Hz (NTSC) mains
    // TOD signal: 985,248 Hz / 100 and 1,022,727 Hz / 120.
    localparam int TOD_HALF = NTSC ? 8523 : 9852;
    localparam int START_DELAY = VIC_START_DELAY >= 0 ? VIC_START_DELAY : (NTSC ? 10 : 11);

    // ---------------------------------------------------------- clocks/reset
    logic [2:0] dot_q;
    logic phi2_q, cpu_clk, rst_q, vic_rst_n;
    logic [1:0] rst_sync_q;
    logic [3:0] vic_delay_q;
    always_ff @(posedge clk) begin
        dot_q <= dot_q + 3'd1;
        rst_sync_q <= {rst_sync_q[0], rst_n};
        // Release reset at dot 6 -> 7, so the first cycle edge is dot 7 -> 0.
        // ASSUMPTION: the CPU/VIC power-on phase is undefined on the real
        // board; the VIC starts START_DELAY system clocks after the CPU,
        // the phase at which unchanged VICE x64sc runs (spec/spec.md).
        if (!rst_sync_q[1]) begin
            rst_q <= 0;
            vic_rst_n <= 0;
            vic_delay_q <= 0;
        end else if (dot_q == 3'd6) begin
            rst_q <= 1;
            if (rst_q && vic_delay_q != 4'(START_DELAY)) vic_delay_q <= vic_delay_q + 4'd1;
            if ((rst_q && vic_delay_q == 4'(START_DELAY)) || START_DELAY == 0) vic_rst_n <= 1;
        end
    end
    always_ff @(negedge clk) phi2_q <= dot_q >= 3'd3 && dot_q <= 3'd6;
    assign cpu_clk = !phi2_q;
    assign phi2 = phi2_q;
    initial begin
        dot_q = 0;
        phi2_q = 0;
        rst_sync_q = 0;
        rst_q = 0;
        vic_rst_n = 0;
        vic_delay_q = 0;
    end

    // ------------------------------------------------------------------- CPU
    logic [7:0] cpu_q, cpu_d;
    logic [5:0] port_o, port_oe, port_pins;
    logic [7:0] unused_ddr, unused_latch;
    logic unused_addr_oe, unused_rw_oe, unused_data_oe, unused_fault;
    // 6510 P0-P2 have board pull-ups; P4 is the cassette sense switch
    // (open = high); P3/P5 drive the cassette write line and motor.
    assign port_pins = (port_o & port_oe) | ~port_oe;
    mos_6510 cpu (
        .clk(cpu_clk), .rst_n(rst_q), .rdy_i(ba), .irq_n, .nmi_n, .aec_i(aec),
        .bus_addr(cpu_addr), .bus_data_i(cpu_q), .bus_data_o(cpu_d), .bus_we(cpu_we),
        .bus_addr_oe(unused_addr_oe), .bus_rw_oe(unused_rw_oe), .bus_data_oe(unused_data_oe),
        .port_i(port_pins), .port_o, .port_oe, .ddr_o(unused_ddr), .latch_o(unused_latch),
        .fetch_o(cpu_fetch), .fault_o(unused_fault), .jammed_o(cpu_jammed), .pc_o(cpu_pc),
        .status_o(cpu_p), .a_o(cpu_a), .x_o(cpu_x), .y_o(cpu_y), .s_o(cpu_s)
    );
    assign cpu_data_in = cpu_q;
    assign cpu_data_out = cpu_d;

    // ------------------------------------------------------------------- PLA
    logic [7:0] pa1_pins, pb1_pins, pa2_pins, pb2_pins;
    logic casram_n, basic_n, kernal_n, charom_n, grw_n, io_n, roml_n, romh_n;
    commodore_906114 pla_cpu (
        .cas_i(1'b0), .loram_i(port_pins[0]), .hiram_i(port_pins[1]),
        .charen_i(port_pins[2]), .va14_i(pa2_pins[0]),
        .a15_i(cpu_addr[15]), .a14_i(cpu_addr[14]), .a13_i(cpu_addr[13]),
        .a12_i(cpu_addr[12]), .ba_i(ba), .aec_i(!aec), .rw_i(!cpu_we),
        .exrom_i(exrom_n), .game_i(game_n), .va13_i(1'b1), .va12_i(1'b1),
        .casram_n_o(casram_n), .basic_n_o(basic_n), .kernal_n_o(kernal_n),
        .charom_n_o(charom_n), .grw_n_o(grw_n), .io_n_o(io_n),
        .roml_n_o(roml_n), .romh_n_o(romh_n)
    );
    assign pla_out = {romh_n, roml_n, io_n, grw_n, charom_n, kernal_n, basic_n, casram_n};

    // ------------------------------------------------------------------- VIC
    logic vic_cs, vic_cycle_edge, vic_phi2_fetch, vic_color_fetch;
    logic [7:0] vic_q, vic_last;
    logic [13:0] vic1_a, vic2_a;
    logic [9:0] vic_color_a;
    logic [3:0] vic_dot;
    // The VIC computes each fetch address and consumes its data in one
    // combinational step (mos_6567 spec), so the fetch path is a false loop.
    /* verilator lint_off UNOPTFLAT */
    logic [7:0] vic1_d, vic2_d;
    logic [3:0] vic_color_d;
    /* verilator lint_on UNOPTFLAT */
    logic vic_irq_n, lp_n;
    logic [8:0] vic_line;
    assign raster_line = vic_line;
    assign vic_cs = !io_n && cpu_addr[11:10] == 2'b00;
    mos_6567 #(.VARIANT(VARIANT)) vic (
        .clk, .rst_n(vic_rst_n), .cs_i(vic_cs), .rw_i(!cpu_we), .addr_i(cpu_addr[5:0]),
        .data_i(cpu_d), .data_o(vic_q), .irq_n_o(vic_irq_n), .ba_o(ba), .aec_o(aec),
        .lp_n_i(lp_n), .rom_window_i(pa2_pins[0] && !(exrom_n && !game_n)),
        .cycle_edge_o(vic_cycle_edge), .phi1_addr_o(vic1_a), .phi1_data_i(vic1_d),
        .phi2_fetch_o(vic_phi2_fetch), .phi2_addr_o(vic2_a), .phi2_data_i(vic2_d),
        .color_fetch_o(vic_color_fetch), .color_addr_o(vic_color_a), .color_data_i(vic_color_d),
        .pixel_valid_o(pixel_valid), .pixel_o(pixel), .pixel_row_o(pixel_row),
        .pixel_col_o(pixel_col), .cycle_o(raster_cycle), .rasterline_o(vic_line),
        .dot_o(vic_dot), .last_data_o(vic_last)
    );

    // VIC address bits 15:14 come from CIA2 PA1:PA0 through inverters.
    logic [15:0] vic1_full, vic2_full;
    logic [7:0] vic1_ram, vic1_rom, vic2_ram, vic2_rom;
    logic vic1_charom_n, vic1_romh_n, vic2_charom_n, vic2_romh_n;
    logic [5:0] unused_vic_pla;
    assign vic1_full = {~pa2_pins[1], ~pa2_pins[0], vic1_a};
    assign vic2_full = {~pa2_pins[1], ~pa2_pins[0], vic2_a};
    commodore_906114 pla_vic1 (
        .cas_i(1'b0), .loram_i(port_pins[0]), .hiram_i(port_pins[1]), .charen_i(port_pins[2]),
        .va14_i(pa2_pins[0]), .a15_i(1'b1), .a14_i(1'b1), .a13_i(1'b1), .a12_i(1'b1),
        .ba_i(ba), .aec_i(1'b1), .rw_i(1'b1), .exrom_i(exrom_n), .game_i(game_n),
        .va13_i(vic1_a[13]), .va12_i(vic1_a[12]),
        .casram_n_o(unused_vic_pla[0]), .basic_n_o(unused_vic_pla[1]),
        .kernal_n_o(unused_vic_pla[2]), .charom_n_o(vic1_charom_n),
        .grw_n_o(unused_vic_pla[3]), .io_n_o(unused_vic_pla[4]),
        .roml_n_o(unused_vic_pla[5]), .romh_n_o(vic1_romh_n)
    );
    logic [5:0] unused_vic_pla2;
    commodore_906114 pla_vic2 (
        .cas_i(1'b0), .loram_i(port_pins[0]), .hiram_i(port_pins[1]), .charen_i(port_pins[2]),
        .va14_i(pa2_pins[0]), .a15_i(1'b1), .a14_i(1'b1), .a13_i(1'b1), .a12_i(1'b1),
        .ba_i(ba), .aec_i(1'b1), .rw_i(1'b1), .exrom_i(exrom_n), .game_i(game_n),
        .va13_i(vic2_a[13]), .va12_i(vic2_a[12]),
        .casram_n_o(unused_vic_pla2[0]), .basic_n_o(unused_vic_pla2[1]),
        .kernal_n_o(unused_vic_pla2[2]), .charom_n_o(vic2_charom_n),
        .grw_n_o(unused_vic_pla2[3]), .io_n_o(unused_vic_pla2[4]),
        .roml_n_o(unused_vic_pla2[5]), .romh_n_o(vic2_romh_n)
    );
    // ASSUMPTION: no cartridge drives ROMH, so an Ultimax VIC fetch reads
    // the floating bus as $FF.
    assign vic1_d = !vic1_charom_n ? vic1_rom : !vic1_romh_n ? 8'hff : vic1_ram;
    assign vic2_d = !vic2_charom_n ? vic2_rom : !vic2_romh_n ? 8'hff : vic2_ram;

    // ------------------------------------------------------------------- SID
    logic sid_cs;
    logic [7:0] sid_q;
    logic [2:0][2:0] unused_pd_sel;
    logic [2:0][11:0] pd_index;
    logic [11:0] osc3_pd_index;
    logic [10:0] unused_fc;
    logic [7:0] unused_res_filt;
    // One SID system clock per CPU cycle, mid-cycle while the access is stable.
    assign sid_ce = rst_q && dot_q == 3'd4;
    assign sid_cs = sid_ce && !io_n && cpu_addr[11:10] == 2'b01;
    // ASSUMPTION: combined waveforms use the digital AND without the
    // sampled analog pull-down tables (mos_6581 table port held at zero
    // pull-down: value equals index). POT inputs read $FF (no paddles).
    mos_6581 sid (
        .clk, .rst_n(rst_q), .ce_i(sid_ce), .cs_i(sid_cs), .rw_i(!cpu_we),
        .addr_i(cpu_addr[4:0]), .data_i(cpu_d), .data_o(sid_q),
        .pot_x_i(8'hff), .pot_y_i(8'hff),
        .pd_sel_o(unused_pd_sel), .pd_index_o(pd_index), .pd_value_i(pd_index),
        .osc3_pd_index_o(osc3_pd_index), .osc3_pd_value_i(osc3_pd_index),
        .wave_o(sid_wave), .env_o(sid_env), .fc_o(unused_fc), .res_filt_o(unused_res_filt),
        .mode_vol_o(sid_mode_vol)
    );

    // ------------------------------------------------------------------ CIAs
    logic cia1_cs_n, cia2_cs_n, cia1_irq_n, cia2_irq_n, tod_q;
    logic [7:0] cia1_q, cia2_q, pa1_o, pb1_o, pa1_oe, pb1_oe, pa2_o, pb2_o, pa2_oe, pb2_oe;
    logic [7:0] pa1_drive, pb1_drive, pa2_drive, pb2_drive;
    logic [3:0] unused_cia1, unused_cia2;
    logic unused_oe1, unused_oe2, unused_pc1, unused_pc2;
    assign cia1_cs_n = !(!io_n && cpu_addr[11:8] == 4'hc);
    assign cia2_cs_n = !(!io_n && cpu_addr[11:8] == 4'hd);
    // Port pins are pulled up; an input bit floats high.
    assign pa1_drive = (pa1_o & pa1_oe) | ~pa1_oe;
    assign pb1_drive = (pb1_o & pb1_oe) | ~pb1_oe;
    assign pa2_drive = (pa2_o & pa2_oe) | ~pa2_oe;
    assign pb2_drive = (pb2_o & pb2_oe) | ~pb2_oe;

    // Keyboard and joysticks: a closed key ties column PAc to row PBr
    // (wired-AND, one level; multi-key ghosting is not modeled).
    logic [7:0] joy1_lines, joy2_lines;
    assign joy1_lines = {3'b111, joy1_n};
    assign joy2_lines = {3'b111, joy2_n};
    always_comb begin
        pa1_pins = pa1_drive & joy2_lines;
        pb1_pins = pb1_drive & joy1_lines;
        for (int c = 0; c < 8; c++)
            for (int r = 0; r < 8; r++)
                if (keys[8*c + r]) begin
                    pa1_pins[c] = pa1_pins[c] & pb1_drive[r] & joy1_lines[r];
                    pb1_pins[r] = pb1_pins[r] & pa1_drive[c] & joy2_lines[c];
                end
    end
    assign lp_n = pb1_pins[4];

    // Serial (IEC) bus through 7406 inverters; no devices are attached, so
    // each line is released unless the C64 itself pulls it.
    assign iec_atn_n = !pa2_drive[3];
    assign iec_clk_n = !pa2_drive[4];
    assign iec_data_n = !pa2_drive[5];
    assign pa2_pins = {pa2_drive[7] & iec_data_n, pa2_drive[6] & iec_clk_n, pa2_drive[5:0]};
    assign pb2_pins = pb2_drive;

    mos_6526 cia1 (
        .clk(phi2_q), .rst_n(rst_q), .cs_n(cia1_cs_n), .rw(!cpu_we), .addr(cpu_addr[3:0]),
        .data_i(cpu_d), .data_o(cia1_q), .data_oe(unused_oe1),
        .pa_i(pa1_pins), .pb_i(pb1_pins), .pa_o(pa1_o), .pb_o(pb1_o), .pa_oe(pa1_oe), .pb_oe(pb1_oe),
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i(tod_q),
        .cnt_o(unused_cia1[0]), .cnt_oe(unused_cia1[1]), .sp_o(unused_cia1[2]),
        .sp_oe(unused_cia1[3]), .pc_n(unused_pc1), .irq_n(cia1_irq_n)
    );
    mos_6526 cia2 (
        .clk(phi2_q), .rst_n(rst_q), .cs_n(cia2_cs_n), .rw(!cpu_we), .addr(cpu_addr[3:0]),
        .data_i(cpu_d), .data_o(cia2_q), .data_oe(unused_oe2),
        .pa_i(pa2_pins), .pb_i(pb2_pins), .pa_o(pa2_o), .pb_o(pb2_o), .pa_oe(pa2_oe), .pb_oe(pb2_oe),
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i(tod_q),
        .cnt_o(unused_cia2[0]), .cnt_oe(unused_cia2[1]), .sp_o(unused_cia2[2]),
        .sp_oe(unused_cia2[3]), .pc_n(unused_pc2), .irq_n(cia2_irq_n)
    );
    assign irq_n = cia1_irq_n && vic_irq_n;
    // ASSUMPTION: RESTORE's 556 monostable is reduced to its level.
    assign nmi_n = cia2_irq_n && restore_n;

    // TOD: mains-derived 50/60 Hz square wave, counted in CPU cycles.
    logic [15:0] tod_count_q;
    always_ff @(posedge cpu_clk) begin
        if (!rst_q) begin
            tod_count_q <= 0;
            tod_q <= 0;
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (tod_count_q == 16'(TOD_HALF - 1)) begin
                tod_count_q <= 0;
                tod_q <= !tod_q;
            end else
                tod_count_q <= tod_count_q + 16'd1;
        end
    end
    logic [8:0] prev_line_q;
    always_ff @(posedge clk) begin
        prev_line_q <= vic_line;
        if (!vic_rst_n) frame_count <= 0;
        else if (vic_line == 0 && prev_line_q != 0) frame_count <= frame_count + 1;
    end

    // ---------------------------------------------------------------- memory
    logic [7:0] ram_q, basic_q, kernal_q, charom_q;
    logic [3:0] color_q;
    logic ram_we, color_we;
    // Writes to $0000/$0001 also reach DRAM, carrying the VIC's last bus
    // byte (the 6510 does not drive its port writes onto the bus).
    assign ram_we = cpu_we && aec && !casram_n;
    assign color_we = cpu_we && aec && !io_n && !grw_n && cpu_addr[11:10] == 2'b10;
    c64_memory memory (
        .cpu_clk, .cpu_addr, .cpu_ram_q(ram_q), .basic_q, .kernal_q, .charom_q,
        .cpu_color_q(color_q), .ram_we, .ram_wdata(cpu_addr[15:1] == 0 ? vic_last : cpu_d),
        .color_we,
        .vic1_addr(vic1_full), .vic1_ram_q(vic1_ram), .vic1_rom_q(vic1_rom),
        .vic2_addr(vic2_full), .vic2_ram_q(vic2_ram), .vic2_rom_q(vic2_rom),
        .vic_color_addr(vic_color_a), .vic_color_q(vic_color_d),
        .host_addr, .host_ram_q, .host_color_q
    );

    // CPU read multiplexer. Unselected reads see the VIC's last bus byte.
    always_comb begin
        cpu_q = vic_last;
        if (!casram_n) cpu_q = ram_q;
        else if (!basic_n) cpu_q = basic_q;
        else if (!kernal_n) cpu_q = kernal_q;
        else if (!charom_n) cpu_q = charom_q;
        else if (!io_n) begin
            case (cpu_addr[11:8])
                4'h0, 4'h1, 4'h2, 4'h3: cpu_q = vic_q;
                4'h4, 4'h5, 4'h6, 4'h7: cpu_q = sid_q;
                4'h8, 4'h9, 4'ha, 4'hb: cpu_q = {vic_last[7:4], color_q};
                4'hc: cpu_q = cia1_q;
                4'hd: cpu_q = cia2_q;
                default: cpu_q = vic_last;  // I/O1, I/O2: no cartridge
            endcase
        end
    end

    // Unused observation and option inputs.
    logic unused;
    assign unused = ^{roml_n, romh_n, vic_phi2_fetch, vic_color_fetch, unused_fault,
                      unused_addr_oe, unused_rw_oe, unused_data_oe, unused_ddr, unused_latch,
                      unused_vic_pla, unused_vic_pla2, unused_pd_sel,
                      unused_fc, unused_res_filt, unused_cia1, unused_cia2, unused_oe1,
                      unused_oe2, unused_pc1, unused_pc2, pa2_drive[2], pa2_drive[7:6],
                      pb2_pins, vic_cycle_edge, vic_dot};

`ifdef SIMULATION
    // Board timing contract: the VIC's dot counter tracks the board's (its
    // reset value 8 is the pending first cycle edge).
    always_ff @(posedge clk)
        if (vic_rst_n && vic_dot != {1'b0, dot_q} && !(vic_dot == 4'd8 && dot_q == 3'd7))
            $fatal(1, "VIC dot %0d out of step with board dot %0d", vic_dot, dot_q);
`endif
endmodule
