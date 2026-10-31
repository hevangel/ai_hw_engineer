`timescale 1ns/1ps
module tb_ttl_74x1284;
    logic dir, hd;
    logic [3:0] a_bus_in, b_bus_in;
    logic [2:0] a_aux_in;
    logic [3:0] a_bus_out, b_bus_out;
    logic [2:0] y_aux_out;
    logic [3:0] a_bus_drive, b_bus_drive;
    logic [2:0] y_aux_drive;
    logic [3:0] expected_a_out, expected_b_out;
    logic [2:0] expected_y_out;
    logic [3:0] expected_a_drive, expected_b_drive;
    logic [2:0] expected_y_drive;
    ttl_74x1284 dut(.*);

    initial begin
        for (int dir_value = 0; dir_value < 2; dir_value++) begin
            for (int hd_value = 0; hd_value < 2; hd_value++) begin
                for (int a_value = 0; a_value < 16; a_value++) begin
                    for (int b_value = 0; b_value < 16; b_value++) begin
                        for (int aux_value = 0; aux_value < 8; aux_value++) begin
                            dir = 1'(dir_value);
                            hd = 1'(hd_value);
                            a_bus_in = 4'(a_value);
                            b_bus_in = 4'(b_value);
                            a_aux_in = 3'(aux_value);
                            #1;

                            expected_a_out = 4'b0000;
                            expected_b_out = 4'b0000;
                            expected_y_out = 3'b000;
                            expected_a_drive = 4'b0000;
                            expected_b_drive = 4'b0000;
                            expected_y_drive = 3'b000;
                            if (dir_value == 0) begin
                                expected_a_out = b_bus_in;
                                expected_a_drive = 4'b1111;
                            end else if (hd_value == 1) begin
                                expected_b_out = a_bus_in;
                                expected_b_drive = 4'b1111;
                            end else begin
                                expected_b_drive = ~a_bus_in;
                            end
                            if (hd_value == 1) begin
                                expected_y_out = a_aux_in;
                                expected_y_drive = 3'b111;
                            end else begin
                                expected_y_drive = ~a_aux_in;
                            end

                            if (a_bus_out !== expected_a_out ||
                                b_bus_out !== expected_b_out ||
                                y_aux_out !== expected_y_out ||
                                a_bus_drive !== expected_a_drive ||
                                b_bus_drive !== expected_b_drive ||
                                y_aux_drive !== expected_y_drive) begin
                                $fatal(1, "DIR=%0d HD=%0d A=%h B=%h A5-7=%h",
                                       dir_value, hd_value, a_bus_in, b_bus_in, a_aux_in);
                            end
                        end
                    end
                end
            end
        end
        $display("PASS: tb_ttl_74x1284");
        $finish;
    end
endmodule
