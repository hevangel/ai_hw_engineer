module tb_ttl_74x4060;
    logic clki,clr,clko,clko_n;
    logic [9:0] q;
    logic [9:0] previous;
    int stages[10]='{4,5,6,7,8,9,10,12,13,14};
    ttl_74x4060 dut(.*);
    initial begin
        clki=1;clr=0;#1;clr=1;#1;
        assert(q==0 && !clko && clko_n) else $fatal(1,"stopped-high clear");
        clki=0;#1;
        assert(q==0 && !clko && clko_n) else $fatal(1,"clear dominates edge");
        clr=0;#1;
        for(int edges=1;edges<=32768;edges++) begin
            previous=q;clki=1;#1;
            assert(q===previous && clko && !clko_n) else $fatal(1,"rising hold");
            clki=0;#1;
            for(int tap=0;tap<10;tap++) begin
                assert(q[tap]===1'((edges/(2**(stages[tap]-1)))%2))
                    else $fatal(1,"tap=%0d edge=%0d",tap,edges);
            end
            assert(!clko && clko_n) else $fatal(1,"oscillator buffer polarity");
        end
        assert(q==0) else $fatal(1,"two-period wrap");
        repeat(1023) begin clki=1;#1;clki=0;#1;end
        assert(q!=0) else $fatal(1,"nonvacuous stopped-low reset setup");
        clr=1;#1;
        assert(q==0 && !clko && clko_n) else $fatal(1,"stopped-low clear");
        clr=0;#1;assert(q==0) else $fatal(1,"clear release holds");
        $display("PASS: tb_ttl_74x4060");$finish;
    end
endmodule
