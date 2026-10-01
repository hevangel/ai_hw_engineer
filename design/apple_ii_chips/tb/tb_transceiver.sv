`timescale 1ns/1ps
module tb_transceiver;
    tri cpu, system_data;
    logic direction=1;
    logic cpu_enable=0, system_enable=0;
    logic cpu_value=0, system_value=0;
    assign cpu = cpu_enable ? cpu_value : 1'bz;
    assign system_data = system_enable ? system_value : 1'bz;
    a2_8t28_appleii dut(.p1(direction),.p2(system_data),.p3(cpu),.p4(system_data),
        .p5(),.p6(),.p7(1'b0),.p8(1'b0),.p9(1'b0),.p10(),.p11(),
        .p12(1'b0),.p13(),.p14(),.p15(direction),.p16(1'b1));
    initial begin
        #1; direction=0; cpu_enable=1; cpu_value=1; #1;
        if(cpu !== 1 || system_data !== 1) $fatal(1,"CPU write %b/%b",cpu,system_data);
        cpu_value=0; #1;
        if(system_data !== 0) $fatal(1,"CPU data change");
        cpu_enable=0; direction=1; system_enable=1; system_value=1; #1;
        if(cpu !== 1 || system_data !== 1) $fatal(1,"CPU read %b/%b",cpu,system_data);
        system_enable=0; #1;
        if(cpu !== 1'bz || system_data !== 1'bz) $fatal(1,"bus release");
        $display("PASS transceiver read/write/release"); $finish;
    end
endmodule
