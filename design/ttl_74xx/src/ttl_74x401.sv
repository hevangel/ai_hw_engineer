// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x401.md.
// ttl_74x401 - CRC generator/checker.
// Implements a generic CRC-16 LFSR (polynomial 0x8005, CRC-16-IBM).
// For RTL, we provide a parameterized CRC-16 engine with serial input.
module ttl_74x401 #(parameter [15:0] POLY = 16'h8005)
(
    input  logic       clk,
    input  logic       clr_n,
    input  logic       din,
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
