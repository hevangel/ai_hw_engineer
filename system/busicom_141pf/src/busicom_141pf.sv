`timescale 1ns/1ps
// ============================================================================
// BUSICOM 141-PF board — virtual platform hardware.
//
// Wires the MCS-4 chip designs into the calculator board (spec section 3):
// shared 4-bit data bus, 4004 CPU, five 4001 ROMs (authentic calculator
// masks), two 4002 RAMs on separate CM-RAM lines, and three 4003 shift
// registers clocked from the ROM0 port lines. The front panel (keyboard
// matrix, printer drum, lamps) is intentionally NOT modelled here: this
// module exposes the board-edge signals so the testbench can attach either
// a DPI host bridge or a headless checker.
// ============================================================================
module busicom_141pf (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clr_n,        // historical CL: clears 4001 I/O latches
    input  logic        test_i,       // printer drum timing -> CPU TEST pin
    // front panel -> board
    input  logic [3:0]  kb_col_i,     // keyboard matrix columns (ROM1 pins)
    input  logic [3:0]  rom2_pin_i,   // {paper_btn, 2'b00, drum_index} (ROM2 pins)
    // board -> front panel
    output logic [3:0]  rom0_port_o,  // shifter clock/data lines
    output logic [3:0]  ram0_port_o,  // printer control: red/hammer/-/advance
    output logic [3:0]  ram1_port_o,  // lamps: memory/overflow/negative
    output logic [9:0]  kb_scan_o,    // keyboard scan one-hot (4003 #0)
    output logic [19:0] printer_bits_o // hammer select word (4003 #1 + #2)
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
        .data_i(data_bus), .data_o(rom_data_o[0]), .data_oe(rom_data_oe[0]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(rom0_port), .port_oe()
    );
    assign rom0_port_o = rom0_port;

    intel_4001_rom1 u_rom1 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[1]), .data_oe(rom_data_oe[1]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(kb_col_i), .port_o(), .port_oe()
    );
    intel_4001_rom2 u_rom2 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[2]), .data_oe(rom_data_oe[2]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(rom2_pin_i), .port_o(), .port_oe()
    );
    intel_4001_rom3 u_rom3 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[3]), .data_oe(rom_data_oe[3]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe()
    );
    intel_4001_rom4 u_rom4 (
        .clk(clk), .rst_n(rst_n), .clr_n(clr_n),
        .data_i(data_bus), .data_o(rom_data_o[4]), .data_oe(rom_data_oe[4]),
        .sync(sync), .cm_rom(cm_rom),
        .port_i(4'h0), .port_o(), .port_oe()
    );

    // ------------------------------------------------------------------------
    // RAM: two 4002-1s, one per CM-RAM line (firmware selects via DCL).
    // The PROM port pin is strapped low.
    // ------------------------------------------------------------------------
    intel_4002 #(.Variant1(1'b1)) u_ram0 (
        .clk(clk), .rst_n(rst_n),
        .data_i(data_bus), .data_o(ram0_data_o), .data_oe(ram0_data_oe),
        .sync(sync), .cm_ram_i(cm_ram[0]),
        .po_i(1'b0),
        .io_o(ram0_port_o)
    );
    intel_4002 #(.Variant1(1'b1)) u_ram1 (
        .clk(clk), .rst_n(rst_n),
        .data_i(data_bus), .data_o(ram1_data_o), .data_oe(ram1_data_oe),
        .sync(sync), .cm_ram_i(cm_ram[1]),
        .po_i(1'b0),
        .io_o(ram1_port_o)
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

    assign printer_bits_o = {sh2_q, sh1_q};

endmodule
