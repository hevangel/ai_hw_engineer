`timescale 1ns/1ps
module tb_top;
    logic clk = 0, rst_n = 0, rdy_i = 1;
    logic [12:0] bus_addr;
    logic [15:0] debug_bus_addr_o, pc_o;
    logic [7:0] bus_data_i, bus_data_o, status_o, a_o, x_o, y_o, s_o;
    logic bus_we, fetch_o, fault_o, jammed_o;
    logic [7:0] ram [0:8191];
    int checks = 0;
    mos_6507 dut (.*);
    assign bus_data_i = ram[bus_addr];
    always_ff @(posedge clk) if (rst_n && bus_we) ram[bus_addr] <= bus_data_o;

    task automatic tick;
        #1; clk = 1; #1; clk = 0; #1;
    endtask
    task automatic transfer(input logic [15:0] address,
                            input logic write_cycle = 0,
                            input logic [7:0] value = 0,
                            input logic opcode_fetch = 0);
        #1;
        if (debug_bus_addr_o !== address || bus_addr !== address[12:0] ||
            bus_we !== write_cycle || fetch_o !== opcode_fetch || fault_o || jammed_o)
            $fatal(1,"6507 bus mismatch expected=%04x/%b/%b actual=%04x/%b/%b PC=%04x",
                   address, write_cycle, opcode_fetch, debug_bus_addr_o, bus_we, fetch_o, pc_o);
        if (opcode_fetch && (pc_o !== address || bus_data_i !== value))
            $fatal(1,"6507 exact PC/next-opcode mismatch P=%02x X=%02x Y=%02x",status_o,x_o,y_o);
        if (write_cycle && bus_data_o !== value) $fatal(1,"6507 write data mismatch");
        checks++;
        tick();
    endtask
    initial begin
        foreach (ram[i]) ram[i] = 8'hea;
        ram['h1ffc] = 0; ram['h1ffd] = 8'he0;
        ram['h1ffe] = 0; ram['h1fff] = 8'h60;
        // Original logical addressing is retained; only the package aliases.
        ram[0]=8'ha2; ram[1]=8'hfd; ram[2]=8'h9a;
        ram[3]=8'h18; ram[4]=8'hd8; ram[5]=8'hb8; // CLC/CLD/CLV
        ram[6]=8'ha9; ram[7]=8'h5a;
        ram[8]=8'h8d; ram[9]=8'h23; ram[10]=8'h21;
        ram[11]=8'ha2; ram[12]=1;
        ram[13]=8'hbd; ram[14]=8'hff; ram[15]=8'h3f;
        ram[16]=0; ram[17]=8'hea;
        tick(); tick(); rst_n = 1;
        repeat (5) tick(); // Undefined power-on PC/SP dummy reads, not instructions.
        transfer(16'hfffc); transfer(16'hfffd);
        transfer(16'he000,0,8'ha2,1); transfer(16'he001);
        transfer(16'he002,0,8'h9a,1); transfer(16'he003);
        if (s_o !== 8'hfd) $fatal(1,"6507 TXS exact result");
        transfer(16'he003,0,8'h18,1); transfer(16'he004);
        transfer(16'he004,0,8'hd8,1); transfer(16'he005);
        transfer(16'he005,0,8'hb8,1); transfer(16'he006);
        rdy_i = 0;
        repeat (3) transfer(16'he006,0,8'ha9,1);
        rdy_i = 1;
        transfer(16'he006,0,8'ha9,1); transfer(16'he007);
        transfer(16'he008,0,8'h8d,1); transfer(16'he009); transfer(16'he00a);
        rdy_i = 0; transfer(16'h2123,1,8'h5a); rdy_i = 1;
        if (ram['h123] !== 8'h5a) $fatal(1,"6507 write alias/RDY");
        transfer(16'he00b,0,8'ha2,1); transfer(16'he00c);
        transfer(16'he00d,0,8'hbd,1); transfer(16'he00e); transfer(16'he00f);
        transfer(16'h3f00); transfer(16'h4000);
        if (a_o !== 8'ha2) $fatal(1,"6507 indexed address crosses physical wrap");
        transfer(16'he010,0,0,1); transfer(16'he011);
        transfer(16'h01fd,1,8'he0); transfer(16'h01fc,1,8'h12);
        transfer(16'h01fb,1,8'hb4); transfer(16'hfffe); transfer(16'hffff);
        if (pc_o !== 16'h6000 || !fetch_o) $fatal(1,"6507 BRK exact vector PC");
        // Change external memory at this known fetch boundary to exercise the
        // architectural FFFF->0000 wrap; no filler can absorb a wrong landing.
        ram[0]=8'h4c; ram[1]=8'hfe; ram[2]=8'hff;
        ram['h1ffe]=8'hea; ram['h1fff]=8'hea;
        transfer(16'h6000,0,8'h4c,1); transfer(16'h6001); transfer(16'h6002);
        transfer(16'hfffe,0,8'hea,1); transfer(16'hffff);
        transfer(16'hffff,0,8'hea,1); transfer(16'h0000);
        transfer(16'h0000,0,8'h4c,1); transfer(16'h0001); transfer(16'h0002);
        if (!fetch_o || pc_o !== 16'hfffe || bus_addr !== 13'h1ffe)
            $fatal(1,"6507 final exact next instruction");
        $display("MOS 6507 PASS: %0d exact bus checks; reset/aliases/RDY/BRK/PC wrap",checks);
        $finish;
    end
endmodule
