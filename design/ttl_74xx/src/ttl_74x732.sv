// SPDX-License-Identifier: MIT
// 74F732: quad 3-bus multiplexer, inverting, with explicit bus drive flags.
// Routing/control modes follow the Signetics FAST manual page n791 table.
module ttl_74x732 (
    input  logic       s0,
    input  logic       s1,
    input  logic       s2,
    input  logic       oe_a_n,
    input  logic       oe_b_n,
    input  logic       oe_c_n,
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic [3:0] c,
    output logic [3:0] a_out,
    output logic [3:0] b_out,
    output logic [3:0] c_out,
    output logic       a_drive,
    output logic       b_drive,
    output logic       c_drive
);
    always_comb begin
        a_out = 4'b0000;
        b_out = 4'b0000;
        c_out = 4'b0000;
        a_drive = 1'b0;
        b_drive = 1'b0;
        c_drive = 1'b0;

        // The select tuple order is S0,S1,S2, as printed in the table.
        case ({s0, s1, s2})
            3'b000: begin // A to C
                if (!oe_c_n) begin
                    c_out = ~a;
                    c_drive = 1'b1;
                end
            end
            3'b100: begin // C to A
                if (!oe_a_n) begin
                    a_out = ~c;
                    a_drive = 1'b1;
                end
            end
            3'b001: begin // B to C
                if (!oe_c_n) begin
                    c_out = ~b;
                    c_drive = 1'b1;
                end
            end
            3'b101: begin // C to B
                if (!oe_b_n) begin
                    b_out = ~c;
                    b_drive = 1'b1;
                end
            end
            3'b010: begin // A to B
                if (!oe_b_n) begin
                    b_out = ~a;
                    b_drive = 1'b1;
                end
            end
            3'b110: begin // B to A
                if (!oe_a_n) begin
                    a_out = ~b;
                    a_drive = 1'b1;
                end
            end
            3'b011, 3'b111: begin // A to B and C; S0 is don't-care
                if (!oe_b_n) begin
                    b_out = ~a;
                    b_drive = 1'b1;
                end
                if (!oe_c_n) begin
                    c_out = ~a;
                    c_drive = 1'b1;
                end
            end
            default: begin
                // All 3-bit S0/S1/S2 combinations are covered above.
            end
        endcase
    end
endmodule
