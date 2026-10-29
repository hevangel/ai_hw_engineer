`timescale 1ns/1ps
module tb_ttl_74x2014;
    logic dir;
    logic [3:0] a_bus_in;
    logic [3:0] b_bus_in;
    logic [3:0] a_output_enable;
    logic [3:0] a_output_data;
    logic [3:0] b_output_enable;
    logic [3:0] b_drive_low;
    logic [3:0] expected_data;
    int a_code;
    int b_code;
    int dir_code;

    ttl_74x2014 dut (.*);

    initial begin
        for (dir_code = 0; dir_code < 2; dir_code = dir_code + 1) begin
            dir = dir_code[0];
            for (a_code = 0; a_code < 16; a_code = a_code + 1) begin
                a_bus_in = a_code[3:0];
                for (b_code = 0; b_code < 16; b_code = b_code + 1) begin
                    b_bus_in = b_code[3:0];
                    #1;
                    if (dir) begin
                        expected_data = 4'b0000;
                        if (a_output_enable !== 4'b0000
                            || a_output_data !== expected_data
                            || b_output_enable !== 4'b1111
                            || b_drive_low !== ~a_bus_in)
                            $fatal(1, "LVTTL-to-GTL direction mismatch a=%0d b=%0d", a_code, b_code);
                    end else begin
                        expected_data = b_bus_in;
                        if (a_output_enable !== 4'b1111
                            || a_output_data !== expected_data
                            || b_output_enable !== 4'b0000
                            || b_drive_low !== 4'b0000)
                            $fatal(1, "GTL-to-LVTTL direction mismatch a=%0d b=%0d", a_code, b_code);
                    end
                end
            end
        end
        $display("PASS: tb_ttl_74x2014 SN74GTL2014 all lane, bus, and direction combinations");
        $finish;
    end
endmodule
