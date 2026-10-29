module tb_ttl_74x2620;
    logic g_ba_n,g_ab,a_drive,b_drive;
    logic [7:0] a_in,b_in,a_out,b_out;
    logic [7:0] saved_a,saved_b;
    ttl_74x2620 dut(.*);
    initial begin
        g_ba_n=1;g_ab=0;a_in=0;b_in=0;#1;
        for(int value=0;value<256;value++) begin
            a_in=8'(value);b_in=8'(value^8'h69);
            g_ba_n=1;g_ab=1;#1;
            assert(!a_drive && b_drive && a_out==0 && b_out==~a_in)
                else $fatal(1,"A to B");
            saved_a=a_in;saved_b=~a_in;
            g_ba_n=0;#1;
            assert(a_drive && b_drive && a_out==saved_a && b_out==saved_b)
                else $fatal(1,"A-to-feedback capture");
            a_in=~a_in;b_in=~b_in;#1;
            assert(a_out==saved_a && b_out==saved_b) else $fatal(1,"feedback hold");
            g_ab=0;#1;
            assert(a_drive && !b_drive && a_out==~b_in && b_out==0)
                else $fatal(1,"B to A");
            b_in=~b_in;#1;
            assert(a_out==~b_in) else $fatal(1,"transparent B source");
            saved_a=~b_in;saved_b=b_in;
            g_ab=1;#1;
            assert(a_drive && b_drive && a_out==saved_a && b_out==saved_b)
                else $fatal(1,"B-to-feedback capture");
            a_in=~a_in;b_in=~b_in;#1;
            assert(a_out==saved_a && b_out==saved_b) else $fatal(1,"reverse hold");
            g_ba_n=1;g_ab=0;#1;
            assert(!a_drive && !b_drive && a_out==0 && b_out==0)
                else $fatal(1,"isolation");
        end
        $display("PASS: tb_ttl_74x2620");$finish;
    end
endmodule
