`timescale 1ns/1ps
module tb_rom;
    logic [10:0] address=0;
    logic enable=0;
    tri [7:0] data;
    a2_rom_chip dut(.p1(address[7]),.p2(address[6]),.p3(address[5]),.p4(address[4]),
        .p5(address[3]),.p6(address[2]),.p7(address[1]),.p8(address[0]),
        .p9(data[0]),.p10(data[1]),.p11(data[2]),.p12(1'b0),.p13(data[3]),
        .p14(data[4]),.p15(data[5]),.p16(data[6]),.p17(data[7]),.p18(enable),
        .p19(address[10]),.p20(1'b0),.p21(1'b0),.p22(address[9]),.p23(address[8]),.p24(1'b1));
    initial begin
        for(int i=0;i<2048;i++) dut.rom[i]=8'(i^(i>>8));
        #1;
        if(data!==8'bz) $fatal(1,"disabled ROM must release bus");
        enable=1;
        for(int i=0;i<2048;i++) begin
            address=11'(i); #1;
            if(data!==8'(i^(i>>8))) $fatal(1,"ROM physical address pins %0d",i);
        end
        $display("PASS ROM physical address/data pins and chip enable"); $finish;
    end
endmodule
