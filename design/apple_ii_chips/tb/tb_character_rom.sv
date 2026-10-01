`timescale 1ns/1ps
module tb_character_rom;
    logic [8:0] address=0;
    logic disabled=1;
    tri [4:0] data;
    a2_2513 dut(.p1(1'b1),.p4(data[0]),.p5(data[1]),.p6(data[2]),.p7(data[3]),.p8(data[4]),
        .p10(1'b0),.p11(disabled),.p12(1'b1),.p14(address[0]),.p15(address[1]),
        .p16(address[2]),.p17(address[3]),.p18(address[4]),.p19(address[5]),
        .p20(address[6]),.p21(address[7]),.p22(address[8]),.p24(1'b1));
    initial begin
        for(int i=0;i<512;i++) dut.rom[i]=5'(i^(i>>5));
        #1;
        if(data!==5'bz) $fatal(1,"disabled character ROM");
        disabled=0;
        for(int i=0;i<512;i++) begin
            address=9'(i); #1;
            if(data!==5'(i^(i>>5))) $fatal(1,"2513 physical address pins %0d",i);
        end
        $display("PASS character ROM row/character and output pins"); $finish;
    end
endmodule
