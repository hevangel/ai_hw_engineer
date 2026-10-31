// Source: TI SN54BCT2411/SN74BCT2411, printed p. 10-31.
// The output's physical 25-ohm series resistor is outside this digital model.
module ttl_74x2411 (
    input  logic [10:0] a,
    input  logic        g1_n,
    input  logic        g2_n,
    output logic [10:0] y,
    output logic [10:0] drive
);
    logic enabled;

    assign enabled = ~g1_n & ~g2_n;
    assign drive = {11{enabled}};
    assign y = ~a & {11{enabled}};
endmodule
