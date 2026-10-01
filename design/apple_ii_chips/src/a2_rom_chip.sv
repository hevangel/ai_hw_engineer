// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_rom_chip #(parameter integer T_PD = 0, parameter ROM_FILE = "") (
    input tri p1, // A7
    input tri p2, // A6
    input tri p3, // A5
    input tri p4, // A4
    input tri p5, // A3
    input tri p6, // A2
    input tri p7, // A1
    input tri p8, // A0
    output tri p9, // D0
    output tri p10, // D1
    output tri p11, // D2
    input tri p12, // GND
    output tri p13, // D3
    output tri p14, // D4
    output tri p15, // D5
    output tri p16, // D6
    output tri p17, // D7
    input tri p18, // CS2
    input tri p19, // A10
    input tri p20, // ~{CS1}
    input tri p21, // ~{CS3}
    input tri p22, // A9
    input tri p23, // A8
    input tri p24 // VCC
);
    logic powered;
    assign powered = (p24 === 1'b1 && p12 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [7:0] rom [0:2047];
    logic [10:0] address;
    logic [7:0] data;
    initial begin
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end
    assign address = {p19,p22,p23,p1,p2,p3,p4,p5,p6,p7,p8};
    assign data = rom[address];
    assign #(T_PD) p9 = powered ? ((p18 & ~p20 & ~p21) ? data[0] : 1'bz) : 1'bx;
    assign #(T_PD) p10 = powered ? ((p18 & ~p20 & ~p21) ? data[1] : 1'bz) : 1'bx;
    assign #(T_PD) p11 = powered ? ((p18 & ~p20 & ~p21) ? data[2] : 1'bz) : 1'bx;
    assign #(T_PD) p13 = powered ? ((p18 & ~p20 & ~p21) ? data[3] : 1'bz) : 1'bx;
    assign #(T_PD) p14 = powered ? ((p18 & ~p20 & ~p21) ? data[4] : 1'bz) : 1'bx;
    assign #(T_PD) p15 = powered ? ((p18 & ~p20 & ~p21) ? data[5] : 1'bz) : 1'bx;
    assign #(T_PD) p16 = powered ? ((p18 & ~p20 & ~p21) ? data[6] : 1'bz) : 1'bx;
    assign #(T_PD) p17 = powered ? ((p18 & ~p20 & ~p21) ? data[7] : 1'bz) : 1'bx;

endmodule
`default_nettype wire
