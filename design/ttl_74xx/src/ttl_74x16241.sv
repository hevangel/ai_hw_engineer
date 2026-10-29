module ttl_74x16241 (
    input  logic [15:0] a_in,
    input  logic        oe1_n,
    input  logic        oe2,
    input  logic        oe3,
    input  logic        oe4_n,
    output logic [15:0] y_out,
    output logic [3:0]  y_drive
);
    always_comb begin
        y_drive = {~oe4_n, oe3, oe2, ~oe1_n};
        y_out = 16'h0000;
        if (y_drive[0]) y_out[3:0]   = a_in[3:0];
        if (y_drive[1]) y_out[7:4]   = a_in[7:4];
        if (y_drive[2]) y_out[11:8]  = a_in[11:8];
        if (y_drive[3]) y_out[15:12] = a_in[15:12];
    end
endmodule
