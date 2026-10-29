`timescale 1ns/1ps
module tb_ttl_74x6001;
    logic vin;
    logic vo;
    logic expected_vo;

    ttl_74x6001 dut (.*);

    initial begin
        for (int value = 0; value < 2; value++) begin
            vin = 1'(value);
            expected_vo = ~1'(value);
            #1;
            if (vo !== expected_vo)
                $fatal(1, "VIN=%0b expected VO=%0b, got %0b", vin, expected_vo, vo);
        end
        $display("PASS: tb_ttl_74x6001");
        $finish;
    end
endmodule
