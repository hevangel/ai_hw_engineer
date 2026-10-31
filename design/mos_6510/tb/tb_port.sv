`timescale 1ns/1ps
module tb_port;
    localparam int FALLOFF = 350000;
    logic clk=0, rst_n=0, write_i=0, address_i=0;
    logic [7:0] data_i=0, data_o, ddr_o, latch_o;
    logic [5:0] port_i=0, port_o, port_oe;
    int checks=0, directions=256, values=256;
    mos_6510_port dut (.*);
    task automatic tick;
        #1; clk=1; #1; clk=0; #1;
    endtask
    task automatic put(input logic address, input logic [7:0] value);
        address_i=address; data_i=value; write_i=1; tick(); write_i=0;
    endtask
    initial begin
        if ($test$plusargs("quick")) begin directions=16; values=16; end
        tick(); rst_n=1;
        if (ddr_o !== 0 || latch_o !== 0 || port_oe !== 0) $fatal(1,"6510 port reset profile");
        for (int direction=0;direction<directions;direction++) begin
            for (int value=0;value<values;value++) begin
                put(0,8'(direction)); put(1,8'(value));
                address_i=0; #1;
                if (data_o !== 8'(direction)) $fatal(1,"6510 all-eight-bit DDR readback");
                address_i=1;
                for (int pins=0;pins<64;pins++) begin
                    port_i=6'(pins); #1;
                    if (data_o[5:0] !== ((6'(value)&6'(direction)) | (6'(pins)&~6'(direction))) ||
                        port_o !== 6'(value) || port_oe !== 6'(direction) || latch_o !== 8'(value))
                        $fatal(1,"6510 port truth table DDR=%02x data=%02x pins=%02x",direction,value,pins);
                    checks++;
                end
            end
        end
        // Charge each unbonded bit independently. No clock runs inside the
        // combinational sweep above; the decay duration is checked here.
        for (int bit_number=6;bit_number<8;bit_number++) begin
            rst_n=0; tick(); rst_n=1;
            put(0,8'(1<<bit_number)); put(1,8'(1<<bit_number));
            put(0,0); address_i=1; #1;
            if (!data_o[bit_number]) $fatal(1,"6510 unbonded charge retained on release");
            repeat(FALLOFF-1) begin tick(); if (!data_o[bit_number]) $fatal(1,"6510 charge decayed early"); end
            tick(); if (data_o[bit_number]) $fatal(1,"6510 charge failed exact sampled decay");
            // Writing an input latch must not recharge the unbonded pin.
            put(1,8'hc0); #1;
            if (data_o[7:6] !== 0) $fatal(1,"6510 input latch write spuriously charged pin");
        end
        $display("MOS 6510 PORT PASS: %0d physical-pin combinations; DDR/latch/reset/charge/decay",checks);
        $finish;
    end
endmodule
