`timescale 1ns/1ps
// One IBM FM/MFM word. Address mark selection: 0 normal, 1 A1, 2 C2, 3 FM mark.
module intel_8272_codec (
    input logic mfm, previous_data,
    input logic [7:0] data_in,
    input logic [1:0] mark,
    output logic [15:0] encoded,
    input logic [15:0] encoded_in,
    output logic [7:0] decoded,
    output logic next_data, missing_clock
);
    logic prior;
    logic [7:0] clocks;
    integer b;
    always_comb begin
        encoded=0; decoded=0; prior=previous_data; clocks=mark==3 ? 8'hc7 : 8'hff;
        for (b=7;b>=0;b=b-1) begin
            encoded[2*b+1]=mfm ? !(prior || data_in[b]) : clocks[b];
            encoded[2*b]=data_in[b];
            prior=data_in[b]; decoded[b]=encoded_in[2*b];
        end
        if (mfm && mark==1) encoded=16'h4489;
        if (mfm && mark==2) encoded=16'h5224;
        next_data=encoded[0];
        missing_clock=mfm ? (encoded_in==16'h4489 || encoded_in==16'h5224) :
            ({encoded_in[15],encoded_in[13],encoded_in[11],encoded_in[9],
              encoded_in[7],encoded_in[5],encoded_in[3],encoded_in[1]}!=8'hff);
    end
endmodule
