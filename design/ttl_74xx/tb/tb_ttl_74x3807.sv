module tb_ttl_74x3807;
    logic clock_in;
    logic [9:0] q;
    ttl_74x3807 dut(.*);
    initial begin
        clock_in=0;#1;
        assert(q==10'd0) else $fatal(1,"all outputs low");
        clock_in=1;#1;
        assert(q==10'd1023) else $fatal(1,"all outputs high");
        repeat(16) begin
            clock_in=~clock_in;#1;
            for(int output_pin=0;output_pin<10;output_pin++) begin
                assert(q[output_pin]===clock_in) else $fatal(1,"fanout polarity");
            end
        end
        $display("PASS: tb_ttl_74x3807");$finish;
    end
endmodule
