// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_2513 #(parameter integer T_PD = 0, parameter ROM_FILE = "") (
    input tri p1, // VGG
    output tri p4, // O1
    output tri p5, // O2
    output tri p6, // O3
    output tri p7, // O4
    output tri p8, // O5
    input tri p10, // GND
    input tri p11, // ~{CE}
    input tri p12, // VDD
    input tri p14, // A1
    input tri p15, // A2
    input tri p16, // A3
    input tri p17, // A4
    input tri p18, // A5
    input tri p19, // A6
    input tri p20, // A7
    input tri p21, // A8
    input tri p22, // A9
    input tri p24 // VCC
);
    logic powered;
    assign powered = (p24 === 1'b1 && p10 === 1'b0 && p1 === 1'b1 && p12 === 1'b1);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [4:0] rom [0:511];
    logic [4:0] data;
    initial begin
        if (ROM_FILE != "") $readmemh(ROM_FILE, rom);
    end
    assign data = rom[{p22,p21,p20,p19,p18,p17,p16,p15,p14}];
    assign #(T_PD) p4 = powered ? (p11 ? 1'bz : data[0]) : 1'bx;
    assign #(T_PD) p5 = powered ? (p11 ? 1'bz : data[1]) : 1'bx;
    assign #(T_PD) p6 = powered ? (p11 ? 1'bz : data[2]) : 1'bx;
    assign #(T_PD) p7 = powered ? (p11 ? 1'bz : data[3]) : 1'bx;
    assign #(T_PD) p8 = powered ? (p11 ? 1'bz : data[4]) : 1'bx;

endmodule
`default_nettype wire
