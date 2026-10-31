`timescale 1ns/1ps
// Fairchild 74OL6000 is the table-listed LSTTL-to-TTL non-inverting buffer.
// VIN is the data input; the LED and optical path are internal to the package.
module ttl_74x6000 (
    input  logic vin,
    output logic vo
);
    assign vo = vin;
endmodule
