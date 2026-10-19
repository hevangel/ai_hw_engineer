`timescale 1ns/1ps
module tb_firmware;
    logic clk14=0,power_n=0,rst_n=0,key_down=0;
    logic [6:0] key_data=0;
    wire bus_clk,we,fetch,fault;
    wire [15:0] address,pc;
    wire [7:0] data,debug_data;
    logic [15:0] debug_address=16'h0000;
    logic [7:0] reference_rom[0:16383];
    int cycles=0,fetches=0;
    bit vector_low=0,vector_high=0,first_fetch=0;
    apple_iie dut(.clk14(clk14),.power_n(power_n),.rst_n(rst_n),.key_data(key_data),.key_down(key_down),
        .external_addr(16'd0),.external_data(8'd0),.external_we(1'b0),.debug_addr(debug_address),.debug_aux(1'b0),
        .debug_data(debug_data),.bus_clk(bus_clk),.bus_addr(address),.pc(pc),.bus_data(data),.bus_we(we),.fetch(fetch),.fault(fault));
    task automatic tick(output bit edge_seen,output logic [15:0] old_a,output bit old_we);
        bit previous,old_fetch;logic[7:0] old_data;
        previous=bus_clk;old_a=address;old_we=we;old_fetch=fetch;old_data=data;
        #5;clk14=1;#1;edge_seen=rst_n&&!previous&&bus_clk;
        if(rst_n&&fault)$fatal(1,"Original IIe ROM fault PC=%h",pc);
        if(edge_seen)begin
            cycles++;
            if(!old_we&&old_a==16'hfffc&&!first_fetch)begin
                if(old_data!==reference_rom[16380])$fatal(1,"Reset low");vector_low=1;
            end
            if(!old_we&&old_a==16'hfffd&&!first_fetch)begin
                if(old_data!==reference_rom[16381])$fatal(1,"Reset high");vector_high=1;
            end
            if(old_fetch)begin
                if($isunknown(old_data))$fatal(1,"Unknown firmware opcode");fetches++;
                if(!first_fetch)begin
                    if(!vector_low||!vector_high||old_a!=={reference_rom[16381],reference_rom[16380]})$fatal(1,"Exact first firmware fetch");first_fetch=1;
                end
            end
            if(cycles%20000==0)$display("IIE_ROM_PROGRESS cycles=%0d PC=%h keys=%h",cycles,pc,key_data);
        end
        #4;clk14=0;
    endtask
    initial begin
        bit edge_seen,old_we,held;logic[15:0] old_a;
        int index,age,cooldown;string command;
        $readmemh("work/rom.hex",reference_rom);
        repeat(8)tick(edge_seen,old_a,old_we);power_n=1;
        repeat(56)tick(edge_seen,old_a,old_we);rst_n=1;
        command="POKE 768,55\r";index=0;age=0;held=0;cooldown=0;
        while(cycles<500000)begin
            tick(edge_seen,old_a,old_we);
            if(edge_seen)begin
                if(held)begin
                    age++;
                    if(age>=5&&((!old_we&&old_a==16'hc010)||(old_we&&old_a>=16'hc010&&old_a<=16'hc01f)))begin
                        key_down=0;held=0;index++;cooldown=8;
                    end
                end else if(cooldown>0)cooldown--;
                else if(index<command.len()&&!old_we&&old_a==16'hc000)begin
                    key_data=7'(command[index]);key_down=1;held=1;age=0;
                end
                if(index==command.len()&&debug_address==16'h0300&&debug_data===8'd55)begin
                    if(!first_fetch)$fatal(1,"No reset/fetch evidence");
                    $display("PASS xezim original IIe ROM: exact reset/first fetch, keyboard POKE 768=55; cycles=%0d fetches=%0d",cycles,fetches);$finish;
                end
                // Explicit debug-read transactions: xezim may not refresh a
                // constant-address asynchronous RAM read after a write.
                if(index==command.len())debug_address=(debug_address==16'h0300)?16'h0301:16'h0300;
            end
        end
        $display("FINAL keys=%0d target=%h",index,debug_data);
        for(int row=0;row<24;row++)begin
            for(int col=0;col<40;col++)begin
                debug_address=16'(1024+(row%8)*128+(row/8)*40+col);#1;
                $write("%c",(debug_data&127)<32?((debug_data&127)+64):(debug_data&127));
            end
            $display("");
        end
        $fatal(1,"Original IIe ROM keyboard/POKE timeout PC=%h",pc);
    end
endmodule
