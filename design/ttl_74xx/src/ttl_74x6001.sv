`timescale 1ns/1ps
// Fairchild 74OL6001 is the table-listed LSTTL-to-TTL inverting buffer.
// VIN is the data input; the LED and optical path are internal to the package.
module ttl_74x6001 (
    input  logic vin,
    output logic vo
);
    assign vo = ~vin;
endmodule
