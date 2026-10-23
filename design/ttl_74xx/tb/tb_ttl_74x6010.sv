`timescale 1ns/1ps
module tb_ttl_74x6010;
    logic vin;
    logic vo_drive_low;
    logic expected_drive_low;

    ttl_74x6010 dut (.*);

    initial begin
        for (int value = 0; value < 2; value++) begin
            vin = 1'(value);
            // Non-inverting logical output; a zero is produced by sinking.
            expected_drive_low = ~1'(value);
            #1;
            if (vo_drive_low !== expected_drive_low)
                $fatal(1, "VIN=%0b expected sink=%0b, got %0b",
                       vin, expected_drive_low, vo_drive_low);
        end
        $display("PASS: tb_ttl_74x6010");
        $finish;
    end
endmodule
