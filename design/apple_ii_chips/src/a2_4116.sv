// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_4116 #(parameter integer T_PD = 0) (
    input tri p1, // VBB
    input tri p2, // DI
    input tri p3, // R~{W}
    input tri p4, // ~{RAS}
    input tri p5, // A5
    input tri p6, // A4
    input tri p7, // A3
    input tri p8, // VDD
    input tri p9, // VCC
    input tri p10, // A0
    input tri p11, // A1
    input tri p12, // A2
    input tri p13, // A6
    output tri p14, // D0
    input tri p15, // ~{CAS}
    input tri p16 // GND
);
    logic powered;
    assign powered = (p9 === 1'b1 && p16 === 1'b0 && p1 === 1'b1 && p8 === 1'b1);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    // ASSUMPTION: ideal retention; no decay, power sequencing, or analog timing.
    logic memory [0:16383];
    logic [6:0] row, column;
    logic [6:0] address;
    logic cas_active, read_cycle, data_out;
    assign address = {p13,p5,p6,p7,p12,p11,p10};
    always_ff @(negedge p4) row <= address;
    // Capture once per CAS cycle; a later WE edge is a read-modify-write.
    // This event model is deliberately not advertised as synthesizable RAM.
    always_ff @(negedge p15 or posedge p15 or negedge p3) begin
        if (p15) begin
            cas_active <= 0;
            read_cycle <= 0;
        end else if (!p4 && powered) begin
            if (!cas_active) begin
                column <= address;
                read_cycle <= p3;
                data_out <= memory[{row,address}];
                if (!p3) memory[{row,address}] <= p2;
            end else if (!p3) memory[{row,column}] <= p2;
            cas_active <= 1;
        end
    end
    assign #(T_PD) p14 = powered ? ((!p15 & read_cycle) ? data_out : 1'bz) : 1'bx;

endmodule
`default_nettype wire
