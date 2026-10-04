`timescale 1ns/1ps
module tb_dpll;
    logic clk=0;
    always #5 clk=~clk;
    intel_8273_if v(clk);
    intel_8273 dut (
        .clk(clk),.rst_n(v.rst_n),.cs_n(v.cs_n),.rd_n(v.rd_n),.wr_n(v.wr_n),
        .addr(v.addr),.data_i(v.data_i),.data_o(v.data_o),.data_oe(v.data_oe),
        .tx_dack_n(v.tx_dack_n),.rx_dack_n(v.rx_dack_n),.tx_drq(v.tx_drq),
        .rx_drq(v.rx_drq),.tx_int(v.tx_int),.rx_int(v.rx_int),.tx_tick(v.tx_tick),
        .rx_tick(v.dpll_tick),.tx_sample_tick(v.tx_sample_tick),.clk32_tick(v.clk32_tick),
        .rxd(v.rxd),.txd(v.txd),.dpll_tick(v.dpll_tick),.cts_n(v.cts_n),.cd_n(v.cd_n),
        .port_a(v.port_a),.port_b(v.port_b),.rts_n(v.rts_n),.flag_det_n(v.flag_det_n)
    );
    bit bits[0:199]; logic [7:0] body[0:10],value;
    int wire_len,body_len,bad_len,frames=0;
    task automatic source(input int offset,input int period);
        bit level=1;
        v.tick(offset+1);
        // NRZI preframe sync gives transitions for initial phase acquisition.
        repeat(16) begin level=!level; v.rxd=level; v.tick(period); end
        for(int i=0;i<wire_len;i++) begin
            if (!bits[i]) level=!level;
            v.rxd=level; v.tick(period);
        end
        v.tick(64);
    endtask
    task automatic sink;
        int got=0,timeout=0;
        while (!v.rx_int) begin
            if (v.rx_drq) begin
                v.data_get(value); v.check(value==body[got+2],"DPLL recovered data"); got++;
            end else v.tick();
            timeout++; if (timeout>20000) $fatal(1,"clock recovery timeout data=%0d",got);
        end
        v.check(got==9,"DPLL exact payload length");
        v.get(3,value); v.check(value==8'he0,$sformatf("DPLL recovered CRC code=%02x",value));
        v.get(3,value); v.check(value==9,"DPLL result count"); v.get(3,value); v.check(value==0,"DPLL high count");
        v.get(3,value); v.check(value==8'hff,"DPLL address"); v.get(3,value); v.check(value==8'h03,"DPLL control");
    endtask
    initial begin
        int fd,rc,temp;
        string filename;
        if (!$value$plusargs("vectors=%s",filename)) filename="design/intel_8273/references/frames.txt";
        fd=$fopen(filename,"r"); rc=$fscanf(fd,"%d %d %d",body_len,wire_len,bad_len);
        for(int i=0;i<body_len;i++) begin rc=$fscanf(fd,"%h",temp); body[i]=8'(temp); end
        for(int i=0;i<wire_len;i++) begin rc=$fscanf(fd,"%d",temp); bits[i]=1'(temp); end
        $fclose(fd);
        for(int period=31;period<=33;period++) for(int offset=0;offset<32;offset++) begin
            v.reset(); v.mask(8'h91,8'h24); v.mask(8'ha0,1); v.receive(9);
            v.clk32_tick=1;
            fork source(offset,period); sink(); join
            frames++;
        end
        $display("8273 DPLL PASSED frames=%0d checks=%0d",frames,v.checks); $finish;
    end
    initial begin #100000000; $fatal(1,"DPLL timeout"); end
endmodule
