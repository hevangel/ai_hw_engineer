module intel_80286_at_refresh_row_tb;
    logic reset_n, refresh, q1, q2, row_oe, memr_n, memr_oe;
    logic [7:0] row, counter;
    intel_80286_at_refresh_row dut (
        .reset_n_i(reset_n), .refresh_i(refresh), .chain_q1_i(q1), .chain_q2_i(q2),
        .row_o(row), .row_oe_o(row_oe), .memr_n_o(memr_n), .memr_oe_o(memr_oe),
        .counter_o(counter)
    );
    initial begin
        reset_n=1; refresh=0; q1=0; q2=0;
        #1 reset_n=0; #1;
        assert(counter==0 && !row_oe && !memr_oe && memr_n)
            else $fatal(1,"counter reset or disabled outputs failed");
        reset_n=1;
        for (int i=0;i<260;i++) begin
            refresh=1; #1;
            assert(row==8'(i) && counter==8'(i+1))
                else $fatal(1,"LS590 counter/register lag or wrap failed at %0d",i);
            refresh=0; #1;
            assert(row==8'(i) && counter==8'(i+1))
                else $fatal(1,"falling refresh edge changed counter or register");
        end
        for (int inputs=0;inputs<4;inputs++) begin
            {q2,q1}=2'(inputs); #1;
            assert(row_oe==q1 && memr_oe==q2 && memr_n==!q1)
                else $fatal(1,"LS590/LS125 enable polarity failed");
        end
        reset_n=0; #1;
        assert(counter==0 && row==8'd3)
            else $fatal(1,"counter clear incorrectly changed output register");
        refresh=1; #1;
        assert(counter==0 && row==0)
            else $fatal(1,"register did not capture cleared counter during reset");
        $display("PASS: AT LS590 pre-increment row, wrap, reset and LS125 output enables");
        $finish;
    end
endmodule
