`timescale 1ns / 1ps

module intel_8279_cover (
    input logic clk,
    input logic rst_n,
    input logic bd_n,
    input logic status_du
);
    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end else if (rst_n) begin
            cover (status_du && !bd_n);
        end
    end
endmodule
