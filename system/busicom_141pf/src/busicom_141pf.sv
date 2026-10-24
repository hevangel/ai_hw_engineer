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
    input  logic        drum_idx_i,   // index sensor -> ROM2 bit 0
    input  logic        panel_tick_i, // host bridge tick (level toggles)
    // front panel -> board (quasi-static, host provided)
    input  logic [31:0] keys_mask_i,  // bit i = scancode 129+i pressed
    input  logic [3:0]  precision_i,  // decimal-point selector: 0,1,2,3,4,5,6,8 (no 7)
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
    output logic [9:0]  kb_scan_o     // keyboard scan one-low (4003 #0)
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
    // ROM-port select decoding (review finding B1, 2026-10-23).
    //
    // The 4001s compare the FULL SRC X2 nibble against their strapped chip
    // number, and the firmware addresses every functionally-relevant ROM
    // port with the exact chip number, so the chips see the raw bus. Trace
    // of the Kintli disassembly (rel-1-0-1, addresses per Kintli's own
    // comments):
    //   $065/$068  src 4< + wrr  X2 = R8 = 0  -> ROM0 (shifter clocks/data)
    //   $02e/$033/$0c0  src 3< + rdr  X2 = R6 = 1 -> ROM1 (keyboard/switches)
    //   $06d/$06e  fim 1< $20 + src 1< + rdr  X2 = R2 = 2 -> ROM2 (drum index)
    //   $01e-$020  inc 6 + src 3< + rdr  X2 = R6 = 2 -> ROM2 (paper button)
    // All RAM-side SRC selects pass through unmodified as well (they carry
    // chip/register fields the 4001s ignore). SRC nibbles 3-15 occur only on
    // stray selects (e.g. the WRR at $243 goes out with the leftover R8=1);
    // they simply select no ROM, exactly as in the independent Ilmer
    // reference, whose 4001 model compares the whole nibble with no
    // aliasing. An earlier build rewrote SRC X2 nibbles > 4 mod 5 before the
    // 4001s saw them; that translator had no hardware basis (nothing in the
    // Kintli disassembly or the replica documentation describes it) and is
    // functionally inert for this firmware - removed. See
    // failure_notes/2026-10-23-busicom-src-port-alias.md.
    // ------------------------------------------------------------------------

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
    // ROMs: the design-folder 4001, five instances, each loading its
    // authentic 141-PF mask from src/rom/rom_4001_N.hex ($readmemh; the
    // path resolves against the simulator's working directory, which the
    // launch scripts set to the system folder). Board straps per spec 3.1:
    // rom0 drives the 4003 shifters (IO_DIR 0111), rom1 keyboard columns
    // (inputs), rom2 drum index + paper button, rom3/rom4 unused.
    // ------------------------------------------------------------------------
    logic [3:0] rom0_port;

    intel_4001 #(
        .CHIP_NO  (4'h0),
        .IO_DIR   (4'b0111),
        .ROM_FILE ("src/rom/rom_4001_0.hex")
    ) u_rom0 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[0]), .data_oe(rom_data_oe[0]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(rom0_port), .port_oe(), .port_read_o()
    );

    // keyboard matrix columns are decoded below (front-panel section)
    logic [3:0] kb_col;

    // strobe from the keyboard ROM: high while ROM1 drives its (input) port
    // value onto the bus, i.e. the firmware is sampling the matrix columns
    logic rom1_port_read;

    intel_4001 #(
        .CHIP_NO  (4'h1),
        .IO_DIR   (4'b0000),
        .ROM_FILE ("src/rom/rom_4001_1.hex")
    ) u_rom1 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[1]), .data_oe(rom_data_oe[1]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(kb_col), .port_o(), .port_oe(), .port_read_o(rom1_port_read)
    );

    // ROM2 port pins: bit3 = paper button, bit0 = drum index pulse

    intel_4001 #(
        .CHIP_NO  (4'h2),
        .IO_DIR   (4'b0000),
        .ROM_FILE ("src/rom/rom_4001_2.hex")
    ) u_rom2 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[2]), .data_oe(rom_data_oe[2]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i({paper_btn_i, 2'b00, drum_idx_i}), .port_o(), .port_oe(),
        .port_read_o()
    );
    intel_4001 #(
        .CHIP_NO  (4'h3),
        .IO_DIR   (4'b0000),
        .ROM_FILE ("src/rom/rom_4001_3.hex")
    ) u_rom3 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[3]), .data_oe(rom_data_oe[3]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe(), .port_read_o()
    );
    intel_4001 #(
        .CHIP_NO  (4'h4),
        .IO_DIR   (4'b0000),
        .ROM_FILE ("src/rom/rom_4001_4.hex")
    ) u_rom4 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[4]), .data_oe(rom_data_oe[4]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe(), .port_read_o()
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
    // Kintli $064-$069 clocks shared ROM0 bit1 data into the shifters.
    // Keyboard selection is active low ($0bc-$0bd inserts one zero).
    // Data has the same polarity for keyboard and printer. Printer shifter
    // #2 takes #1's serial out (MSB before the shift) - a 20-bit chain.
    // ------------------------------------------------------------------------
    logic sh1_so;
    logic [9:0] sh1_q, sh2_q;

    intel_4003 #(.WIDTH(10)) u_sh_keyboard (
        .clk(clk), .rst_n(rst_n),
        .cp_i(rom0_port[0]), .data_in_i(rom0_port[1]), .en_i(1'b1),
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
    // The firmware scans by shifting a single zero through 4003 #0. Rows 0-7
    // are key rows (4 columns each, scancode 129+4r+c layout per spec 4.1);
    // rows 8/9 are the decimal-point and rounding selector switches read
    // through the same matrix. Written as a flat case: xezim re-evaluates
    // always_comb blocks on every clock edge, so this stays cheap.
    always_comb begin
        case (~kb_scan_o)
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
    //
    // Drum phase convention (review finding B2): the index pulse marks
    // character 0 in the print position (Kintli section 3.3). This board
    // captures `drum_pos_i` at the instant the hammer edge arrives; the
    // host testbench advances `drum_pos_i` at each TEST-high half-spin so
    // that value is the character in the print window at hammer time. The
    // independent reference oracle instead derives the position from its
    // sector counter as (spin/2 - 1) mod 13, i.e. one lower than the
    // half-spin count, because it evaluates at the sector tick rather than
    // at the hammer edge. The two conventions are two reference-edge
    // choices for the same drum; they were aligned against the scanned
    // manual examples (42-example regression prints identical tapes), not
    // derived from a shared formula.
    logic [1:0] ram0_prev;
    logic [1:0] tick_prev;
    logic key_seen;

    wire hammer_edge  = (ram0_prev[0] == 1'b0) && (ram0_port[1] == 1'b1);
    wire advance_edge = (ram0_prev[1] == 1'b0) && (ram0_port[3] == 1'b1);
    wire tick_pulse   = (panel_tick_i != tick_prev[0]);
    // The firmware samples the matrix by RDR through ROM1's port; the 4001's
    // port_read_o strobe (spec 7.4) marks exactly those bus periods.
    wire kbd_sampled  = rom1_port_read && kb_col != 4'h0;

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
                // Kintli section 3.3: index identifies character zero;
                // capture the character at the instant the hammer fires.
                hammer_data_o <= {drum_pos_i, sh2_q, sh1_q};
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
    // Board-level debug traces (review finding B3): everything below uses
    // only this module's own signals - the keyboard ROM's port_read strobe
    // and a debug-only fetch snoop - with no hierarchical references into
    // the chip instances. CPU-internal breakpoints (e.g. the pseudo-engine
    // checkpoints at PC $029/$037) live in tb_top.sv, which may reach into
    // the DUT hierarchy.
    logic [2:0] dbg_phase;
    logic [3:0] dbg_opr, dbg_opa;
    logic [3:0] dbg_prev_sel = 4'hF;  // driven only by the trace block below
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dbg_phase    <= 3'd0;
            dbg_opr      <= 4'h0;
            dbg_opa      <= 4'h0;
        end else begin
            if (sync) dbg_phase <= 3'd1;
            else if (dbg_phase == 3'd7) dbg_phase <= 3'd0;
            else dbg_phase <= dbg_phase + 3'd1;
            if (dbg_phase == 3'd3) dbg_opr <= data_bus;
            if (dbg_phase == 3'd4) dbg_opa <= data_bus;
        end
    end
    always @(posedge clk) begin
        if (rst_n) begin
            // SRC port selects: the X2 nibble of every SRC word, so the
            // firmware's port usage can be mapped from the log.
            if (dbg_phase == 3'd6 && dbg_opr == 4'h2 && dbg_opa[0] &&
                data_bus != dbg_prev_sel)
                dbg_prev_sel <= data_bus;
            `ifdef DEBUG_XLATE
            if (dbg_phase == 3'd6 && dbg_opr == 4'h2 && dbg_opa[0] &&
                data_bus != 4'hF)
                $display("[%0t] SRCSEL x2=%0d cm_rom=%b",
                         $time, data_bus, cm_rom);
            `endif            // keyboard-port reads that land on key row 6 (zero or not)
            if (rom1_port_read && kb_scan_o == 10'b0001000000)
                $display("[%0t] KBDROW6 col=%b bus=%b keys=%08h",
                         $time, kb_col, data_bus, keys_mask_i);
            // RAM I/O commands (WRM/WMP/WR0-3/RDM/RD0-3/ADM/SBM) with the
            // bus value, while a CM-RAM line 0 pointer is active
            if (cm_ram[0] && dbg_opr == 4'he && dbg_phase >= 3'd6 &&
                dbg_opa != 4'h2 && dbg_opa != 4'h3 && dbg_opa != 4'ha)
                $display("[%0t] RAMIO opa=%h bus=%b",
                         $time, dbg_opa, data_bus);
        end
    end
    `endif

endmodule
