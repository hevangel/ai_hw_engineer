module tb_ttl_74x16470;
    logic [15:0] a_in,b_in,a_out,b_out;
    logic [1:0] clk_ab,clk_ba,clken_ab_n,clken_ba_n,oe_ab_n,oe_ba_n;
    logic [1:0] a_drive,b_drive;
    logic [15:0] expected_ab,expected_ba;
    ttl_74x16470 dut(.*);
    task automatic verify;
        for (int bank=0;bank<2;bank++) begin
            assert(a_drive[bank]===!(clken_ba_n[bank]|oe_ba_n[bank]))
                else $fatal(1,"BA drive");
            assert(b_drive[bank]===!(clken_ab_n[bank]|oe_ab_n[bank]))
                else $fatal(1,"AB drive");
            assert(a_out[bank*8+:8]===(a_drive[bank]?expected_ba[bank*8+:8]:8'b0))
                else $fatal(1,"BA data");
            assert(b_out[bank*8+:8]===(b_drive[bank]?expected_ab[bank*8+:8]:8'b0))
                else $fatal(1,"AB data");
        end
    endtask
    initial begin
        clk_ab=0;clk_ba=0;clken_ab_n=0;clken_ba_n=0;
        oe_ab_n=0;oe_ba_n=0;a_in=16'h1234;b_in=16'h5678;
        expected_ab=a_in;expected_ba=b_in;#1;
        clk_ab=3;clk_ba=3;#1;verify();clk_ab=0;clk_ba=0;#1;
        for(int value=0;value<256;value++) begin
            for(int controls=0;controls<256;controls++) begin
                {oe_ab_n,oe_ba_n,clken_ab_n,clken_ba_n}=8'(controls);
                a_in={8'(value),8'(~value)};
                b_in={8'(value^8'h69),8'(value^8'h96)};#1;verify();
                // Clock each direction and bank independently; others must hold.
                for(int bank=0;bank<2;bank++) begin
                    if(clken_ab_n[bank]==0) expected_ab[bank*8+:8]=a_in[bank*8+:8];
                    clk_ab[bank]=1;#1;verify();
                    a_in[bank*8+:8]=~a_in[bank*8+:8];#1;verify();
                    clk_ab[bank]=0;#1;verify();
                    if(clken_ba_n[bank]==0) expected_ba[bank*8+:8]=b_in[bank*8+:8];
                    clk_ba[bank]=1;#1;verify();
                    b_in[bank*8+:8]=~b_in[bank*8+:8];#1;verify();
                    clk_ba[bank]=0;#1;verify();
                end
            end
        end
        $display("PASS: tb_ttl_74x16470");$finish;
    end
endmodule
