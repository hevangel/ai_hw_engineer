// IBM EGA I/O and memory decode (TR sheet 4: LS27 U16, PROMs U34/U48,
// LS138 U25/U28; sheet 1: ROMCE via U17).
//
// I/O: U16 gives !AEN & A9 & (P3 normal ? A8 : !A8). A15-A10 are not
// decoded, so every port repeats every 400h. PROM U34 sees that signal,
// MONO MONITOR (Misc Output bit 0) and A7-A0; its contents are not printed.
// ASSUMPTION E3: it decodes the ports the TR documents plus 3C1 as a second
// attribute-controller write port (the BIOS's OUT_DX helper writes the
// attribute index to 3C0 and the data to 3C1, C000:0403-0416). ASSUMPTION
// E5: LP CLR = 3xB, LP SET = 3xC.
//
// Memory: PROM U48 (A19-A13, Enable RAM, memory map) is disabled while
// DACK0 is active (G1). ROM C0000h-C3FFFh; RAM in the window chosen by the
// Graphics Miscellaneous memory map bits (TR p.53).
module ega_io_decode (
    input  logic [19:0] a,
    input  logic        aen,
    input  logic        p3,          // 1 = jumper P3 at 3XX (pins 1-2)
    input  logic        mono_n,      // Misc Output bit 0 (1 = 3Dx)
    input  logic        dack0_n,
    input  logic        ram_en,      // Misc Output bit 1
    input  logic [1:0]  mem_map,     // Graphics Miscellaneous bits 3-2
    // I/O selects (combine with -IOW / -IOR outside)
    output logic        io_attr,     // 3C0/3C1 write (attribute address/data)
    output logic        io_c2,       // 3C2: Misc Output (W), Input Status 0 (R)
    output logic        io_seq,      // 3C4/3C5 (A0 selects)
    output logic        io_gc2pos,   // 3CA
    output logic        io_gc1pos,   // 3CC
    output logic        io_gc,       // 3CE/3CF (A0 selects)
    output logic        io_crtc,     // 3x4/3x5 (A0 selects)
    output logic        io_xa,       // 3xA: Feature Control (W), Input Status 1 (R)
    output logic        io_lpclr,    // 3xB
    output logic        io_lpset,    // 3xC
    // memory
    output logic        mem_rom,
    output logic        mem_ram,
    output logic [16:0] ram_off
);
    logic u16;
    logic [7:0] lo;
    logic [7:0] xb;

    assign u16 = !aen && a[9] && (p3 ? a[8] : !a[8]);
    assign lo  = a[7:0];
    assign xb  = mono_n ? 8'hD0 : 8'hB0;

    always_comb begin
        io_attr   = u16 && (lo[7:1] == 7'h60);          // C0, C1 (E3)
        io_c2     = u16 && (lo == 8'hC2);
        io_seq    = u16 && (lo[7:1] == 7'h62);          // C4, C5
        io_gc2pos = u16 && (lo == 8'hCA);
        io_gc1pos = u16 && (lo == 8'hCC);
        io_gc     = u16 && (lo[7:1] == 7'h67);          // CE, CF
        io_crtc   = u16 && (lo[7:1] == (xb[7:1] | 7'h02));
        io_xa     = u16 && (lo == (xb | 8'h0A));
        io_lpclr  = u16 && (lo == (xb | 8'h0B));
        io_lpset  = u16 && (lo == (xb | 8'h0C));
    end

    always_comb begin
        mem_rom = dack0_n && (a[19:14] == 6'b110000);
        mem_ram = 1'b0;
        ram_off = 17'd0;
        if (dack0_n && ram_en) begin
            unique case (mem_map)
                2'b00: begin mem_ram = (a[19:17] == 3'b101);  ram_off = a[16:0]; end
                2'b01: begin mem_ram = (a[19:16] == 4'hA);    ram_off = {1'b0, a[15:0]}; end
                2'b10: begin mem_ram = (a[19:15] == 5'b10110); ram_off = {2'b00, a[14:0]}; end
                2'b11: begin mem_ram = (a[19:15] == 5'b10111); ram_off = {2'b00, a[14:0]}; end
            endcase
        end
    end
endmodule
