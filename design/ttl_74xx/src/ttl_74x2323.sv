// ASSUMPTION: line inputs are valid digital levels relative to VREF.
module ttl_74x2323 (
    input logic [1:0] line,
    input logic strobe,
    output logic [1:0] out
);
    assign out=~(line | {2{strobe}});
endmodule
