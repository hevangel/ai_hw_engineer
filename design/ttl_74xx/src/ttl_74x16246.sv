// ASSUMPTION: externally resolved powered logic; analog keepers/precharge omitted.
module ttl_74x16246 (
    input logic oe_n,
    input logic oe_11_n,
    input logic [2:0] dir,
    input logic [10:0] a_in,
    input logic [7:0] bi_in,
    input logic [2:0] b_in,
    output logic [10:0] a_out,
    output logic [10:0] a_drive,
    output logic [10:0] b_out,
    output logic [10:0] b_drive
);
    always_comb begin
        a_out = '0;
        a_drive = '0;
        b_out = '0;
        b_drive = '0;
        if (!oe_n) begin
            a_drive[7:0] = ~bi_in;
            b_drive[7:0] = '1;
            b_out[7:0] = a_in[7:0];
            for (int channel = 0; channel < 3; channel++) begin
                if (dir[channel]) begin
                    a_drive[channel+8] = 1'b1;
                    a_out[channel+8] = b_in[channel];
                end else if (channel != 2 || !oe_11_n) begin
                    b_drive[channel+8] = 1'b1;
                    b_out[channel+8] = a_in[channel+8];
                end
            end
        end
    end
endmodule
