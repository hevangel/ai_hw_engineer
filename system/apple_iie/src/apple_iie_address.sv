`timescale 1ns/1ps
// Apple IIe TRM Table 7-9: inverse of the physical RA pin multiplexing.
module apple_iie_address (
    input logic [7:0] row_address, column_address,
    output logic [15:0] physical_address
);
    assign physical_address={column_address[7:2],column_address[0],
                             row_address[7:6],column_address[1],row_address[5:0]};
endmodule
