// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x402.md.
// ttl_74x402 - Serial-data polynomial generator/checker (same as 74x401).
module ttl_74x402 #(parameter [15:0] POLY = 16'h8005)
(
    input  logic        clk,
    input  logic        clr_n,
    input  logic        din,
    output logic [15:0] crc
);
    logic feedback;
    assign feedback = crc[15] ^ din;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) crc <= 16'h0000;
        else begin
            crc <= {crc[14:0], 1'b0};
            if (feedback) crc <= ({crc[14:0], 1'b0}) ^ POLY;
        end
    end
endmodule
