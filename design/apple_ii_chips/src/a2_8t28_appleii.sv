// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_8t28_appleii #(parameter integer T_PD = 0) (
    input tri p1, // RecEna
    output tri p2, // A_Out
    inout tri p3, // BusA
    input tri p4, // DriverIn_A
    output tri p5, // B_Out
    inout tri p6, // BusB
    input tri p7, // DriverIn_B
    input tri p8, // GND
    input tri p9, // DriverIn_C
    inout tri p10, // BusC
    output tri p11, // C_Out
    input tri p12, // DriverIn_D
    inout tri p13, // BusD
    output tri p14, // D_Out
    input tri p15, // Driver_Ena
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p3 = powered ? (p15 ? p4 : 1'bz) : 1'bx;
    assign #(T_PD) p2 = powered ? (p1 ? 1'bz : p3) : 1'bx;
    assign #(T_PD) p6 = powered ? (p15 ? p7 : 1'bz) : 1'bx;
    assign #(T_PD) p5 = powered ? (p1 ? 1'bz : p6) : 1'bx;
    assign #(T_PD) p10 = powered ? (p15 ? p9 : 1'bz) : 1'bx;
    assign #(T_PD) p11 = powered ? (p1 ? 1'bz : p10) : 1'bx;
    assign #(T_PD) p13 = powered ? (p15 ? p12 : 1'bz) : 1'bx;
    assign #(T_PD) p14 = powered ? (p1 ? 1'bz : p13) : 1'bx;

endmodule
`default_nettype wire
