`timescale 1ns/1ps
module tb_top;
    logic clk=0;
    always #5 clk=~clk;
    intel_8273_if v(clk);
    `include "dut.svh"
    logic [7:0] body[0:1023],received[0:1023];
    bit wire_bits[0:9999],bad_bits[0:9999];
    int body_len,wire_len,bad_len,got,seed=1,frames=0;
    int unsigned rng;
    logic [7:0] value;
    string vectors;
    function automatic int hold_cycles;
        rng=rng*32'd1664525+32'd1013904223;
        return 1+int'(rng%3);
    endfunction
    task automatic serial_rx(input bit b,input bit service=1,input bit nd=0);
        v.rxd=b; v.rx_tick=1; v.tick(); v.rx_tick=0; v.tick(2);
        if (service && (v.rx_drq || (nd && v.rx_int && dut.rx_count_q==0))) begin
            v.data_get(value,hold_cycles()); received[got]=value; got++;
        end
    endtask
    task automatic serial_tx;
        v.tx_tick=1; v.tick(); v.tx_tick=0; v.tick(2);
    endtask
    task automatic rx_result(input logic [7:0] code,input int n,input bit bufmode);
        v.check(v.rx_int,"Rx result IRQ");
        v.get(0,value); v.check(value[1],"Rx IRA");
        v.get(3,value,hold_cycles()); v.check(value==code,$sformatf("Rx code expected %02x got %02x",code,value));
        v.check(v.rx_int,"Rx IRQ persists through length");
        v.get(3,value); v.check(value==8'(n),"Rx length low");
        v.get(3,value); v.check(value==8'(n>>8),"Rx length high");
        if (bufmode) begin
            v.check(v.rx_int,"Rx IRQ persists through A/C");
            v.get(3,value); v.check(value==body[0],"Rx buffered address");
            v.get(3,value); v.check(value==body[1],"Rx buffered control");
        end
        v.check(!v.rx_int,"Rx result drain clears IRQ");
    endtask
    task automatic setup(input bit bufmode=1,nrzi=0,nd=0,input logic [7:0] extra=0);
        v.reset(); v.mask(8'h91,(bufmode?8'h24:8'h20)|extra);
        if (nrzi) v.mask(8'ha0,1);
        if (nd) v.mask(8'h97,1);
    endtask
    task automatic test_tx(input bit bufmode,nrzi,nd,input bit sync=0);
        int fed,first,target;
        bit line_level;
        setup(bufmode,nrzi,nd,sync ? 8'h02 : 8'h00);
        first=bufmode ? 2 : 0; target=body_len-first; fed=first;
        v.transmit(target,bufmode,body[0],body[1]);
        v.check(!v.rts_n,"RTS active during frame"); line_level=1;
        if (sync) for (int k=0;k<16;k++) begin
            bit b;
            b=nrzi ? 1'b0 : ((k%2)==0);
            line_level=nrzi ? (b?line_level:!line_level) : b;
            serial_tx(); v.check(v.txd==line_level,"preframe sync bit");
        end
        for (int i=0;i<wire_len;i++) begin
            if (fed<body_len && (v.tx_drq || (nd && v.tx_int))) begin
                v.data_put(body[fed],hold_cycles()); fed++;
            end
            line_level=nrzi ? (wire_bits[i]?line_level:!line_level) : wire_bits[i];
            serial_tx();
            v.check(v.txd==line_level,$sformatf("Tx independent bit %0d expected %b got %b",i,line_level,v.txd));
        end
        v.check(fed==body_len,"exact Tx host count");
        v.check(v.tx_int,"Tx completion IRQ"); v.get(2,value,hold_cycles());
        v.check(value==8'h0d,"Tx complete result");
        v.check(!v.tx_int && v.rts_n,"Tx IRQ clears and RTS releases"); frames++;
    endtask
    task automatic test_rx(input bit bufmode,nrzi,nd,input bit corrupt=0,
        input logic [7:0] opcode=8'hc0,input bit second_match=0,reject=0);
        bit line_level;
        int expected_count,total;
        setup(bufmode,nrzi,nd); got=0;
        v.receive(body_len+16,opcode,second_match||reject ? 8'h17 : body[0],
                  reject ? 8'h18 : body[0]);
        line_level=1; total=corrupt ? bad_len : wire_len;
        for (int i=0;i<total;i++) begin
            bit b;
            b=corrupt ? bad_bits[i] : wire_bits[i];
            line_level=nrzi ? (b?line_level:!line_level) : b;
            serial_rx(line_level,1,nd);
        end
        expected_count=reject ? 0 : body_len-(bufmode?2:0);
        v.check(got==expected_count,$sformatf("Rx count expected %0d got %0d",expected_count,got));
        for (int i=0;i<got;i++) v.check(received[i]==body[i+(bufmode?2:0)],"independent Rx data byte");
        if (reject) v.check(!v.rx_int,"rejected address has no result");
        else rx_result(corrupt?8'he3:second_match?8'he1:8'he0,expected_count,bufmode);
        frames++;
    endtask
    task automatic error_result(input logic [7:0] code);
        v.check(v.rx_int,"error IRQ"); v.get(3,value);
        v.check(value==code,$sformatf("error expected %02x got %02x",code,value));
        repeat(4) v.get(3,value);
    endtask
    task automatic replay(input bit service=1);
        for (int i=0;i<wire_len;i++) serial_rx(wire_bits[i],service);
    endtask
    task automatic extras;
        // Immediate ports and logical OR/AND masks, including stretched strobes.
        v.reset(); v.port_a=5; v.put(0,8'h22,3); v.get(0,value);
        v.check(value==8'h10,"immediate CRBF"); v.get(1,value,3);
        v.check(value==8'h14,"physical modem port A bits");
        v.mask(8'h63,8'he1); v.check(v.port_b==0,"port B reset mask");
        v.mask(8'ha3,8'h0a); v.check(v.port_b==5,"port B set mask");
        v.put(0,8'h23); v.get(1,value); v.check(value==8'h2b,"port B readback");
        v.mask(8'h91,1);
        for (int k=0;k<32;k++) begin serial_tx(); v.check(v.txd==wire_bits[k%8],"idle flag stream"); end
        v.mask(8'h51,8'hfe); serial_tx(); v.check(v.txd,"idle mark");
        // CBSY persists until the final parameter; no duplicate held accesses.
        v.put(0,8'hc0,3); v.get(0,value); v.check(value[7],"command busy");
        v.put(1,8'h20,3); v.get(0,value); v.check(value[7],"busy after length low");
        v.put(1,0,3); v.get(0,value); v.check(!value[7],"busy clears after last parameter");
        v.put(0,8'hc5); replay(); v.check(!v.rx_int && !v.rx_drq,"disabled receiver ignores stream");
        // Reset-register hold cancels activity and resets modes/results.
        v.put(2,1); v.check(!v.tx_int && !v.rx_int && v.rts_n,"software reset active");
        v.put(2,0); v.get(0,value); v.check(value==0,"software reset status");
        // Transparent Tx bypasses flags, FCS and stuffing.
        setup(); v.transmit(body_len,0,0,0,8'hc9);
        for (int i=0;i<body_len;i++) begin
            if (v.tx_drq) v.data_put(body[i]);
            for (int j=0;j<8;j++) begin serial_tx(); v.check(v.txd==body[i][j],"transparent bit"); end
        end
        v.get(2,value); v.check(value==8'h0d,"transparent complete");
        // Early and final results coexist; each is separately acknowledged.
        setup(1,0,0,8'h08); v.transmit(body_len-2,1,body[0],body[1]);
        begin
            int fed=2;
            for (int i=0;i<wire_len;i++) begin
                if (v.tx_drq && fed<body_len) begin v.data_put(body[fed]); fed++; end
                serial_tx();
            end
        end
        v.get(2,value); v.check(value==8'h0c && v.tx_int,"early result retained");
        v.get(2,value); v.check(value==8'h0d && !v.tx_int,"final result retained");
        // Missing Tx service and CTS loss generate aborts with distinct results.
        setup(); v.transmit(1);
        repeat(80) serial_tx(); v.get(2,value); v.check(value==8'h0e,"Tx underrun");
        setup(); v.cts_n=1; v.transmit(1); repeat(32) serial_tx();
        v.check(!v.tx_int && !v.rts_n,"Tx waits for CTS");
        v.cts_n=0; v.tick(3); repeat(10) serial_tx(); v.cts_n=1;
        repeat(32) serial_tx(); v.get(2,value); v.check(value==8'h0f,"CTS failure");
        setup(); v.transmit(1); repeat(10) serial_tx(); v.put(0,8'hcc);
        repeat(16) serial_tx(); v.get(2,value); v.check(value==8'h10,"abort complete");
        setup(); v.transmit(1,0,0,0,8'hc9); v.put(0,8'hcd);
        repeat(16) serial_tx(); v.get(2,value); v.check(value==8'h10,"transparent abort");
        // Receive data/memory/result overflow, carrier loss and CRC errors.
        setup(); got=0; v.receive(1024); replay(0); error_result(8'he8);
        setup(); got=0; v.receive(1); replay(); error_result(8'he9);
        setup(); got=0; v.receive(1024); replay(); replay(); error_result(8'heb);
        setup(); v.receive(10); v.cd_n=1; v.tick(4); error_result(8'hea);
        setup(); got=0; v.receive(1024); replay(); rx_result(8'he0,body_len-2,1);
        repeat(20) serial_rx(1); error_result(8'he5);
        // Aborted partial frame; no FCS or ending flag is supplied.
        setup(); got=0; v.receive(1024);
        for (int i=0;i<32;i++) serial_rx(wire_bits[i]);
        repeat(12) serial_rx(1); error_result(8'he4);
        // SDLC EOP and selective-loop turnaround to flag stream.
        setup(1,0,0,8'h10); v.mask(8'h51,8'hdf); v.receive(1024);
        serial_rx(0); repeat(7) serial_rx(1); error_result(8'he6);
        setup(1,0,0,8'h10); v.mask(8'h51,8'hdf); got=0;
        v.mask(8'ha4,8'h80); v.receive(1024,8'hc2,body[0],8'h17);
        replay(); rx_result(8'he0,body_len-2,1); serial_rx(0); repeat(7) serial_rx(1);
        v.check(!dut.delay_q && dut.mode_q[0],"selective loop EOP turnaround");
        // One-bit relay and mask reset, then loop transmit waiting for EOP.
        setup(); v.mask(8'ha4,8'h80); serial_rx(0); serial_rx(1);
        v.check(!v.txd,"one-bit delayed line");
        v.mask(8'h64,8'h7f); v.check(!dut.delay_q,"delay reset mask");
        v.receive(1024); v.mask(8'h51,8'hdf);
        v.transmit(body_len-2,1,body[0],body[1],8'hca);
        v.check(!v.tx_drq,"loop Tx waits for EOP"); serial_rx(0); repeat(7) serial_rx(1);
        begin
            int fed=2;
            v.tick(4);
            for (int i=0;i<wire_len;i++) begin
                if (v.tx_drq && fed<body_len) begin v.data_put(body[fed]); fed++; end
                serial_tx(); v.check(v.txd==wire_bits[i],"loop Tx independent wire bit");
            end
        end
        v.get(2,value); v.check(value==8'h0d && dut.delay_q,"loop Tx resumes delay");
        setup(1,0,0,1); v.transmit(1,1,8'h42,8'h13,8'hca);
        repeat(10) serial_tx(); v.put(0,8'hce);
        for(int i=0;i<8;i++) begin serial_tx(); v.check(v.txd==(((8'h7e>>i)&8'h01)!=0),"loop abort emits flag"); end
        v.get(2,value); v.check(value==8'h10 && dut.delay_q,"loop abort resumes delay");
    endtask
    initial begin
        int fd,rc,temp,case_no;
        case_no=0;
        if ($value$plusargs("seed=%d",seed)) begin end
        rng=32'(seed);
        if (!$value$plusargs("vectors=%s",vectors)) vectors="design/intel_8273/references/frames.txt";
        fd=$fopen(vectors,"r"); v.check(fd!=0,"open independent vectors");
        while (!$feof(fd)) begin
            rc=$fscanf(fd,"%d %d %d",body_len,wire_len,bad_len);
            if (rc==3) begin
                for(int i=0;i<body_len;i++) begin rc=$fscanf(fd,"%h",temp); v.check(rc==1,"body vector"); body[i]=8'(temp); end
                for(int i=0;i<wire_len;i++) begin rc=$fscanf(fd,"%d",temp); v.check(rc==1,"wire vector"); wire_bits[i]=1'(temp); end
                for(int i=0;i<bad_len;i++) begin rc=$fscanf(fd,"%d",temp); v.check(rc==1,"bad vector"); bad_bits[i]=1'(temp); end
                $display("8273 vector %0d body=%0d",case_no,body_len);
                for(int nr=0;nr<2;nr++) for(int bf=0;bf<2;bf++) begin
                    test_tx(1'(bf),1'(nr),case_no[0]); test_rx(1'(bf),1'(nr),case_no[0]);
                end
                test_rx(1,0,0,1);
                if (case_no==0) begin
                    test_tx(1,0,0,1); test_tx(1,1,0,1);
                    test_rx(1,0,0,0,8'hc1,0,0); test_rx(1,0,0,0,8'hc1,1,0);
                    test_rx(1,0,0,0,8'hc1,0,1); extras();
                end
                case_no++;
            end
        end
        $fclose(fd); v.check(case_no==44,"all independent vectors exercised");
        $display("8273 SUITE PASSED checks=%0d frames=%0d seed=%0d",v.checks,frames,seed); $finish;
    end
    initial begin #100000000; $fatal(1,"8273 suite timeout"); end
endmodule
