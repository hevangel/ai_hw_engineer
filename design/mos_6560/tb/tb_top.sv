`timescale 1ns/1ps
module tb_top;
    logic clk = 0;
    logic rst_n = 0;
    logic phi2_i = 0;
    logic rw_i = 1;
    logic [13:0] addr_i = 0;
    logic [7:0] data_i = 0;
    logic [8:0] raster_i = 0;
    logic [7:0] lightpen_x_i = 0, lightpen_y_i = 0;
    logic [7:0] pot_x_i = 0, pot_y_i = 0;
    logic [7:0] data_o;
    logic data_oe_o;
    logic [127:0] config_o;
    logic [7:0] expected [0:15];
    int checks = 0;
    mos_6560_regs dut (.*);

    task automatic check(input bit condition, input string message);
        checks++;
        if (!condition) $fatal(1, "%s addr=%h data=%h", message, addr_i, data_o);
    endtask

    task automatic access_bus(input logic [13:0] address,
                              input bit phase, input bit read_cycle,
                              input logic [7:0] value);
        logic select_chip;
        logic [7:0] read_value;
        addr_i = address;
        phi2_i = phase;
        rw_i = read_cycle;
        data_i = value;
        select_chip = (address >= 14'h1000 && address <= 14'h10ff);
        #1;
        check(data_oe_o === (rst_n && select_chip && phase && read_cycle), "drive enable");
        read_value = 0;
        if (rst_n && select_chip && phase && read_cycle) begin
            case (address[3:0])
                3: read_value = {raster_i[0], expected[3][6:0]};
                4: read_value = raster_i[8:1];
                6: read_value = lightpen_x_i;
                7: read_value = lightpen_y_i;
                8: read_value = pot_x_i;
                9: read_value = pot_y_i;
                default: read_value = expected[address[3:0]];
            endcase
        end
        check(data_o === read_value, "readback");
        clk = 1;
        if (!rst_n) begin
            for (int r = 0; r < 16; r++) expected[r] = 0;
        end else if (select_chip && phase && !read_cycle) begin
            case (address[3:0])
                3: expected[3] = value & 8'h7f;
                4,6,7,8,9: begin end
                default: expected[address[3:0]] = value;
            endcase
        end
        #1;
        for (int r = 0; r < 16; r++)
            check(config_o[8*r +: 8] === expected[r], "configuration/retention");
        clk = 0;
        #1;
    endtask

    initial begin
        for (int r = 0; r < 16; r++) expected[r] = 0;
        access_bus(14'h1000, 1, 0, 8'hff);
        rst_n = 1;
        // Exhaustive physical address decode, for all four bus qualifiers.
        for (int a = 0; a < 16384; a++) begin
            access_bus(14'(a), 0, 0, 8'ha5);
            access_bus(14'(a), 0, 1, 8'h5a);
            access_bus(14'(a), 1, 0, 8'ha5);
            access_bus(14'(a), 1, 1, 8'h5a);
        end
        // Every byte through every mirror and register; check all other storage.
        for (int m = 0; m < 16; m++) begin
            for (int r = 0; r < 16; r++) begin
                for (int v = 0; v < 256; v++) begin
                    raster_i = 9'(v*2 + (m & 1));
                    lightpen_x_i = 8'(v);
                    lightpen_y_i = ~8'(v);
                    pot_x_i = 8'(v ^ 8'h55);
                    pot_y_i = 8'(v ^ 8'haa);
                    access_bus(14'h1000 + 14'(m*16+r), 1, 0, 8'(v));
                    access_bus(14'h1000 + 14'(r), 1, 1, 0);
                end
            end
        end
        // All 512 raster values, changing external readbacks without writes.
        for (int v = 0; v < 512; v++) begin
            raster_i = 9'(v);
            access_bus(14'h10f3, 1, 1, 0);
            access_bus(14'h10f4, 1, 1, 0);
        end
        rst_n = 0;
        access_bus(14'h10ff, 1, 1, 8'hff);
        rst_n = 1;
        access_bus(14'h100f, 1, 1, 0);
        $display("MOS 6560 REGS PASS: %0d checks", checks);
        $finish;
    end
endmodule
