// Intel 8279 Formal Safety Properties & Assertions
// Standard: IEEE 1800-2017 SystemVerilog

`timescale 1ns / 1ps

module intel_8279_props (
    input logic        clk,
    input logic        rst_n,
    input logic        cs_n,
    input logic        rd_n,
    input logic        wr_n,
    input logic        a0,
    input logic [7:0]  data_i,
    input logic [7:0]  data_o,
    input logic        data_oe,
    input logic        irq,
    input logic [3:0]  sl,
    input logic [7:0]  rl,
    input logic        shift,
    input logic        cntl_stb,
    input logic [3:0]  out_a,
    input logic [3:0]  out_b,
    input logic        bd_n,
    // Internal DUT signals
    input logic [3:0]  fifo_count,
    input logic [4:0]  prescaler_cnt,
    input logic [4:0]  prescaler_reload,
    input logic [3:0]  scan_cnt,
    input logic        status_overrun,
    input logic        status_underrun,
    input logic        status_du,
    input logic        status_se,
    input logic        special_error_mode,
    input logic        is_sensor_mode
);

    // Initial cycle assume reset
    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end else begin
            if (!$past(rst_n)) begin
                assert (fifo_count == 4'd0);
                assert (!status_overrun);
                assert (!status_underrun);
                assert (!status_du);
                assert (prescaler_reload == 5'd31);
            end else begin
                // Structural and protocol invariants after reset
                assert (data_oe == (~cs_n & ~rd_n & wr_n));
                assert (prescaler_cnt < prescaler_reload);
                assert (fifo_count <= 4'd8);
                assert (scan_cnt <= 4'd15);

                if (!is_sensor_mode) begin
                    assert (irq == ((fifo_count > 4'd0) ||
                                   (special_error_mode && status_se)));
                end

                if (status_du) begin
                    assert (bd_n == 1'b0);
                end
            end
        end
    end

endmodule
