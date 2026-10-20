`timescale 1ns/1ps
module tb_irq;
    logic clk=0, rst_n=0, read_i=0, write_i=0;
    logic [7:0] data_i=0, data_o;
    logic [4:0] source_i=0;
    logic irq_n;
    int checks=0;
    logic enabled;
    mos_6526_irq dut (.*);
    task automatic tick;
        #1; clk=1; #1; clk=0; #1;
    endtask
    task automatic require_check(input logic condition,input string message);
        if(condition !== 1) $fatal(1,"%s ICR=%02x IRQN=%b",message,data_o,irq_n);
        checks++;
    endtask
    task automatic reset_chip;
        rst_n=0; read_i=0; write_i=0; source_i=0; tick(); rst_n=1;
        require_check(data_o==0 && irq_n,"IRQ reset");
    endtask
    task automatic put(input logic [7:0] value);
        write_i=1; data_i=value; tick(); write_i=0;
    endtask
    initial begin
        for(int mask=0;mask<32;mask++) begin
            for(int flags=0;flags<32;flags++) begin
                reset_chip(); put(8'h80|8'(mask));
                source_i=5'(flags); tick(); source_i=0;
                enabled=|(5'(mask)&5'(flags));
                require_check(data_o==8'(flags) && irq_n,"Source flags precede legacy D7/pin");
                tick();
                require_check(data_o=={enabled,2'b00,5'(flags)} && irq_n==!enabled,"All mask/source combinations");
                put(8'h7f);
                require_check(irq_n==!enabled,"Mask clear cannot cancel active interrupt");
                read_i=1; #1;
                require_check(irq_n && data_o=={enabled,2'b00,5'(flags)},"ICR read immediately releases pin, retains read value");
                tick(); read_i=0; #1;
                require_check(data_o=={enabled,7'b0} && irq_n,"Pending bits clear before delayed D7");
                tick(); require_check(data_o==0 && irq_n,"Delayed acknowledge clears D7");
            end
        end
        reset_chip(); source_i=5'h1f; tick(); source_i=0;
        put(8'h81); require_check(data_o==8'h1f && irq_n,"Enabling pending source schedules future interrupt");
        tick(); require_check(data_o==8'h9f && !irq_n,"Pending enable reaches D7/pin");
        put(0); require_check(!irq_n,"Zero mask write leaves mask unchanged");
        reset_chip(); put(8'h90); read_i=1; source_i=5'h10; tick(); read_i=0; source_i=0;
        require_check(data_o==8'h10 && irq_n,"Fresh event survives coincident ICR read");
        tick(); require_check(data_o==8'h90 && !irq_n,"New request wins delayed D7 acknowledge");
        $display("MOS 6526 IRQ PASS: 1024 mask/source combinations, %0d checks; pending/latency/read races",checks);
        $finish;
    end
endmodule
