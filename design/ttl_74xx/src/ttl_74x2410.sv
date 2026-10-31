// Source: TI SN54BCT2410/SN74BCT2410, printed p. 10-30.
// The output's physical 25-ohm series resistor is outside this digital model.
module ttl_74x2410 (
    input  logic [10:0] a,
    input  logic        g1_n,
    input  logic        g2_n,
    output logic [10:0] y,
    output logic [10:0] drive
);
    logic enabled;

    assign enabled = ~g1_n & ~g2_n;
    assign drive = {11{enabled}};
    assign y = a & {11{enabled}};
endmodule
