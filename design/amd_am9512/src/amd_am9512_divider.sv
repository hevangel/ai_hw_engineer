`timescale 1ns/1ps
// Restoring divider used by the Am9512 floating-point unit.  One quotient bit
// is produced per clock.  The numerator is pre-shifted by the caller so the
// quotient carries the guard, round and sticky bits needed for rounding.
module amd_am9512_divider #(
    parameter int DIV_QW = 28,
    parameter int DIV_DW = 24,
    parameter int DIV_NW = 52
) (
    input  logic clk_i,
    input  logic reset_i,
    input  logic start_i,
    input  logic [DIV_NW-1:0] numerator_i,
    input  logic [DIV_DW-1:0] denominator_i,
    output logic busy_o,
    output logic done_o,
    output logic [DIV_QW-1:0] quotient_o,
    output logic [DIV_DW-1:0] remainder_o
);
    localparam int REM_W = DIV_DW + 1;

    logic [DIV_NW-1:0] numerator_q;
    logic [DIV_DW-1:0] denominator_q;
    logic [DIV_QW-1:0] quotient_q;
    logic [DIV_DW-1:0] remainder_q;
    integer bit_index;
    logic [REM_W-1:0] shifted;
    logic [REM_W-1:0] diff;

    always_comb begin
        shifted = {remainder_q, numerator_q[bit_index]};
        diff = shifted - {1'b0, denominator_q};
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            busy_o <= 1'b0;
            done_o <= 1'b0;
            numerator_q <= {DIV_NW{1'b0}};
            denominator_q <= {DIV_DW{1'b0}};
            quotient_q <= {DIV_QW{1'b0}};
            remainder_q <= {DIV_DW{1'b0}};
            bit_index <= 0;
        end else begin
            done_o <= 1'b0;
            if (start_i && !busy_o) begin
                numerator_q <= numerator_i;
                denominator_q <= denominator_i;
                quotient_q <= {DIV_QW{1'b0}};
                remainder_q <= {DIV_DW{1'b0}};
                bit_index <= DIV_QW - 1;
                busy_o <= 1'b1;
            end else if (busy_o) begin
                if (!diff[REM_W-1]) begin
                    remainder_q <= diff[DIV_DW-1:0];
                    quotient_q[bit_index] <= 1'b1;
                end else begin
                    remainder_q <= shifted[DIV_DW-1:0];
                end
                if (bit_index == 0) begin
                    busy_o <= 1'b0;
                    done_o <= 1'b1;
                end else begin
                    bit_index <= bit_index - 1;
                end
            end
        end
    end

    assign quotient_o = quotient_q;
    assign remainder_o = remainder_q;
endmodule
