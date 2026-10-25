`timescale 1ns/1ps
// Fairchild 74OL6010 is a non-inverting open-collector CMOS-output optocoupler.
// The flag is high when the output transistor sinks; high logic is released.
module ttl_74x6010 (
    input  logic vin,
    output logic vo_drive_low
);
    assign vo_drive_low = ~vin;
endmodule
