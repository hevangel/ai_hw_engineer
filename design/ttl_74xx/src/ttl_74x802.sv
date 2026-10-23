// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x802.md.
// ttl_74x802 - triple 4-input OR/NOR drivers.
module ttl_74x802 (
    input  logic [3:0] a0, a1, a2,
    output logic       y0,    y1,    y2,
    output logic       y0_n,  y1_n,  y2_n
);
    assign y0   =  |a0;  assign y0_n = ~|a0;
    assign y1   =  |a1;  assign y1_n = ~|a1;
    assign y2   =  |a2;  assign y2_n = ~|a2;
endmodule
