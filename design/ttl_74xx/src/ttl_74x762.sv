// SPDX-License-Identifier: MIT
// SN74AS762: two independently enabled groups of four open-collector drivers.
// TI 1984 TTL Data Book Vol. 3, printed p. 2-501, logic-symbol scan.
module ttl_74x762 (
    input  logic       g1_n,
    input  logic       g2_n,
    input  logic [3:0] a1,
    input  logic [3:0] a2,
    output logic [3:0] y1,
    output logic [3:0] y2,
    output logic       y1_drive,
    output logic       y2_drive
);
    always_comb begin
        y1 = 4'b0000;
        y2 = 4'b0000;
        y1_drive = 1'b0;
        y2_drive = 1'b0;

        if (!g1_n) begin
            y1 = ~a1;
            y1_drive = 1'b1;
        end
        if (!g2_n) begin
            y2 = a2;
            y2_drive = 1'b1;
        end
    end
endmodule
