`timescale 1ns/1ps
// ============================================================================
// BUSICOM 141-PF board — virtual platform hardware.
//
// Wires the MCS-4 chip designs into the calculator board (spec section 3):
// shared 4-bit data bus, 4004 CPU, five 4001 ROMs (authentic calculator
// masks), two 4002 RAMs on separate CM-RAM lines, and three 4003 shift
// registers clocked from the ROM0 port lines.
//
// The front-panel electronics (keyboard matrix decode, printer drum
// position, hammer/paper/red edge capture, lamps) are also modelled here,
// in the clock domain, so the host bridge only needs a low-rate view:
// quasi-static inputs (key mask, selector switches, paper button) and
// latched one-shot events out (print, advance). See spec section 4/5.
// ============================================================================
module busicom_141pf (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clr_n,        // historical CL: clears 4001 I/O latches
    input  logic        test_i,       // printer drum timing -> CPU TEST pin
    input  logic        panel_tick_i, // host bridge tick (level toggles)
    // front panel -> board (quasi-static, host provided)
    input  logic [31:0] keys_mask_i,  // bit i = scancode 129+i pressed
    input  logic [3:0]  precision_i,  // decimal digits selector 0..8
    input  logic [3:0]  rounding_i,   // 0 float, 1 round, 8 truncate
    input  logic        paper_btn_i,  // manual paper advance button
    // board -> front panel
    output logic        hammer_evt_o, // one-shot: hammer_data_o is fresh
    output logic [23:0] hammer_data_o,// {drum_pos[3:0], shifter word[19:0]}
    output logic        advance_evt_o,// one-shot: paper advanced one line
    output logic        red_o,        // red/black ribbon level (RAM0 bit0)
    output logic [2:0]  lamps_o,      // {negative, overflow, memory}
    input  logic [3:0]  drum_pos_i,   // current drum character position 0..12
    output logic        key_seen_o,   // one-shot: firmware sampled the key
    output logic [9:0]  kb_scan_o     // keyboard scan one-hot (4003 #0)
);

    // ------------------------------------------------------------------------
    // Shared 4-bit data bus. Every chip drives 4'h0 while data_oe is low, so
    // an OR tree resolves the bus (exactly one driver is enabled at a time).
    // ------------------------------------------------------------------------
    logic [3:0] data_bus;

    logic [3:0] cpu_data_o,  ram0_data_o,  ram1_data_o;
    logic       cpu_data_oe, ram0_data_oe, ram1_data_oe;
    logic [3:0] rom_data_o   [5];
    logic       rom_data_oe  [5];

    assign data_bus = (cpu_data_oe  ? cpu_data_o   : 4'h0)
                    | (rom_data_oe[0] ? rom_data_o[0] : 4'h0)
                    | (rom_data_oe[1] ? rom_data_o[1] : 4'h0)
                    | (rom_data_oe[2] ? rom_data_o[2] : 4'h0)
                    | (rom_data_oe[3] ? rom_data_o[3] : 4'h0)
                    | (rom_data_oe[4] ? rom_data_o[4] : 4'h0)
                    | (ram0_data_oe ? ram0_data_o : 4'h0)
                    | (ram1_data_oe ? ram1_data_o : 4'h0);

    // ------------------------------------------------------------------------
    // ROM-port select alias translator.
    //
    // The firmware addresses the five 4001 I/O ports by (SRC X2 nibble
    // mod 5): trace shows it selects nibbles 0/1/2/4/5/7, where 5 aliases
    // to port 0 (shifter clocks) and 7 aliases to port 2 (drum index /
    // paper button). The stock 4001 compares the whole nibble against its
    // strapped chip number, so the board rewrites ROM-port SRC operands
    // (nibble mod 5) before the chips snoop them. Only SRC-X2 words under
    // CM-ROM are translated; fetch bytes, WRR data and RAM selects pass
    // through untouched.
    // ------------------------------------------------------------------------
    localparam logic [2:0] PhA1 = 3'd0;
    localparam logic [2:0] PhM1 = 3'd3;
    localparam logic [2:0] PhM2 = 3'd4;
    localparam logic [2:0] PhX2 = 3'd6;
    localparam logic [2:0] PhX3 = 3'd7;

    logic [2:0] xlate_phase;
    logic [3:0] xlate_opr, xlate_opa;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            xlate_phase <= PhA1;
            xlate_opr   <= 4'h0;
            xlate_opa   <= 4'h0;
        end else begin
            if (sync) xlate_phase <= PhA1 + 3'd1;
            else if (xlate_phase == PhX3) xlate_phase <= PhA1;
            else xlate_phase <= xlate_phase + 3'd1;

            if (xlate_phase == PhM1) xlate_opr <= data_bus;
            if (xlate_phase == PhM2) xlate_opa <= data_bus;
        end
    end

    wire xlate_src_x2 = (xlate_phase == PhX2) &&
                        (xlate_opr == 4'h2) && xlate_opa[0];

    wire [3:0] xlate_raw = data_bus;
    wire       xlate_remap = xlate_src_x2 && (xlate_raw > 4'd4);

    logic [3:0] data_chips;
    always_comb begin
        case ({xlate_remap, xlate_raw})
            default: data_chips = xlate_raw;
            5'b1_0101: data_chips = 4'h0;  // 5 -> 0
            5'b1_0110: data_chips = 4'h1;  // 6 -> 1
            5'b1_0111: data_chips = 4'h2;  // 7 -> 2
            5'b1_1000: data_chips = 4'h3;  // 8 -> 3
            5'b1_1001: data_chips = 4'h4;  // 9 -> 4
            5'b1_1010: data_chips = 4'h0;  // 10 -> 0
            5'b1_1011: data_chips = 4'h1;  // 11 -> 1
            5'b1_1100: data_chips = 4'h2;  // 12 -> 2
            5'b1_1101: data_chips = 4'h3;  // 13 -> 3
            5'b1_1110: data_chips = 4'h4;  // 14 -> 4
            5'b1_1111: data_chips = 4'h0;  // 15 -> 0
        endcase
    end

    // ------------------------------------------------------------------------
    // CPU
    // ------------------------------------------------------------------------
    logic sync, cm_rom;
    logic [3:0] cm_ram;

    intel_4004 u_cpu (
        .clk     (clk),
        .rst_n   (rst_n),
        .test_i  (test_i),
        .data_i  (data_bus),
        .data_o  (cpu_data_o),
        .data_oe (cpu_data_oe),
        .sync    (sync),
        .cm_rom  (cm_rom),
        .cm_ram  (cm_ram)
    );

    // ------------------------------------------------------------------------
    // ROMs (generated wrappers carry the authentic masks and board straps)
    // ------------------------------------------------------------------------
    logic [3:0] rom0_port;

    intel_4001_rom0 u_rom0 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_chips), .data_o(rom_data_o[0]), .data_oe(rom_data_oe[0]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(rom0_port), .port_oe()
    );

    // keyboard matrix columns are decoded below (front-panel section)
    logic [3:0] kb_col;

    intel_4001_rom1 u_rom1 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_chips), .data_o(rom_data_o[1]), .data_oe(rom_data_oe[1]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(kb_col), .port_o(), .port_oe()
    );

    // ROM2 port pins: bit3 = paper button, bit0 = drum index pulse
    logic drum_idx;

    intel_4001_rom2 u_rom2 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_chips), .data_o(rom_data_o[2]), .data_oe(rom_data_oe[2]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i({paper_btn_i, 2'b00, drum_idx}), .port_o(), .port_oe()
    );
    intel_4001_rom3 u_rom3 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_chips), .data_o(rom_data_o[3]), .data_oe(rom_data_oe[3]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe()
    );
    intel_4001_rom4 u_rom4 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_chips), .data_o(rom_data_o[4]), .data_oe(rom_data_oe[4]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe()
    );

    // ------------------------------------------------------------------------
    // RAM: two 4002-1s, one per CM-RAM line (firmware selects via DCL).
    // The PROM port pin is strapped low.
    // ------------------------------------------------------------------------
    logic [3:0] ram0_port, ram1_port;

    intel_4002 #(.Variant1(1'b1)) u_ram0 (
        .clk(clk), .rst_n(rst_n),
        .data_i(data_bus), .data_o(ram0_data_o), .data_oe(ram0_data_oe),
        .sync(sync), .cm_ram_i(cm_ram[0]),
        .po_i(1'b0),
        .io_o(ram0_port)
    );
    intel_4002 #(.Variant1(1'b1)) u_ram1 (
        .clk(clk), .rst_n(rst_n),
        .data_i(data_bus), .data_o(ram1_data_o), .data_oe(ram1_data_oe),
        .sync(sync), .cm_ram_i(cm_ram[0]),
        .po_i(1'b1),
        .io_o(ram1_port)
    );

    // ------------------------------------------------------------------------
    // 4003 shift registers, clocked from the ROM0 port lines (spec 3.1).
    // The ROM port drives an active-low pulse; the 4003 shifts on the
    // rising edge of cp_i, which is the falling edge of the firmware's
    // active-low pulse. Serial data is ~bit1 into the keyboard shifter and
    // bit1 into the printer chain (as on the real board). Printer shifter
    // #2 takes #1's serial out (MSB before the shift) - a 20-bit chain.
    // ------------------------------------------------------------------------
    logic sh1_so;
    logic [9:0] sh1_q, sh2_q;

    intel_4003 #(.WIDTH(10)) u_sh_keyboard (
        .clk(clk), .rst_n(rst_n),
        .cp_i(rom0_port[0]), .data_in_i(~rom0_port[1]), .en_i(1'b1),
        .q_o(kb_scan_o), .so_o()
    );
    intel_4003 #(.WIDTH(10)) u_sh_printer_lo (
        .clk(clk), .rst_n(rst_n),
        .cp_i(rom0_port[2]), .data_in_i(rom0_port[1]), .en_i(1'b1),
        .q_o(sh1_q), .so_o(sh1_so)
    );
    intel_4003 #(.WIDTH(10)) u_sh_printer_hi (
        .clk(clk), .rst_n(rst_n),
        .cp_i(rom0_port[2]), .data_in_i(sh1_so), .en_i(1'b1),
        .q_o(sh2_q), .so_o()
    );

    // ------------------------------------------------------------------------
    // Front panel: keyboard matrix decode
    // ------------------------------------------------------------------------
    // The firmware scans by shifting a one-hot through 4003 #0. Rows 0-7
    // are key rows (4 columns each, scancode 129+4r+c layout per spec 4.1);
    // rows 8/9 are the decimal-point and rounding selector switches read
    // through the same matrix. Written as a flat case: xezim re-evaluates
    // always_comb blocks on every clock edge, so this stays cheap.
    always_comb begin
        case (kb_scan_o)
            10'b0000000001:
                kb_col = {keys_mask_i[3], keys_mask_i[2], keys_mask_i[1],
                          keys_mask_i[0]};
            10'b0000000010:
                kb_col = {keys_mask_i[7], keys_mask_i[6], keys_mask_i[5],
                          keys_mask_i[4]};
            10'b0000000100:
                kb_col = {keys_mask_i[11], keys_mask_i[10], keys_mask_i[9],
                          keys_mask_i[8]};
            10'b0000001000:
                kb_col = {keys_mask_i[15], keys_mask_i[14], keys_mask_i[13],
                          keys_mask_i[12]};
            10'b0000010000:
                kb_col = {keys_mask_i[19], keys_mask_i[18], keys_mask_i[17],
                          keys_mask_i[16]};
            10'b0000100000:
                kb_col = {keys_mask_i[23], keys_mask_i[22], keys_mask_i[21],
                          keys_mask_i[20]};
            10'b0001000000:
                kb_col = {keys_mask_i[27], keys_mask_i[26], keys_mask_i[25],
                          keys_mask_i[24]};
            10'b0010000000:
                kb_col = {keys_mask_i[31], keys_mask_i[30], keys_mask_i[29],
                          keys_mask_i[28]};
            10'b0100000000: kb_col = precision_i;
            10'b1000000000: kb_col = rounding_i;
            default: kb_col = 4'h0;
        endcase
    end

    // ------------------------------------------------------------------------
    // Front panel: printer drum position and event capture
    // ------------------------------------------------------------------------
    // The drum position arrives from the testbench (which generates the
    // sector/index timing). The character under the hammers while a hammer
    // pulse arrives is the previous position (the sector pulse closes the
    // print window). Hammer and paper-advance are RAM0 port rising edges;
    // they latch a one-shot event that survives until the host bridge
    // acknowledges it with a panel tick.
    logic [1:0] ram0_prev;
    logic [1:0] tick_prev;
    logic key_seen;

    wire hammer_edge  = (ram0_prev[0] == 1'b0) && (ram0_port[1] == 1'b1);
    wire advance_edge = (ram0_prev[1] == 1'b0) && (ram0_port[3] == 1'b1);
    wire tick_pulse   = (panel_tick_i != tick_prev[0]);
    wire kbd_sampled  = u_rom1.u_4001.s_rdr && u_rom1.u_4001.io_selected &&
                        u_rom1.u_4001.phase >= 6 && kb_col != 4'h0;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ram0_prev  <= 2'b00;
            tick_prev  <= 2'b00;
            key_seen   <= 1'b0;
            hammer_evt_o <= 1'b0;
            hammer_data_o <= 24'h0;
            advance_evt_o <= 1'b0;
            red_o       <= 1'b0;
            lamps_o     <= 3'b000;
        end else begin
            ram0_prev <= {ram0_port[3], ram0_port[1]};
            tick_prev <= {tick_prev[0], panel_tick_i};

            if (tick_pulse) begin
                // events were delivered to the host with this tick
                hammer_evt_o  <= 1'b0;
                advance_evt_o <= 1'b0;
                key_seen      <= 1'b0;
            end
            if (hammer_edge) begin
                hammer_evt_o  <= 1'b1;
                // the sector pulse closes the character's print window, so
                // the character under the hammers is the previous position
                hammer_data_o <= {(drum_pos_i == 4'd0 ? 4'd12
                                                      : drum_pos_i - 4'd1),
                                  sh2_q, sh1_q};
            end
            if (advance_edge)
                advance_evt_o <= 1'b1;
            // a fresh sample re-arms the latch after the tick clear, so
            // every key read delivers its own event to the host
            if (kbd_sampled)
                key_seen <= 1'b1;

            red_o   <= ram0_port[0];
            lamps_o <= ram1_port[2:0];
        end
    end

    assign key_seen_o = key_seen;

    `ifdef DEBUG_TRACE
    // Keyboard-read visibility: the firmware reads ROM1's port (RDR) to
    // sample the matrix. Trace every visit to key row 6 (zero or not) with
    // the bus value the CPU actually sees, plus every SRC port select so
    // the firmware's port usage can be mapped.
    logic [3:0] prev_iosel = 4'hF;
    always @(posedge clk) begin
        if (rst_n) begin
            if (u_rom1.u_4001.io_sel_q != prev_iosel) begin
                prev_iosel <= u_rom1.u_4001.io_sel_q;
                `ifdef DEBUG_XLATE
                $display("[%0t] SRCSEL raw=%0d xphase=%0d cm=%b opr=%h opa=%h src=%b",
                         $time, u_rom1.u_4001.io_sel_q, xlate_phase, cm_rom,
                         xlate_opr, xlate_opa, xlate_src_x2);
                `endif
            end
            if (u_rom1.u_4001.s_rdr && u_rom1.u_4001.io_selected &&
                u_rom1.u_4001.phase >= 6 && kb_scan_o == 10'b0001000000)
                $display("[%0t] KBDROW6 col=%b bus=%b acc=%b keys=%08h",
                         $time, u_rom1.u_4001.rdr_value, data_bus, u_cpu.acc,
                         keys_mask_i);
            // RAM0 I/O commands (WMP/WR0/RD0/WRM/RDM/ADM) with bus value
            if (dut.u_ram0.selected && dut.u_ram0.cmd_opr == 4'he &&
                dut.u_ram0.phase >= 6)
                $display("[%0t] RAM0IO opa=%h bus=%b addr=%b",
                         $time, dut.u_ram0.cmd_opa, data_bus, dut.u_ram0.addr);
            // pseudo-engine key translation checkpoints
            if (u_cpu.pc == 12'h029)
                $display("[%0t] KEYPROC pc=029 R0R1=%h%h acc=%h",
                         $time, u_cpu.idx[0], u_cpu.idx[1], u_cpu.acc);
            if (u_cpu.pc == 12'h037)
                $display("[%0t] KEYPROC pc=037 R4=%h R5=%h (param,func)",
                         $time, u_cpu.idx[4], u_cpu.idx[5]);
        end
    end
    `endif

endmodule
