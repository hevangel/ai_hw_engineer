`timescale 1ns/1ps
module tb_ttl_74x162344;
    logic [7:0] a;
    logic [3:0] oe_n;
    logic [31:0] b, drive;
    logic expected_drive;
    logic expected_data;
    ttl_74x162344 dut(.*);
    initial begin
        for (int oe_pattern = 0; oe_pattern < 16; oe_pattern++) begin
            oe_n = 4'(oe_pattern);
            for (int data_pattern = 0; data_pattern < 256; data_pattern++) begin
                a = 8'(data_pattern);
                #1;
                for (int address_index = 0; address_index < 8; address_index++) begin
                    for (int copy_index = 0; copy_index < 4; copy_index++) begin
                        int output_index;
                        int oe_index;
                        output_index = address_index * 4 + copy_index;
                        oe_index = address_index / 2;
                        expected_drive = !oe_n[oe_index];
                        expected_data = expected_drive && a[address_index];
                        if (drive[output_index] !== expected_drive || b[output_index] !== expected_data)
                            $fatal(1, "output %0d mismatch for OE=%h A=%h", output_index, oe_n, a);
                    end
                end
            end
        end
        $display("PASS: tb_ttl_74x162344");
        $display("PASS: tb_ttl_74x162344");
        $finish;
    end
endmodule
