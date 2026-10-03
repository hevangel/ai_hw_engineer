`timescale 1ns/1ps
// IBM floppy CRC: non-reflected CCITT, polynomial 1021, initial FFFF.
module intel_8272_crc (
    input logic clk, rst_n, clear, byte_valid,
    input logic [7:0] data,
    output logic [15:0] crc
);
    logic [15:0] next_crc;
    integer b;
    always_comb begin
        next_crc=crc ^ {data,8'd0};
        for (b=0;b<8;b=b+1)
            next_crc=next_crc[15] ? (next_crc<<1)^16'h1021 : next_crc<<1;
    end
    always_ff @(posedge clk) begin
        if (!rst_n || clear) crc<=16'hffff;
        else if (byte_valid) crc<=next_crc;
    end
endmodule
