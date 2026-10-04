`timescale 1ns/1ps
// Exercise the complete 16-bit information length, including A/C and FCS.
module tb_long_frame;
    logic clk=0;
    always #5 clk=~clk;
    intel_8273_if v(clk);
    `include "dut.svh"
    logic [31:0] oracle[0:19999];
    logic [7:0] value;
    int fed=0,got=0,bits;
    string filename;
    initial begin
        if (!$value$plusargs("long_vectors=%s",filename)) filename="design/intel_8273/work/sim/long_wire.hex";
        $readmemh(filename,oracle); bits=int'(oracle[0]);
        v.reset(); v.mask(8'h91,8'h24); v.mask(8'ha0,6); // internal NRZ loopback + TxC sample.
        v.receive(65535); v.transmit(65535,1,8'h42,8'h13);
        for(int i=0;i<bits;i++) begin
            if (v.tx_drq && fed<65535) begin v.data_put(8'(fed*7)); fed++; end
            v.tx_tick=1; v.tick(); v.tx_tick=0;
            v.check(v.txd===oracle[1+i/32][i%32],"maximum frame independent wire bit");
            v.tx_sample_tick=1; v.tick(); v.tx_sample_tick=0; v.tick(2);
            if (v.rx_drq) begin
                v.data_get(value); v.check(value===8'(got*7),"maximum frame received payload"); got++;
            end
        end
        v.check(fed==65535 && got==65535,"complete 16-bit payload count");
        v.get(2,value); v.check(value==8'h0d,"maximum Tx complete");
        v.get(3,value); v.check(value==8'he0,"maximum Rx CRC result");
        v.get(3,value); v.check(value==8'hff,"maximum Rx length low");
        v.get(3,value); v.check(value==8'hff,"maximum Rx length high");
        v.get(3,value); v.check(value==8'h42,"maximum address");
        v.get(3,value); v.check(value==8'h13,"maximum control");
        v.check(!v.tx_int && !v.rx_int && !v.tx_drq && !v.rx_drq,"maximum frame drained");
        $display("8273 MAXIMUM FRAME PASSED bits=%0d payload=%0d checks=%0d",bits,got,v.checks); $finish;
    end
    initial begin #1000000000; $fatal(1,"maximum frame timeout"); end
endmodule
