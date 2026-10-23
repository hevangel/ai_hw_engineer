module tb_ttl_74x16246;
    logic oe_n, oe_11_n;
    logic [2:0] dir;
    logic [10:0] a_in, a_out, a_drive, b_out, b_drive;
    logic [7:0] bi_in;
    logic [2:0] b_in;
    logic [10:0] expected_a, expected_ad, expected_b, expected_bd;
    ttl_74x16246 dut (.*);
    initial begin
        for (int controls=0; controls<32; controls++) begin
            {oe_n,oe_11_n,dir}=5'(controls);
            for (int value=0; value<2048; value++) begin
                a_in=11'(value);
                bi_in=8'(value ^ (value>>3));
                b_in=3'((value>>5) ^ value);
                expected_a='0; expected_ad='0;
                expected_b='0; expected_bd='0;
                // Independent reconstruction of manufacturer table rows.
                if (controls<16) begin
                    for (int i=0;i<8;i++) begin
                        if (bi_in[i]==0) expected_ad[i]=1;
                        expected_b[i]=a_in[i]; expected_bd[i]=1;
                    end
                    case (dir[0])
                        0: begin expected_b[8]=a_in[8]; expected_bd[8]=1; end
                        1: begin expected_a[8]=b_in[0]; expected_ad[8]=1; end
                    endcase
                    case (dir[1])
                        0: begin expected_b[9]=a_in[9]; expected_bd[9]=1; end
                        1: begin expected_a[9]=b_in[1]; expected_ad[9]=1; end
                    endcase
                    case ({dir[2],oe_11_n})
                        0: begin expected_b[10]=a_in[10]; expected_bd[10]=1; end
                        1: begin end
                        2,3: begin expected_a[10]=b_in[2]; expected_ad[10]=1; end
                    endcase
                end
                #1;
                assert ({a_out,a_drive,b_out,b_drive}===
                        {expected_a,expected_ad,expected_b,expected_bd})
                    else $fatal(1,"16246 table control=%0d data=%0d",controls,value);
                assert ((a_out[7:0]&a_drive[7:0])==0)
                    else $fatal(1,"open collector sourced a high");
            end
        end
        $display("PASS: tb_ttl_74x16246"); $finish;
    end
endmodule
