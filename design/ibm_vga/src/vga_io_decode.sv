// IBM PS/2 Display Adapter I/O and memory decode (spec "I/O and memory
// decode").
//
// ASSUMPTION V3: the VGA ports 3B0-3DF are decoded on A9-A0 (every port
// repeats every 400h, as the EGA's U16); 46E8h and 102h on A15-A0.
// ASSUMPTION V4: the 3xx ports and the RAM respond only while the card is
// enabled (46E8h bit 3 and POS 102h bit 0); the DAC ports also need 46E8h
// bit 4 (setup) = 0; POS 102h responds only in setup; the ROM, 46E8h and
// the setup port are always decoded. ASSUMPTION V5: 3C3 is not decoded.
module vga_io_decode (
    input  logic [19:0] a,
    input  logic        aen,
    input  logic        enable,      // 46E8h bit 3 & POS 102h bit 0
    input  logic        setup,       // 46E8h bit 4
    input  logic        mono_n,      // Misc Output bit 0 (1 = 3Dx)
    input  logic        dack0_n,
    input  logic        ram_en,      // Misc Output bit 1
    input  logic [1:0]  mem_map,     // Graphics Miscellaneous bits 3-2
    output logic        io_attr,     // 3C0 (read and write)
    output logic        io_attr_rd,  // 3C1 (read only, ASSUMPTION V6)
    output logic        io_c2,       // 3C2: Misc Output (W), Input Status 0 (R)
    output logic        io_seq,      // 3C4/3C5
    output logic        io_pelmask,  // 3C6
    output logic        io_dac_ra,   // 3C7: read address (W), DAC state (R)
    output logic        io_dac_wa,   // 3C8: write address (R/W)
    output logic        io_dac_data, // 3C9
    output logic        io_fcr_rd,   // 3CA read: Feature Control
    output logic        io_misc_rd,  // 3CC read: Misc Output
    output logic        io_gc,       // 3CE/3CF
    output logic        io_crtc,     // 3x4/3x5
    output logic        io_xa,       // 3xA: Feature Control (W), Input Status 1 (R)
    output logic        io_vse,      // 46E8h (write only)
    output logic        io_pos,      // 102h (setup only)
    output logic        mem_rom,
    output logic        mem_ram,
    output logic [16:0] ram_off
);
    logic io;
    logic [7:0] lo;
    logic [7:0] xb;
    logic dac;

    assign io  = !aen && enable && (a[9:8] == 2'b11);
    assign lo  = a[7:0];
    assign xb  = mono_n ? 8'hD0 : 8'hB0;
    assign dac = io && !setup;

    always_comb begin
        io_attr     = io && (lo == 8'hC0);
        io_attr_rd  = io && (lo == 8'hC1);
        io_c2       = io && (lo == 8'hC2);
        io_seq      = io && (lo[7:1] == 7'h62);          // C4, C5
        io_pelmask  = dac && (lo == 8'hC6);
        io_dac_ra   = dac && (lo == 8'hC7);
        io_dac_wa   = dac && (lo == 8'hC8);
        io_dac_data = dac && (lo == 8'hC9);
        io_fcr_rd   = io && (lo == 8'hCA);
        io_misc_rd  = io && (lo == 8'hCC);
        io_gc       = io && (lo[7:1] == 7'h67);          // CE, CF
        io_crtc     = io && (lo[7:1] == (xb[7:1] | 7'h02));
        io_xa       = io && (lo == (xb | 8'h0A));
        io_vse      = !aen && (a[15:0] == 16'h46E8);
        io_pos      = !aen && setup && (a[15:0] == 16'h0102);
    end

    always_comb begin
        // ASSUMPTION V22: 32 KB ROM window C0000h-C7FFFh
        mem_rom = dack0_n && (a[19:15] == 5'b11000);
        mem_ram = 1'b0;
        ram_off = 17'd0;
        if (dack0_n && ram_en && enable) begin
            unique case (mem_map)
                2'b00: begin mem_ram = (a[19:17] == 3'b101);  ram_off = a[16:0]; end
                2'b01: begin mem_ram = (a[19:16] == 4'hA);    ram_off = {1'b0, a[15:0]}; end
                2'b10: begin mem_ram = (a[19:15] == 5'b10110); ram_off = {2'b00, a[14:0]}; end
                2'b11: begin mem_ram = (a[19:15] == 5'b10111); ram_off = {2'b00, a[14:0]}; end
            endcase
        end
    end
endmodule
