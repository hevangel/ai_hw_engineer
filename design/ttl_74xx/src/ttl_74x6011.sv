`timescale 1ns/1ps
// Fairchild 74OL6011 is an inverting open-collector CMOS-output optocoupler.
// The flag is high when the output transistor sinks; high logic is released.
module ttl_74x6011 (
    input  logic vin,
    output logic vo_drive_low
);
    assign vo_drive_low = vin;
endmodule
