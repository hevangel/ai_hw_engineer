// ASSUMPTION: externally resolved powered logic with settled controls; ERC
// analog edge-rate control and VREF are omitted. The B port is open-drain GTLP:
// b_drive masks indicate which pins are actively sunk low.
module ttl_74x16945 (
    input  logic [15:0] a_in,
    input  logic [15:0] b_in,
    input  logic        oe1,
    input  logic        dir1,
    input  logic        oe2,
    input  logic        dir2,
    output logic [15:0] a_out,
    output logic [15:0] a_drive,
    output logic [15:0] b_drive
);
    always_comb begin
        a_out = '0;
        a_drive = '0;
        b_drive = '0;
        if (!oe1) begin
            if (dir1)
                b_drive[7:0] = ~a_in[7:0];
            else begin
                a_drive[7:0] = '1;
                a_out[7:0] = b_in[7:0];
            end
        end
        if (!oe2) begin
            if (dir2)
                b_drive[15:8] = ~a_in[15:8];
            else begin
                a_drive[15:8] = '1;
                a_out[15:8] = b_in[15:8];
            end
        end
    end
endmodule
